# 🎉 Antigravity Proxy Launcher v2.0 - 全新原生 macOS 桌面时代！

彻底告别终端黑框时代！v2.0 迎来史诗级重构。我们将底层核心逻辑（dylib注入劫持）与纯原生图形化交互（SwiftUI）完美融合，正式推出完全由图形界面驱动的 **macOS 桌面级应用**！

## 🚀 核心重磅更新 (New Features)

- ✨ **原生 macOS 桌面体验**：全新 SwiftUI 构建的总览 (Dashboard) 界面，现在你只需要点击 **「修复并启动」** 这个按钮，脏活累活全部自动完成，无需再打开 Terminal 敲命令行。
- 🛡️ **智能兼容性引擎 & 失败自动回滚**：应用启动时动态扫描原版应用版本，并与远程/本地 `compatibility.json` 规则库比对。在探测到不支持的版本时进行拦截以防污染；修补失败时全自动将环境恢复为干净初始状态，100% 保护你的原机 App。
- 🌐 **可视化节点与代理管理**：新增代理设置页 (Config) 与 配额看板 (Quota) 。告别修改隐藏终端配置文件的噩梦，可直接在应用内完成节点填写和网络流量状态监测。
- 🩺 **强大的排障与诊断中枢**：新增诊断页 (Diagnostics) 与内置 FAQ。若遇到环境异常，只需点击「一键导出诊断快照」，瞬间生成标准排障 Zip 压缩包，方便追踪与反馈。
- 🔄 **开箱即用的内置更新通知**：App 启动自动拉取远程发布订阅，在总览页面直接推送新版本更新横幅。
- 🎨 **专属视觉呈现**：新增了全新渲染的高清桌面级 App Icon（渐变盾牌雷电），提供完美融入 macOS 的产品级体验。

## 🛠️ 底层与架构优化 (Under the Hood)

- **Monorepo 架构统一**：底层 C/C++ 注入内核库 (`AntigravityTun`) 与 Swift 桌面端应用 (`launcher`) 完全合并收敛至单一仓库内，彻底规范各子模块边界。
- **构建环境与安全清理**：修复了 Xcode `#filePath` 宏在 Release 包中导致的本地 macOS 用户名信息泄漏漏洞，并完善了自动化一键无签名/带签名打包流程 (`CI/CD`)。
- **文档体系焕新**：新增 v2.0 主线 README 以及一系列详细的二次开发者构建分发指北，旧版 v1 脚本已归档至 `legacy_scripts/`。

## 📖 安装指南 (Installation)

1. 在下方 Assets 列表中下载最新的 **`AntigravityProxyLauncher_v2.0.dmg`** 文件。
2. 双击打开并将 `Antigravity Proxy Launcher.app` 拖入至你的 **应用程序 (Applications)** 文件夹中。
3. **⚠️ 首次运行注意**：如果你在双击打开时遇到 “文件已损坏” 或 “无法验证开发者” 的系统拦截（macOS Gatekeeper 机制），请打开**终端 (Terminal)** 并执行以下命令解除应用隔离：
   ```bash
   xattr -cr /Applications/Antigravity\ Proxy\ Launcher.app
   ```
4. 再次直接双击 App 即可正常无缝享用！

---
**Enjoy the magic! ✨**