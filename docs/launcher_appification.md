# Antigravity Proxy Launcher App 化改造方案

## 1. 文档目标

本文档用于回答两个问题：

1. 为什么当前 `swift run AntigravityProxyLauncher` 虽然进入了 GUI 模式，但没有看到可用的 macOS 应用窗口
2. 如何把当前 `launcher/` 从开发期的 Swift Package 可执行程序，升级成真正可双击启动、可打包分发的 `Launcher.app`

---

## 2. 当前现状判断

当前 `launcher/` 的工程形态是：

- `Package.swift`
- `products: [.executable(...)]`
- 入口是 `@main struct ... : App`
- 通过 `swift run AntigravityProxyLauncher` 启动

对应文件：

- [Package.swift](/Users/kevinliangx/Developer/Repos/PublicCodeHub/KevinLiangX/AntigravityProxyApp/launcher/Package.swift)
- [AntigravityProxyLauncherApp.swift](/Users/kevinliangx/Developer/Repos/PublicCodeHub/KevinLiangX/AntigravityProxyApp/launcher/Sources/App/AntigravityProxyLauncherApp.swift)

结论：

- 现在它是一个“带 SwiftUI 生命周期的命令行可执行程序”
- 不是标准 macOS App bundle
- 不是用户视角的桌面应用

这也解释了为什么：

```bash
swift run AntigravityProxyLauncher
```

终端输出：

```text
[INFO] Launcher started in GUI mode. If no terminal output appears, check the app window in Dock/桌面。
```

但你看不到窗口。

---

## 3. 为什么 `swift run` 没有窗口

根因不是“代码里没有 SwiftUI WindowGroup”，而是：

- 当前产物是 **普通 Mach-O 可执行文件**
- 不是 `.app` bundle
- 没有标准 App bundle 的 `Info.plist`
- 没有正式的 AppKit/macOS 应用宿主环境

虽然代码中写了：

- `@main struct AntigravityProxyLauncherApp: App`
- `WindowGroup { HomeView() }`

但在 Swift Package 的 executable 模式下，macOS 对它的行为更接近“启动了一个进程”，而不是“启动了一个标准桌面 App”。

因此可能出现以下现象：

1. 进程启动了，但没有正常激活为前台 App
2. 没有稳定的 Dock 图标或窗口焦点
3. 窗口生命周期不稳定
4. 某些机器上看似运行了，但用户感知不到应用

也就是说：

- 现在不是“窗口代码没写”
- 而是“工程形态不对”

---

## 4. 当前方案的根本问题

当前 `launcher/` 更适合做：

- 核心逻辑验证
- CLI 排障
- SwiftUI 原型验证

但不适合做：

- 正式桌面应用分发
- 双击启动
- DMG 安装
- 用户级产品交付

主要问题有四类：

### 4.1 产物形态不对

现在产物是：

- 可执行文件

而不是：

- `.app`

### 4.2 资源加载是开发期思维

当前资源路径还依赖：

- `launcher/Resources/`
- 兄弟仓库 fallback

对应文件：

- [FileSystemPaths.swift](/Users/kevinliangx/Developer/Repos/PublicCodeHub/KevinLiangX/AntigravityProxyApp/launcher/Sources/Utilities/FileSystemPaths.swift)

这对开发方便，但不适合最终分发。

### 4.3 应用生命周期仍偏 CLI

当前入口同时承载：

- GUI 启动
- CLI `--doctor`
- CLI `--verify-patched`
- CLI `--patch-and-launch`

这在开发阶段没问题，但产品阶段应该变成：

- GUI 是主入口
- CLI 是辅助诊断工具

### 4.4 发布手册还是以 `swift build / swift run` 为中心

这说明当前工程定位依然是：

- 开发程序

而不是：

- 可分发应用

对应文件：

- [release_handbook.md](/Users/kevinliangx/Developer/Repos/PublicCodeHub/KevinLiangX/AntigravityProxyApp/docs/release_handbook.md)

---

## 5. 正确目标

正确目标不是继续优化 `swift run` 的表现，而是：

- 让 `AntigravityProxyLauncher` 成为标准 macOS App

用户最终拿到的应该是：

- `Antigravity Proxy Launcher.app`

并且支持：

- 双击启动
- 正常显示窗口
- 正常显示 Dock 图标
- 资源全部从 App bundle 读取
- 可进一步打包为 `.dmg`

---

## 6. 推荐改造方案

推荐方案：

- 保留 `launcher/` 里的业务代码
- 新建标准 macOS App target
- 让 GUI 与资源从 App bundle 启动
- 保留 CLI 为附属目标

不要继续把 Swift Package executable 直接当最终用户产品。

---

## 7. 建议的工程形态

推荐最终结构：

```text
AntigravityProxyApp/
  launcher/
    AntigravityProxyLauncher.xcodeproj
    App/
    Sources/
    Resources/
    CLI/
```

说明：

### 7.1 App Target

负责：

- `Launcher.app`
- SwiftUI 主窗口
- App bundle 资源
- 应用生命周期

### 7.2 Shared Sources

复用现有：

- Models
- Services
- Utilities
- State
- Views

### 7.3 CLI Target

保留诊断能力：

- `doctor`
- `verify-patched`
- `patch-and-launch`

但它不再是主交付物。

---

## 8. App 化改造步骤

按顺序建议这样做。

### Phase A：前端

目标：

- 建立标准 macOS App target

任务：

- 新建 `AntigravityProxyLauncher.xcodeproj`
- 新建 macOS App target
- 接入现有 `HomeView`
- 接入现有 `LauncherAppState`
- 确保双击 `.app` 可以看到窗口

完成标准：

- 不通过 `swift run`
- 直接运行 App target 就能看到窗口

### Phase B：前端

目标：

- 资源从 App bundle 内读取

任务：

- 把 `libAntigravityTun.dylib`
- `entitlements.plist`
- `proxy_config.template.json`
- `compatibility.json`

全部作为 App bundle resources 打包

完成标准：

- 不再依赖源码目录资源
- 不再依赖兄弟仓库 fallback 才能运行

### Phase C：后端

目标：

- 重构资源路径与环境路径逻辑

任务：

- `FileSystemPaths` 改为优先从 `Bundle.main` 读取资源
- 开发模式下可保留 fallback，但默认使用 bundle
- 分离“开发环境路径”和“发布环境路径”

完成标准：

- `.app` 在脱离源码目录的情况下仍能正常 patch

### Phase D：前端

目标：

- 完整应用化体验

任务：

- App 名称
- App Icon
- Dock 行为
- 菜单栏文案
- 首次启动体验

完成标准：

- 它在用户视角就是一个正常的 macOS App

### Phase E：后端

目标：

- 发布产物化

任务：

- 生成 `.app`
- 加入 Launcher 自身签名流程
- 准备 DMG/ZIP 打包脚本

完成标准：

- 可生成正式发布产物

---

## 9. 对现有代码的具体调整建议

### 9.1 `Package.swift`

当前：

- 适合开发期

后续建议：

- 保留用于共享模块或 CLI 调试
- 不再作为最终 GUI 交付方式

### 9.2 `AntigravityProxyLauncherApp.swift`

当前代码本身没有明显问题。

问题不在这里，而在：

- 它被放在 executable product 中运行

迁移到 App target 后，这个入口才会真正成为桌面应用入口。

### 9.3 `FileSystemPaths.swift`

应当新增：

- `bundledResourceURL(named:)`
- `appBundleResourceRoot`

并优先从：

- `Bundle.main`

读取资源。

### 9.4 `README.md`

当前文档里的运行方式：

```bash
swift build
swift run AntigravityProxyLauncher
```

应该在 App 化后改成：

- 开发运行：通过 Xcode App target
- CLI 诊断：通过单独 CLI target 或辅助命令
- 用户运行：双击 `.app`

---

## 10. 对“为什么现在没有窗口”的最终结论

最终结论是：

- 不是因为 SwiftUI 页面没写
- 不是因为 `WindowGroup` 没写
- 不是因为状态机卡住了

而是因为：

- **你现在启动的不是标准 macOS App，而是一个 Swift Package 的可执行程序**

所以当前问题的正确修复方式不是继续调 UI，而是：

- **做 App 化改造**

---

## 11. 最终建议

下一步不要再把 `swift run` 当作最终用户启动方式。

推荐立即新增一个正式阶段：

### Phase：前端

目标：

- 完成 `Launcher.app` 化

任务：

- 从 Swift Package executable 迁移到 macOS App target
- 让资源从 App bundle 读取
- 让 GUI 真正以 `.app` 形态运行
- 保留 CLI 诊断为附属能力

这是当前最优先的结构性工作。

如果不做这一步，后续无论补多少配置页、诊断页、规则更新，本质上仍然只是一个开发态程序，不是类似 `figmaEX` 的桌面分发产品。
