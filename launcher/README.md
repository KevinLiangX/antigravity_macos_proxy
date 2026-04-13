# Antigravity Proxy Launcher

本目录是 AntigravityProxyApp 的工程化起点，对齐 `docs/app.md` 与 `docs/mvp.md` 的 Phase 1 目标。

## 已完成内容

- Swift Package 可执行工程骨架
- 核心模型：`AppStatus` / `AppInfo` / `PatchMetadata` / `ProxyConfig` / `CompatibilityRule` / `PatchResult` / `DiagnosticSnapshot`
- 基础服务：检测、兼容性、Patch、签名、迁移、启动、诊断
- 工具：命令执行、路径管理、日志
- 兼容性注册表示例：`Sources/Compatibility/compatibility.json`

## 当前主流程

- 启动后自动检测原版 Antigravity
- 读取兼容性注册表并判断版本是否支持
- 点击「修复并启动」后执行：
	- 迁移数据（如果存在沙盒数据）
	- 复制原版 App 到用户目录 `~/Applications/Antigravity_Unlocked.app`
	- 清理扩展属性 (`xattr -cr`)
	- 嵌入 `dylib` 和代理配置
	- 写入 `Info.plist` 的 `LSEnvironment`
	- 写入 patch 元数据到 `~/Library/Application Support/AntigravityProxy/metadata/`
	- inside-out 重签名
	- 启动修复版 App
	- 失败时自动回滚修复包（避免残留半成品）

- 支持导出诊断包（summary.json + runtime.log）
- patch 流程日志落盘：`~/Library/Logs/AntigravityProxy/patch.log`
- GUI 增加页签：总览 / 配置 / 诊断
- GUI 增加设置页：失败自动导出诊断、修复后自动启动
- 设置页支持兼容规则远程更新（缓存到本地并优先加载）
- 设置页支持兼容规则可信域名白名单与可选 SHA256 校验
- 支持保存代理配置到 `~/Library/Application Support/Antigravity/proxy_config.json`
- patch 时优先使用用户保存配置注入修复包
- refresh 时自动检查 patched app 是否缺失/过期/可用
- 诊断页支持历史记录和失败聚合统计

运行时资源查找顺序：

1. `launcher/Resources/`
2. 邻接仓库 `../antigravity_macos_proxy/`（用于开发期复用已有产物）

## 本地运行

```bash
cd launcher
swift build
swift run AntigravityProxyLauncher
```

## App 化开发（Phase 10）

当前目录已支持通过 xcodegen 生成标准 macOS App 工程。

1. 生成 Xcode 工程

```bash
cd launcher
xcodegen generate
```

2. 打开并运行 App target

```bash
open AntigravityProxyLauncher.xcodeproj
```

工程包含两个 target：

- `AntigravityProxyLauncher`：GUI 主入口（正式 `.app`）
- `AntigravityProxyLauncherCLI`：CLI 诊断入口（辅助工具）

3. 命令行验证 App target 可编译

```bash
xcodebuild -project AntigravityProxyLauncher.xcodeproj \
	-scheme AntigravityProxyLauncher \
	-configuration Debug \
	-destination 'platform=macOS' \
	CODE_SIGNING_ALLOWED=NO build
```

若首次安装完整 Xcode 后出现插件加载失败，可先执行：

```bash
xcodebuild -runFirstLaunch
```

4. 构建 CLI target

```bash
xcodebuild -project AntigravityProxyLauncher.xcodeproj \
	-scheme AntigravityProxyLauncherCLI \
	-configuration Debug \
	-destination 'platform=macOS' \
	CODE_SIGNING_ALLOWED=NO build
```

也可以直接运行一键脚本：

```bash
bash scripts/build_app_targets.sh
```

## 发布打包（Phase 11 起点）

生成 Release `.app`、`.zip`、`.dmg`：

```bash
bash scripts/package_release_artifacts.sh
```

如需在打包时同时生成 `release.json`，可追加环境变量：

```bash
RELEASE_DOWNLOAD_BASE_URL="https://example.com/downloads" \
RELEASE_VERSION="0.2.0" \
RELEASE_NOTES="改进启动稳定性与配额监控体验" \
bash scripts/package_release_artifacts.sh
```

输出目录：`launcher/dist/`

生成更新提醒所需 `release.json`：

```bash
bash scripts/generate_release_feed.sh \
	--version 0.2.0 \
	--url https://example.com/downloads/Antigravity-Proxy-Launcher-macos-arm64.dmg \
	--notes "改进启动稳定性与配额监控体验" \
	--output dist/release.json
```

示例模板：`scripts/templates/release_feed.example.json`

校验最新发布产物内容并生成 SHA256 清单：

```bash
bash scripts/verify_release_artifacts.sh
```

签名与公证（脚本骨架）：

```bash
SIGN_IDENTITY="Developer ID Application: ..." \
NOTARY_PROFILE="antigravity-notary" \
bash scripts/sign_and_notarize.sh
```

首次使用前先配置 notarytool profile：

```bash
xcrun notarytool store-credentials antigravity-notary \
	--apple-id <APPLE_ID> --team-id <TEAM_ID> --password <APP_PASSWORD>
```

更新提醒支持“忽略此版本”和“恢复提醒”，可在总览页与设置页操作。

## 二开与构建 App（无签名版）

完整手册（含二开流程、无签名内测分发、签名公证正式分发）见：`../docs/app_build_distribution_guide.md`

### 二开建议流程

1. 分支与工程生成

```bash
cd launcher
xcodegen generate
open AntigravityProxyLauncher.xcodeproj
```

2. 开发优先顺序

- UI 层：`Sources/Views/`
- 状态编排：`Sources/State/`
- 业务服务：`Sources/Services/`
- 数据模型：`Sources/Models/`

3. 每次改动后的本地回归

```bash
swift build
bash scripts/build_app_targets.sh
```

### 构建 Debug App（无签名）

```bash
bash scripts/build_app_targets.sh
```

产物：

- `launcher/.build/xcode/Build/Products/Debug/AntigravityProxyLauncher.app`
- `launcher/.build/xcode/Build/Products/Debug/AntigravityProxyLauncherCLI`

### 构建 Release App / ZIP / DMG（无签名）

```bash
bash scripts/package_release_artifacts.sh
bash scripts/verify_release_artifacts.sh
```

产物目录：`launcher/dist/`

说明：

- 没有真实签名与公证时，产物可用于开发测试和内部验证。
- 对外分发前再执行 `scripts/sign_and_notarize.sh`。

## 终端诊断

如果你在终端运行后看不到更多输出，这通常是因为程序进入了 GUI 模式。

可执行诊断模式查看关键状态：

```bash
swift run AntigravityProxyLauncher -- --doctor
```

导出诊断包（终端模式）：

```bash
swift run AntigravityProxyLauncher -- --export-diagnostics
```

验证修复包（终端模式）：

```bash
swift run AntigravityProxyLauncher -- --verify-patched
```

一键执行 CLI 全流程（doctor -> migrate -> patch -> verify -> launch）：

```bash
swift run AntigravityProxyLauncher -- --patch-and-launch
```

Phase 4 无 GUI 回归脚本：

```bash
bash scripts/phase4_smoke_test.sh
```

Phase 6 核心链路验证脚本：

```bash
bash scripts/phase6_validation.sh
```

## Google OAuth 团队内置配置

当团队不希望每个人都单独填写 Client ID / Client Secret 时，可在仓库内置一份共享配置：

1. 编辑 `launcher/Resources/google_oauth_client.json`
2. 写入真实的 Google OAuth 客户端信息：

```json
{
	"client_id": "<your-client-id>",
	"client_secret": "<your-client-secret>"
}
```

加载优先级（高 -> 低）：

1. 环境变量：`AG_GOOGLE_CLIENT_ID` / `AG_GOOGLE_CLIENT_SECRET`
2. 设置页保存值
3. `launcher/Resources/google_oauth_client.json`（团队内置）

## 下一步建议

1. 完成 Phase 6 测试清单与执行记录（正向/异常/回滚）。
2. 扩展 CLI 回归脚本覆盖配置变更与规则更新场景。
3. 补充发布文档与运维手册（规则更新与紧急回滚）。
