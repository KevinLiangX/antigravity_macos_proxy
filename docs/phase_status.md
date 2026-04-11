# AntigravityProxyApp 阶段验收状态

更新时间: 2026-04-10

## 当前总体判断

项目已经完成了：

- Patch Engine 核心能力
- 检测 / 兼容性 / 修复 / 验证 / 启动 / 诊断 / 配置 / 设置
- 开发期 GUI 原型
- CLI 诊断能力

但当前工程形态仍然主要是：

- 开发期 Swift Package 可执行程序

还没有完成：

- 标准 macOS `Launcher.app`
- 正式 App bundle 资源封装
- `.app` / `.dmg` 分发形态

因此，当前阶段状态应该定义为：

- **后端核心能力基本完成**
- **开发期 GUI 已完成**
- **App 化与正式分发尚未完成**

---

## Phase 1 后端: 工程骨架与模型层

状态: Completed

已完成:
- `launcher/` 工程初始化
- `Models / Services / Utilities / Compatibility / Resources` 建立
- `CommandRunner` 与 `FileSystemPaths` 建立
- 基础日志工具建立
- 核心模型全部落地

---

## Phase 2 后端: 检测与兼容性系统

状态: Completed

已完成:
- `AppDetectionService` 读取 `Info.plist`
- 输出版本、Bundle ID、主执行路径、架构
- `CompatibilityService + compatibility.json`
- 未支持版本可给出明确状态
- 兼容规则远程拉取、本地缓存、可信域名白名单、可选 SHA256 校验

备注:
- 缓存损坏后回退内置规则的容错仍需加强

---

## Phase 3 后端: Patch Engine 基础版

状态: Completed

已完成:
- `PatchService` 主流程
- 原版复制
- `xattr` 清理
- 资源嵌入
- `Info.plist` 写入
- patch 元数据写入
- patch 失败自动回滚半成品

备注:
- `LSEnvironment` 当前使用绝对路径，后续建议收敛回相对路径方案

---

## Phase 4 后端: 签名、迁移、启动、验证闭环

状态: Completed with Risks

已完成:
- `SigningService` inside-out 重签名
- `MigrationService` 数据迁移
- `LaunchService` 启动修复版
- `PatchVerificationService` 验证点:
  - `codesign --verify`
  - 主执行文件在位
  - `dylib/config` 在位
  - `LSEnvironment` 校验
- CLI 命令:
  - `--doctor`
  - `--verify-patched`
  - `--patch-and-launch`
- 统一错误码体系

风险:
- 启动参数尚未完全对齐原 `run_unlocked.sh`
- 数据迁移逻辑仍比原 `migrate_data.sh` 精简
- 真实 Electron 嵌套代码签名稳定性仍需更多回归验证

---

## Phase 5 前端: 主流程界面

状态: Completed (Development Mode)

已完成:
- 首页状态总览
- 检测结果展示
- 修复并启动主按钮
- 流程步骤展示
- 实时日志面板
- 基础错误提示

说明:
- 这一阶段完成的是“开发期 GUI 原型”
- 不是最终 `Launcher.app` 形态

---

## Phase 6 测试: 核心链路验证

状态: Completed (Development Coverage)

已完成:
- 测试清单文档: `docs/phase6_test_plan.md`
- 首轮执行记录: `docs/phase6_test_report.md`
- 自动化验证脚本: `launcher/scripts/phase6_validation.sh`
- 支持版本路径验证: PASS
- 不支持版本路径验证: PASS

待补充:
- 代理离线场景
- GUI 交互路径回归
- 签名失败路径回归
- 缓存损坏 / 规则损坏容错测试

---

## Phase 7 前端: 配置、诊断、设置体系

状态: Completed (Development Mode)

已完成:
- 诊断导出按钮
- 日志入口
- 配置页
- 诊断页
- 设置页
- 诊断历史记录
- 失败聚合

说明:
- 页面功能已具备
- 但仍运行在开发期 GUI 入口，不是正式 App 分发形态

---

## Phase 8 后端: 版本管理、失败恢复、规则更新

状态: Completed with Risks

已完成:
- patch 失败自动回滚
- patched app 过期检测
- patched app 健康检查
- 失败自动导出诊断
- 规则更新机制
- 可信来源校验
- 可选 SHA256 校验

风险:
- 本地缓存规则损坏时，当前仍可能阻断主流程

---

## Phase 9 测试: 兼容矩阵与回归体系

状态: In Progress

已完成:
- 基础自动化脚本雏形
- 部分支持版本 / 不支持版本验证

未完成:
- 多 macOS 版本矩阵
- arm64 / x64 全量回归
- 迁移路径全量验证
- 真实签名失败样本回归
- patched app 移动路径回归

---

## Phase 10 前端: App 化与分发体验

状态: Not Started

目标:
- 将当前开发期 GUI 迁移为标准 macOS `Launcher.app`
- 从 App bundle 读取资源
- 让应用可双击启动并稳定显示窗口
- 补齐首次安装引导与分发体验

原因:
- 当前 `swift run` 形态不是正式桌面应用
- 用户不能把它当成像 `figmaEX` 一样的客户端来使用

参考文档:
- `docs/launcher_appification.md`

---

## Phase 11 后端: 发布支持与运维支撑

状态: Not Started

目标:
- Launcher 自身签名
- `.app` 产物校验
- `.dmg` / `.zip` 打包流程
- 发布工单和产物校验

说明:
- 当前发布手册仍带有开发期 `swift build / swift run` 口径
- App 化完成后需要切换到正式发布产物流程

---

## Phase 12 测试: 灰度发布与正式发布验收

状态: Not Started

目标:
- `.app` / `.dmg` 实机安装验证
- 小范围灰度发布
- 发布后回滚演练
- 正式发布验收

---

## 当前阶段总结

从能力成熟度上看：

- 后端核心能力: 70% - 80%
- 开发期 GUI: 70%
- 正式桌面产品形态: 20%
- 分发与发布体系: 20%

因此当前项目不应再被描述为：

- “Launcher.app 已完成”

更准确的描述应当是：

- “Launcher 核心逻辑已完成，正在从开发期程序向正式 App 过渡”

---

## 下一阶段优先顺序

1. Phase 10 前端: 完成 App 化改造
2. Phase 11 后端: 完成 `.app` / `.dmg` 发布支持
3. Phase 9 测试: 补齐兼容矩阵和回归体系
4. Phase 12 测试: 灰度发布与正式发布验收
