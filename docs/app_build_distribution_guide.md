# Antigravity Proxy Launcher 二开、构建与分发完整指南

更新时间: 2026-04-11
适用范围: AntigravityProxyApp/launcher

## 1. 文档目标

这份文档面向三类场景:

- 二开团队: 如何在现有工程上持续开发
- 构建负责人: 如何稳定产出 Debug 和 Release 产物
- 发布负责人: 如何把产物发给内测用户或正式用户

目标是让流程可复制、可排查、可交接。

## 2. 前置条件

### 2.1 必备环境

- macOS
- 完整 Xcode (不是 CommandLineTools)
- xcodebuild 可用
- xcodegen 已安装

### 2.2 快速自检命令

```bash
xcodebuild -version
xcode-select -p
which xcodegen
```

如果 xcodegen 未安装:

```bash
brew install xcodegen
```

## 3. 工程结构与职责

关键目录:

- launcher/Sources/Views: 界面层
- launcher/Sources/State: 状态编排
- launcher/Sources/Services: 核心业务服务
- launcher/Sources/Models: 数据模型
- launcher/Resources: 打包进 App 的资源
- launcher/scripts: 构建、打包、校验、签名、公证脚本

关键产物:

- GUI: AntigravityProxyLauncher.app
- CLI: AntigravityProxyLauncherCLI

## 4. 二开标准流程

### 4.1 初始化

```bash
cd launcher
xcodegen generate
open AntigravityProxyLauncher.xcodeproj
```

### 4.2 代码改动建议顺序

1. 先改 Models 或 Services，确保核心逻辑正确
2. 再改 State，把 UI 状态转换补齐
3. 最后改 Views，避免 UI 先行导致状态不一致

### 4.3 每次提交前本地回归

```bash
cd launcher
swift build
bash scripts/build_app_targets.sh
```

推荐额外执行:

```bash
bash scripts/phase6_validation.sh
```

## 5. 构建方式

### 5.1 Debug 构建 (本地开发)

```bash
cd launcher
bash scripts/build_app_targets.sh
```

输出路径:

- launcher/.build/xcode/Build/Products/Debug/AntigravityProxyLauncher.app
- launcher/.build/xcode/Build/Products/Debug/AntigravityProxyLauncherCLI

运行 GUI:

```bash
open launcher/.build/xcode/Build/Products/Debug/AntigravityProxyLauncher.app
```

运行 CLI:

```bash
launcher/.build/xcode/Build/Products/Debug/AntigravityProxyLauncherCLI --help
```

### 5.2 Release 打包 (无签名)

```bash
cd launcher
bash scripts/package_release_artifacts.sh
bash scripts/verify_release_artifacts.sh
```

输出目录:

- launcher/dist/*.zip
- launcher/dist/*.dmg
- launcher/dist/release-checksums-*.json

说明:

- 无签名产物适合开发测试和内部验证
- 不建议直接对外公开分发

## 6. 二开后的分发策略

### 6.1 内部测试分发 (无签名)

发布方操作:

1. 执行 Release 打包和校验
2. 将最新 dmg 和 checksum 文件发给测试同学
3. 在发布说明中附带安装与排错步骤

测试方安装步骤:

1. 打开 dmg
2. 拖拽 AntigravityProxyLauncher.app 到 /Applications
3. 首次启动使用右键 -> 打开

如果 Gatekeeper 阻止启动，可执行:

```bash
xattr -dr com.apple.quarantine /Applications/AntigravityProxyLauncher.app
```

### 6.2 正式分发 (签名 + 公证)

前提:

- 有 Developer ID Application 证书
- 已配置 notarytool profile

首次配置 notary profile:

```bash
xcrun notarytool store-credentials antigravity-notary \
  --apple-id <APPLE_ID> --team-id <TEAM_ID> --password <APP_PASSWORD>
```

执行签名和公证:

```bash
cd launcher
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="antigravity-notary" \
bash scripts/sign_and_notarize.sh
```

签名公证后建议再次校验:

```bash
bash scripts/verify_release_artifacts.sh
```

## 7. 更新源 release.json 维护

### 7.1 手动生成

```bash
cd launcher
bash scripts/generate_release_feed.sh \
  --version 0.2.0 \
  --url https://example.com/downloads/Antigravity-Proxy-Launcher-macos-arm64-20260411-120000.dmg \
  --notes "修复若干稳定性问题" \
  --output dist/release.json
```

### 7.2 打包时自动生成

```bash
cd launcher
RELEASE_DOWNLOAD_BASE_URL="https://example.com/downloads" \
RELEASE_VERSION="0.2.0" \
RELEASE_NOTES="修复若干稳定性问题" \
bash scripts/package_release_artifacts.sh
```

## 8. 发布检查清单

发布前必须确认:

1. swift build 成功
2. build_app_targets.sh 成功
3. package_release_artifacts.sh 成功
4. verify_release_artifacts.sh 成功
5. GUI 可启动，主流程可走通
6. 诊断导出可用
7. 兼容规则更新可用

正式外发前追加确认:

1. sign_and_notarize.sh 成功
2. 签名后 DMG 可安装
3. release.json 指向正确下载地址
4. 发布说明包含版本、变更、已知问题、回滚方式

## 9. 常见问题

### 9.1 Xcode 可以编译但脚本失败

优先检查:

- xcode-select 是否指向完整 Xcode
- xcodegen 是否已安装
- scripts 是否有执行权限

### 9.2 对方反馈 App 无法打开

优先检查:

- 是否安装到 /Applications
- 是否经过签名与公证
- 是否被 quarantine 拦截

### 9.3 打包后运行缺少资源

优先检查:

- launcher/project.yml 里的 resources 配置
- verify_release_artifacts.sh 是否通过

## 10. 建议协作方式

1. 开发分支只做功能改动
2. 发布分支只做版本与发布相关改动
3. 每次发布保留对应 checksum 清单和发布说明
4. 线上问题优先导出诊断包再定位
