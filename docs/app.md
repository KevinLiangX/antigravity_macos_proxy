# Antigravity Proxy Launcher 方案设计

## 1. 目标

本项目的目标不是继续分发脚本，而是做成类似 `figmaEX` 的桌面分发产品。

用户拿到的应该是一个可双击运行的 `Launcher.app`，而不是：

- clone 仓库
- 手动编译 `dylib`
- 手动执行解锁脚本
- 手动迁移数据
- 手动编辑配置
- 手动从终端启动

推荐方案：

- **主方案：Launcher App + 本地 Patch 引擎**

该方案的核心思路是：

- 分发我们自己的 `Antigravity Proxy Launcher.app`
- 不直接分发修改后的 `Antigravity.app`
- 由 Launcher 在用户本机完成检测、复制、嵌入资源、重签名、迁移、启动和修复

这是当前最适合本项目的方案，因为它同时满足：

- 产品体验接近 `figmaEX`
- 最大化复用现有 `dylib` 与脚本能力
- 上游版本变动时维护成本可控
- 分发边界比“直接再分发改造后的官方 App”更稳

---

## 2. 为什么选这个方案

不推荐继续走“脚本分发”：

- 用户门槛太高
- README 驱动的产品很难扩大使用
- 问题排查高度依赖终端
- 每个步骤都可能出错

不推荐把改造后的 `Antigravity_Unlocked.app` 直接作为主分发物：

- 上游 App 一更新就需要重新生产整包
- 签名和兼容性压力很大
- 用户很难理解官方版本与改造版本的关系
- 风险边界更敏感

推荐 Launcher App 的原因：

- 用户看到的是一个桌面客户端
- patch 过程可以做成产品内流程
- 首次使用、修复、升级都能被 UI 承接
- 保留当前仓库最有价值的底层代理能力

一句话总结：

- **底层能力继续保留在当前仓库**
- **分发层升级为 Launcher 产品**

---

## 3. 产品形态

最终交付物：

- `Antigravity Proxy Launcher.app`
- 内置 `libAntigravityTun.dylib`
- 内置 `entitlements.plist`
- 内置默认 `proxy_config.template.json`
- 内置兼容性注册表 `compatibility.json`
- 可选 `CLI` 诊断入口

用户路径：

1. 下载 Launcher
2. 打开 Launcher
3. Launcher 自动检测 `/Applications/Antigravity.app`
4. 用户点击“修复并启动”
5. Launcher 完成 patch 并启动目标 App
6. 用户后续统一从 Launcher 启动或修复

---

## 4. 总体架构

整体分为四层：

### 4.1 Launcher GUI

建议使用：

- `SwiftUI`

职责：

- 展示当前状态
- 引导首次使用
- 编辑代理配置
- 执行修复与启动
- 查看日志与导出诊断信息

### 4.2 Patch Engine

建议使用：

- `Swift`
- 必要时通过 `Process` 调用少量系统命令

职责：

- 检测目标 App
- 校验兼容性
- 复制和改造 App Bundle
- 嵌入资源
- 修改 `Info.plist`
- 重签名
- 迁移数据
- 启动和验证

### 4.3 Runtime Assets

包含：

- `libAntigravityTun.dylib`
- `entitlements.plist`
- 默认配置模板

职责：

- 作为 patch 的固定输入
- 随 Launcher 一起版本化

### 4.4 Compatibility Registry

包含：

- `compatibility.json`

职责：

- 描述支持的目标 App 版本
- 描述目标 App 的 bundle 结构
- 限制未知版本的盲 patch

---

## 5. 和当前仓库的关系

当前仓库已经具备两个最重要的能力：

1. **底层透明代理能力**
2. **目标 App 解锁与注入能力**

现有能力来源：

- `AntigravityTun/`：网络层 hook 与 FakeIP / SOCKS5 代理内核
- `robust_unlock.sh`：复制、嵌资源、写 `Info.plist`、重签名
- `run_unlocked.sh`：显式注入启动
- `migrate_data.sh`：迁移数据

本方案不是推倒重做，而是：

- 先把这些能力收敛成一个稳定的 Patch Engine
- 再由 Launcher GUI 承接用户入口

---

## 6. 目录结构建议

建议在 `AntigravityProxyApp` 下采用如下结构：

```text
AntigravityProxyApp/
  docs/
    app.md
  launcher/
    AntigravityProxyLauncher.xcodeproj
    Sources/
      App/
      Views/
      State/
      Models/
      Services/
        AppDetectionService.swift
        CompatibilityService.swift
        PatchService.swift
        SigningService.swift
        MigrationService.swift
        LaunchService.swift
        DiagnosticsService.swift
      Compatibility/
        compatibility.json
    Resources/
      libAntigravityTun.dylib
      entitlements.plist
      proxy_config.template.json
```

当前仓库建议保留：

- `AntigravityTun/` 继续作为底层注入工程
- `launcher/Resources` 从当前仓库同步构建产物

---

## 7. 本地状态机

Launcher 不能只是几个按钮，必须围绕状态机设计。

建议状态：

- `targetAppMissing`
- `targetAppUnsupportedVersion`
- `targetAppInstalled`
- `patchedAppMissing`
- `patchedAppOutdated`
- `patching`
- `patchedReady`
- `launching`
- `running`
- `repairRequired`
- `error`

状态判定依据：

- 原版 App 是否存在
- Bundle ID 是否正确
- 版本是否在兼容清单内
- 已 patch 的 App 是否存在
- 内嵌 `dylib/config` 是否完整
- `Info.plist` 的 `LSEnvironment` 是否正确
- patch 时间是否晚于原版更新时间
- 上次 patch 是否成功

状态机的意义：

- 首次安装时有明确引导
- 目标 App 升级后能明确提示“需要重新修复”
- 异常场景不会退化成“请去终端跑脚本”

---

## 8. Patch Engine 设计

Patch Engine 是整个方案的核心。

建议将当前脚本能力收敛为以下步骤。

### 8.1 `detectInstalledTargetApp()`

职责：

- 查找 `/Applications/Antigravity.app`
- 读取 `Info.plist`
- 识别版本、架构、主执行文件位置

输出：

- Bundle ID
- App 版本
- 安装路径
- 最后修改时间
- 主执行文件路径

### 8.2 `validateCompatibility()`

职责：

- 对照 `compatibility.json`
- 检查版本是否在支持范围内
- 检查 Bundle 结构是否符合预期

策略：

- 支持的版本正常 patch
- 未知版本给出“暂不支持”或“实验性修复”
- 默认不盲 patch

### 8.3 `preparePatchedBundle()`

职责：

- 复制原版 App 到本地工作路径
- 清理扩展属性

建议路径：

- `~/Applications/Antigravity Proxy/Antigravity_Unlocked.app`

或：

- `~/Library/Application Support/AntigravityProxy/patched/Antigravity_Unlocked.app`

### 8.4 `embedRuntimeAssets()`

职责：

- 嵌入 `libAntigravityTun.dylib`
- 写入实际运行配置文件
- 写入 patch 元信息

建议额外加入：

- `patch_metadata.json`

内容示例：

- Launcher 版本
- patch 时间
- 目标 App 版本
- 运行时资源版本

### 8.5 `rewriteInfoPlist()`

职责：

- 写入 `LSEnvironment`
- 写入 `ANTIGRAVITY_CONFIG`
- 关闭自动更新相关项
- 写入你们自己的 patch 标记

### 8.6 `deepResignBundle()`

职责：

- 遍历 Mach-O
- inside-out 重签名
- 顶层 Bundle 再签一次

这一步基本继承现有 `robust_unlock.sh` 的思路。

### 8.7 `migrateIfNeeded()`

职责：

- 首次修复时做数据迁移
- 已迁移时跳过
- 尽量做成幂等

### 8.8 `launchPatchedApp()`

职责：

- 首次启动时可显式注入
- 后续优先依赖 Bundle 内的 `LSEnvironment`

### 8.9 `verifyPatchedResult()`

职责：

- 检查主执行文件是否存在
- 校验 `dylib` 和配置文件是否存在
- 检查 `Info.plist` 是否生效
- 执行 `codesign --verify`
- 记录验证结果

---

## 9. GUI 页面设计

第一版不需要复杂，只做四个页面。

### 9.1 首页

展示：

- 当前状态
- 当前检测到的 Antigravity 版本
- 当前 patch 状态
- “修复并启动”
- “重新修复”
- “打开日志”

### 9.2 配置页

配置项：

- 代理 host
- 代理 port
- 代理类型
- connect/send/recv timeout
- 日志级别
- 是否启用 `child_injection`

### 9.3 诊断页

展示：

- 原版 App 路径
- patch App 路径
- 签名状态
- 最近 patch 结果
- 最近启动错误
- 导出诊断包

### 9.4 设置页

设置项：

- 是否自动检测兼容更新
- 是否启动时自动修复
- 是否显示高级日志

---

## 10. 兼容性注册表

新增 `compatibility.json`，不要把 Antigravity 的结构细节硬编码在多个模块中。

示例：

```json
{
  "apps": [
    {
      "bundle_id": "com.antigravity.mac",
      "name": "Antigravity",
      "supported_versions": ["1.2.x", "1.3.x"],
      "main_executable": "Contents/MacOS/Electron",
      "resource_dir": "Contents/Resources",
      "data_paths": [
        "~/Library/Containers/com.antigravity.mac/Data",
        "~/Library/Application Support/Antigravity"
      ],
      "requires_entitlements": true,
      "supports_restart_safe_injection": true
    }
  ]
}
```

兼容表至少应描述：

- Bundle ID
- 名称
- 支持的版本范围
- 主执行文件路径
- 资源目录
- 数据目录
- 是否需要重签名
- 是否支持重启后继续注入

---

## 11. 日志与诊断设计

产品化之后，日志不能再只存在终端里。

建议日志分类：

- `launcher.log`
- `patch.log`
- `runtime.log`

建议支持“导出诊断包”：

- Launcher 版本
- 目标 App 版本
- patch 结果
- 当前配置摘要
- `codesign` 验证摘要
- `Info.plist` 关键字段
- 最近一次启动错误

诊断包的目标是：

- 用户反馈问题时，不需要手动截图终端
- 团队可以更快定位问题

---

## 12. 分发格式

推荐：

- 主格式：`.dmg`
- 备用格式：`.zip`

建议按架构分别发布：

- `Antigravity-Proxy-Launcher-macos-arm64.dmg`
- `Antigravity-Proxy-Launcher-macos-x64.dmg`

原因：

- 更接近正式桌面产品的交付方式
- 用户容易理解和安装
- 与 `figmaEX` 的下载体验更接近

第一阶段不建议优先做 universal 包，先把分发链跑通。

---

## 13. 更新策略

需要分清三类更新。

### 13.1 Launcher 自身更新

建议：

- 先做“有更新提示”
- 暂不做自动覆盖安装

### 13.2 Compatibility Registry 更新

建议：

- Launcher 启动时检查远程兼容表
- 新兼容规则优先独立更新

### 13.3 目标 App 更新

策略：

- 检测到原版 App 版本变化后
- 将状态切为 `repairRequired`
- 引导用户重新修复

不建议第一版支持静默后台重 patch。

---

## 14. 风险与边界

必须提前明确以下现实问题：

- 首次重签名可能触发密码输入或权限弹窗
- 自动更新会破坏 patch 结果
- 上游 App 结构变化可能导致 patch 失败
- 某些系统安全策略可能拦截运行
- 用户需要理解这是一个“增强启动器”，不是官方原版

这些问题不能只放在 README。

需要：

- 在产品 UI 中提前提示
- 在失败时给出下一步指引
- 在诊断包中记录完整上下文

---

## 15. 开发路线图

按照约束，phase 只安排单一维度任务，并按后端、前端、测试三个维度拆分。

### Phase 1：后端

目标：

- 收敛现有脚本能力，形成 `Patch Engine`

任务：

- 抽象 `detect / validate / patch / migrate / launch / verify`
- 将关键脚本逻辑迁为结构化服务
- 增加 `compatibility.json`
- 增加 patch 元数据

交付：

- 可被 GUI 调用的 patch 核心模块

### Phase 2：前端

目标：

- 做最小可用 `Launcher.app`

任务：

- 首页状态展示
- “修复并启动”
- 配置页
- 日志入口
- 错误提示

交付：

- GUI 可以承接首次使用流程

### Phase 3：测试

目标：

- 验证完整本地使用路径

任务：

- 新机器首次使用测试
- 已安装原版 App 测试
- 原版 App 升级后重修复测试
- 代理在线 / 离线测试
- arm64 / x64 兼容性测试

交付：

- 一份兼容矩阵
- 一份失败模式清单

### Phase 4：后端

目标：

- 提升适配稳定性与可维护性

任务：

- 增加签名校验
- 增加 patch 结果校验
- 增加清理与恢复能力
- 增加远程兼容规则更新
- 增加诊断包导出

交付：

- 稳定版 Patch Engine

### Phase 5：前端

目标：

- 补齐产品体验

任务：

- 诊断页
- 设置页
- DMG 安装体验
- 更新提示
- 支持边界和说明文案

交付：

- 接近公开分发的桌面产品

### Phase 6：测试

目标：

- 小范围灰度发布验证

任务：

- 收集真实用户安装失败原因
- 收集 patch 失败原因
- 修正 UI 引导与兼容提示
- 固化发布前检查清单

交付：

- 第一版公开发布标准

---

## 16. MVP 定义

第一版 MVP 只需要满足以下条件：

- 用户下载 `Launcher.app`
- Launcher 能检测本机原版 `Antigravity.app`
- Launcher 能执行一键修复
- Launcher 能启动修复后的 App
- 用户能在 GUI 中修改代理配置
- 用户能查看日志和导出诊断包

只要做到这一步，本项目就已经从“技术脚本工具”升级为“可分发产品雏形”。

---

## 17. 最终结论

推荐方案为：

- **Launcher App + 本地 Patch 引擎**

实施原则为：

- 保留现有底层注入能力
- 放弃脚本作为主要用户入口
- 用 Launcher 承接 patch、修复、启动、诊断和配置
- 用兼容性注册表管理上游版本变化
- 用 GUI 和诊断能力替代 README 驱动的人工排障

这条路线最接近 `figmaEX` 的产品化体验，也最符合当前仓库的现实基础。
