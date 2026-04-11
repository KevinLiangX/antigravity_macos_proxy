# AntigravityProxyApp 发布手册

更新时间: 2026-04-10
适用范围: `Antigravity Proxy Launcher.app`（macOS）

## 1. 目标

本手册用于规范 `Antigravity Proxy Launcher.app` 的发布、升级、回滚和故障响应流程，确保发布可重复、可追溯、可恢复。

本手册的口径以：

- 标准 macOS App bundle
- 正式 `.app`
- 正式 `.dmg` / `.zip`

为目标，不再把 `swift run` 视为最终用户交付方式。

---

## 2. 角色与职责

### 2.1 发布负责人

- 执行发布流程
- 确认发布前检查项
- 在发布后收集验收结果

### 2.2 开发负责人

- 合并发布分支
- 修复阻塞缺陷
- 提供紧急补丁

### 2.3 验收负责人

- 执行发布后验证
- 给出通过 / 阻塞结论

---

## 3. 发布类型

### 3.1 Patch 发布

- 小范围修复
- 无破坏性变更

### 3.2 Minor 发布

- 功能增强
- 向后兼容

### 3.3 Emergency 发布

- 紧急故障修复
- 可跳过部分非关键验证
- 但必须在发布后补做完整回归

---

## 4. 版本与产物约定

### 4.1 版本号

- 使用 semver：`major.minor.patch`
- 示例：`0.3.0`

### 4.2 正式发布产物

正式用户产物应包括：

- `Antigravity Proxy Launcher.app`
- `Antigravity-Proxy-Launcher-macos-arm64.dmg`
- `Antigravity-Proxy-Launcher-macos-x64.dmg`
- 可选备用：`.zip`
- 发布说明
- 对应测试记录

### 4.3 开发期产物

开发期可保留：

- `swift build`
- `swift run`
- CLI 诊断命令

但它们仅用于：

- 本地调试
- 开发验证
- 自动化脚本

不应作为正式分发交付口径。

### 4.4 发布记录文件

- [phase_status.md](/Users/kevinliangx/Developer/Repos/PublicCodeHub/KevinLiangX/AntigravityProxyApp/docs/phase_status.md)
- [release_handbook.md](/Users/kevinliangx/Developer/Repos/PublicCodeHub/KevinLiangX/AntigravityProxyApp/docs/release_handbook.md)
- `docs/phase6_test_report.md`
- 未来补充：
  - `docs/qa_checklist.md`
  - `docs/known_issues.md`

---

## 5. 发布前检查清单

### 5.1 工程与构建

- App target 可成功构建
- `.app` 可成功生成
- App bundle 内资源完整
- 不依赖源码目录即可运行

开发期附加检查：

- `swift build` 成功
- `swift run ... -- --doctor` 正常

### 5.2 核心功能验证

- Launcher.app 可双击打开
- 总览页可正常显示状态
- 配置页可保存代理配置
- 设置页可保存行为设置
- 诊断页可导出诊断并看到历史记录
- 修复并启动主流程可正常执行

### 5.3 Patch / Verify 验证

- `doctor` 正常
- `verify-patched` 正常
- `patch-and-launch` 正常
- patch 失败时可回滚
- 失败时诊断包可导出

### 5.4 分发与资源检查

- `libAntigravityTun.dylib` 已打入 App bundle
- `entitlements.plist` 已打入 App bundle
- `proxy_config.template.json` 已打入 App bundle
- `compatibility.json` 已打入 App bundle

### 5.5 兼容性与安全

- 兼容规则地址在可信域名白名单内
- 若配置 SHA256，则与规则文件一致
- 缓存规则损坏时不会永久阻断主流程

---

## 6. 正式发布流程

### 6.1 冻结发布窗口

- 发布期间不再合入无关改动

### 6.2 构建正式产物

构建目标：

- `Launcher.app`
- `DMG`
- 可选 `ZIP`

要求：

- 构建环境固定
- 构建输出路径固定
- 同版本产物可重复生成

### 6.3 执行自动化验证

至少执行：

- 开发期 CLI 验证
- patch / verify 自动化脚本
- 发布前 smoke test

### 6.4 执行人工验收

至少验证：

- `.app` 双击启动
- GUI 主流程
- 配置保存
- patch / verify / launch
- 诊断导出
- 设置保存

### 6.5 产出发布说明

发布说明至少包含：

- 版本号
- 发布时间
- 主要变更
- 支持的 Antigravity 版本范围
- 已知问题
- 回滚方案

### 6.6 小范围灰度

- 先内部用户
- 再扩大到公开用户

### 6.7 发布后观察

首次发布后至少观察 30-60 分钟，重点关注：

- patch 失败率
- verify 失败率
- 启动失败率
- 兼容规则更新失败率

---

## 7. 升级策略

### 7.1 渐进升级

- 先内部灰度
- 再全量发布

### 7.2 升级触发条件

- 新规则缓存可正常加载
- `doctor / verify / patch-and-launch` 在目标版本稳定通过
- `.app` 在脱离源码目录的环境下仍能工作

### 7.3 升级验收标准

- patch-and-launch 成功率 >= 95%
- verify-patched 成功率 >= 99%
- 无高优先级崩溃回归
- 无大面积“窗口打不开 / 应用无响应”问题

---

## 8. 回滚手册（SOP）

### 8.1 触发条件

1. 发布后出现批量 patch 失败
2. 发布后 verify 大面积失败
3. 规则更新导致支持版本误判
4. `.app` 无法正常启动或无窗口

### 8.2 快速止血

1. 停止扩散
- 暂停继续分发新版本

2. 恢复兼容规则
- 清空或替换本地缓存规则文件：
  - `~/Library/Application Support/AntigravityProxy/compatibility.registry.json`
  - `~/Library/Application Support/AntigravityProxy/compatibility.registry.meta.json`
- 强制回退到内置规则

3. 指导用户恢复
- 执行 doctor
- 重新执行 patch-and-launch
- 必要时清理 patched app 后重试

### 8.3 版本回滚

1. 回滚到上一稳定版 `.app`
2. 重新执行自动化验证
3. 发布回滚公告并说明影响范围

---

## 9. 故障分级与响应

### 9.1 P0

- 无法修复 / 无法启动 / 无窗口，影响多数用户
- 目标响应：30 分钟内给出止血方案

### 9.2 P1

- 主要功能受影响，可临时绕过
- 目标响应：2 小时内给出修复计划

### 9.3 P2

- 非关键功能异常
- 目标响应：下一个 patch 发布修复

---

## 10. 发布沟通模板

### 10.1 发布通知模板

标题：

`[发布通知] Antigravity Proxy Launcher vX.Y.Z`

内容：

1. 发布时间：`YYYY-MM-DD HH:mm`
2. 变更摘要：...
3. 影响范围：...
4. 验证结果：自动化通过 / 人工回归通过
5. 产物：`.app / .dmg / .zip`
6. 回滚预案：已准备

### 10.2 回滚通知模板

标题：

`[回滚通知] Antigravity Proxy Launcher vX.Y.Z -> vA.B.C`

内容：

1. 回滚时间：`YYYY-MM-DD HH:mm`
2. 回滚原因：...
3. 影响范围：...
4. 用户动作：重新执行 doctor 与 patch-and-launch，或下载回滚版本
5. 后续计划：...

---

## 11. 发布后验收清单

1. Launcher.app 可正常打开
2. Dock / 窗口行为正常
3. Doctor 正常
4. Verify 正常
5. Patch-and-launch 正常
6. 配置保存和设置保存正常
7. 诊断导出、历史和失败聚合正常
8. 兼容规则更新与可信校验正常
9. `.dmg` 安装链路正常

---

## 12. 开发期常用命令

以下命令仅用于开发与调试，不是正式分发方式。

### 12.1 构建

```bash
swift build
```

### 12.2 核心检查

```bash
swift run AntigravityProxyLauncher -- --doctor
swift run AntigravityProxyLauncher -- --verify-patched
```

### 12.3 全流程

```bash
swift run AntigravityProxyLauncher -- --patch-and-launch
```

### 12.4 自动化验证

```bash
bash scripts/phase6_validation.sh
```

---

## 13. 当前发布口径说明

在 App 化完成之前：

- 本手册中的 `.app / .dmg` 流程属于目标形态
- `swift build / swift run` 仍可继续用于开发期验证

在 App 化完成之后：

- 正式发布只认 `.app / .dmg`
- `swift run` 退化为开发和诊断辅助入口
