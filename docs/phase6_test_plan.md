# Phase 6 测试清单

更新时间: 2026-04-10

## 目标

验证 launcher 核心链路在 CLI 路径可稳定执行，并覆盖支持/不支持版本的关键分支。

## 测试环境

- OS: macOS
- 目标应用: /Applications/Antigravity.app
- 修复应用: ~/Applications/Antigravity_Unlocked.app
- 执行脚本: launcher/scripts/phase6_validation.sh

## 自动化用例

1. Build launcher
- 命令: swift build
- 预期: 构建成功

2. Doctor supported path
- 命令: swift run AntigravityProxyLauncher -- --doctor
- 预期: 输出兼容性支持并返回 0

3. Patch and launch CLI path
- 命令: swift run AntigravityProxyLauncher -- --patch-and-launch
- 预期: patch/verify/launch 全流程成功并返回 0

4. Verify patched result
- 命令: swift run AntigravityProxyLauncher -- --verify-patched
- 预期: 输出 patched app 验证通过并返回 0

5. Doctor unsupported path
- 操作: 注入临时兼容缓存规则（min/max 版本为 999.x）
- 命令: swift run AntigravityProxyLauncher -- --doctor
- 预期: 返回非 0，输出版本不支持

## 人工补充用例（建议）

1. 代理离线场景
- 关闭本地代理端口后执行 patch-and-launch
- 观察应用行为与日志是否有明确诊断

2. GUI 路径回归
- 在 GUI 中执行修复、导出诊断、查看历史与失败聚合

3. 规则更新可信校验
- 使用非白名单域名 URL，验证更新被拒绝
- 使用错误 SHA256，验证校验失败
