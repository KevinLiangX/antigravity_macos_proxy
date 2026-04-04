# Antigravity Proxy 启动器 (Launcher) 方案设计

## 1. 现状与痛点分析

当前 `antigravity_macos_proxy` 项目偏向于“开发者模式”，普通用户在使用时面临较高的操作门槛。完整的使用流程包含以下步骤：

1. **获取与编译**：下载代码仓库，跑 `./compile_without_xcode.sh` 编译动态库。
2. **应用重签名**：执行 `./robust_unlock.sh`，破解原版应用的沙盒与安全限制。
3. **数据迁移**：首次使用需单独执行 `./migrate_data.sh` 转移原版沙盒数据。
4. **启动应用**：每次使用都必须通过终端运行 `./run_unlocked.sh` 进行动态库注入并拉起进程。

**主要痛点：**
- **操作繁琐**：每次启动应用都需要打开终端，缺乏正常的“双击图标”桌面端体验。
- **认知负担高**：用户需要理解多个脚本的先后顺序，容易漏配或错配。
- **配置修改不直观**：修改代理端口必须手动编辑 `config.json` 文件。

---

## 2. 演进方案：从一键脚本到独立 App

为了显著降低使用门槛，提升用户体验，建议采用**渐进式**的改良策略，分为三个阶段落地：

### 阶段一：智能化聚合脚本 (Smart Launcher Script)

编写一个 `launcher.sh`，将目前的多个离散脚本汇总，并引入**状态检测机制**。

**工作流设计：**
1. **环境自检**：检测 `libAntigravityTun.dylib` 是否存在？不存在则自动触发编译。
2. **解锁自检**：检测 `Antigravity_Unlocked.app` 是否存在或是否过期（比原版旧）？如果不满足，则提示并自动触发 `robust_unlock.sh`。
3. **数据迁移自检**：检测是否是首次生成解锁版？如果是，则自动触发 `migrate_data.sh` 迁移用户存档。
4. **静默启动**：完成上述检测后，注入 `DYLD_INSERT_LIBRARIES` 环境变量并直接拉起目标应用。

**优点**：开发零成本，仅用 Shell 逻辑。用户只需记住执行 `./launcher.sh`。

### 阶段二：轻量级 macOS App 封装 (AppleScript / Automator Wrapper)

在阶段一的基础上，给脚本“套个壳”，伪装成一个正常的桌面应用程序。

**工作流设计：**
- 使用 macOS 自带的 **AppleScript** 或 **Automator**，将 `launcher.sh` 的调用逻辑打包成 `Antigravity Launcher.app`。
- 绑定官方的 App Icon。
- 用户可以将这个 Launcher App 拖入自己的 `/Applications` (应用程序) 文件夹中。
- 点击 Launchpad（启动台）中的图标即可触发后台脚本，拉起注入后的前台窗口。

**优点**：用户拥有了双击即用的原生体验，无需跟黑框终端打交道。

### 阶段三：原生 GUI 菜单栏客户端 (Native Menu Bar App) (长期可选)

开发一个类似 ClashX / Surge 的 macOS 原生状态栏小工具（可使用 Swift 或 Electron 控制面板）。

**工作流设计：**
- **可视化配置**：提供 UI 面板，让用户直接输入代理服务器 IP 和端口。
- **一键修复**：面板上提供“重载/修复解锁应用”按钮，后台处理签名逻辑。
- **守护进程守护**：检测目标应用生命周期，应用退出时自动清理相关状态。

**优点**：彻底商业化/产品化的体验，做到真正的“傻瓜式”。

---

## 3. 核心技术挑战与应对策略

无论采用上述哪种 App 化方案，在 macOS 系统下都会面临以下安全机制的挑战：

1. **Gatekeeper 与隔离属性 (Quarantine)**
   - **问题**：如果将封装好的 App 打包分发，用户通过浏览器下载解压后，会被打上 `com.apple.quarantine` 标签。首次运行会被系统拦截报错“文件已损坏”。
   - **对策**：在分发说明中，仍需引导用户执行一次 `xattr -cr /Applications/Antigravity\ Launcher.app` 移除隔离属性，或者提供一个初始的 Install Command。

2. **环境变量清洗保护**
   - **问题**：macOS 对使用 `open` 命令打开的 App 会进行安全清洗，`DYLD_INSERT_LIBRARIES` 这种敏感的环境变量经常会被抹除，导致 Hook 失败。
   - **对策**：在 App 内部封装的脚本中，必须坚持使用 `exec "/path/to/Antigravity_Unlocked.app/Contents/MacOS/Electron"` 的方式直接调用 Unix 可执行二进制文件，不能依赖通用的 `open` 服务。

3. **Keychain 授权弹窗**
   - **问题**：`robust_unlock.sh` 在执行 `codesign` 重新签名时，系统必然会弹出密码输入框以获取证书使用权限。
   - **对策**：如果在 AppleScript 打包的静默模式中执行，弹窗可能会被掩盖或让用户感到突兀。方案是：在首次执行重签名等耗时且需要授权的操作时，弹出一个原生 Dialog (如 `osascript -e 'display dialog "正在构建解锁环境，即将需要您输入密码授权重新签名..."'`) 给用户充分的心理预期。

---

## 4. 下一步行动计划 (Action Items)

1. **[Todo]** 开发 `start_launcher.sh`：将散落的脚本整合成具备自检能力的单入口聚合脚本。
2. **[Todo]** 制作 App 壳：基于 AppleScript 编写 `.app` 封装代码，测试双击拉起应用的稳定性，验证环境变量是否在 GUI 启动环境下有效存活。
3. **[Todo]** 更新 README：更新用户使用指引，突出“一键使用”的新特性。