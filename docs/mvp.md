# Antigravity Proxy Launcher 全量实施路线图

## 1. 文档定位

本文件不再定义 MVP，而是定义一条完整的产品化实施路线。

目标不是“先做一个最小可用 demo”，而是把 `Antigravity Proxy Launcher` 从当前的技术能力，逐步建设成一个可持续分发、可维护、可诊断、可迭代的 macOS 桌面产品。

本文档回答三个问题：

1. 最终要做成什么样
2. 全量要建设哪些能力
3. 先做什么、后做什么、每一步完成标准是什么

本文档与 [app.md](/Users/kevinliangx/Developer/Repos/PublicCodeHub/KevinLiangX/AntigravityProxyApp/docs/app.md) 的关系：

- `app.md` 负责说明总体方案和推荐架构
- 本文负责说明完整落地顺序和全量建设范围

---

## 2. 最终产品目标

最终产品不是一个脚本仓库，也不是一个只会“重新签名 + 注入”的技术工具，而是一个完整的桌面分发体系。

最终目标形态包括：

- 一个正式分发的 `Antigravity Proxy Launcher.app`
- 一个稳定的本地 Patch Engine
- 一个结构化的兼容性管理系统
- 一个可视化的配置、修复、启动和诊断界面
- 一套完整的日志、诊断和反馈链路
- 一套可持续发布的 DMG/ZIP 分发体系
- 一套能适应上游 App 版本变更的维护机制

用户体验目标：

- 用户下载 Launcher
- 双击打开
- 自动检测原版 Antigravity
- 一键修复并启动
- 出现问题时有明确提示
- 需要修复时可以一键重新适配
- 不需要理解脚本、终端、签名细节

---

## 3. 全量能力地图

为了避免边做边散，先把完整能力版图列出来。

### 3.1 后端能力

- 目标 App 检测
- 兼容性校验
- Patch 流程编排
- 资源嵌入
- Bundle 修改
- 重签名
- 数据迁移
- 启动控制
- 运行验证
- 日志写入
- 诊断导出
- 兼容规则更新
- 版本元数据管理
- 失败恢复与清理

### 3.2 前端能力

- 首页状态总览
- 修复与启动主流程
- 代理配置编辑
- 日志查看入口
- 诊断页
- 设置页
- 兼容性状态提示
- 更新提示
- 安装引导
- 错误提示与修复建议

### 3.3 测试能力

- 单机首次安装测试
- 升级后重修复测试
- 代理在线/离线测试
- 兼容版本矩阵测试
- arm64 / x64 测试
- patch 失败场景测试
- 诊断导出测试
- 分发包安装测试
- 灰度发布验证

### 3.4 分发与运营能力

- DMG 打包
- ZIP 兜底分发
- 架构区分下载
- 发布页
- 兼容性说明页
- 常见问题文档
- 已知问题追踪
- 版本发布节奏

---

## 4. 实施原则

完整路线必须遵守以下原则：

### 4.1 先内核，后界面

如果 Patch Engine 不稳定，GUI 只会把问题包装得更隐蔽。

### 4.2 先结构化，后堆功能

先建立清晰的：

- 数据模型
- 状态机
- 服务边界
- 日志规范

再继续往上加功能。

### 4.3 先本地稳定，后分发优化

先让本地机器上稳定跑通，再去做 DMG、下载页、安装引导。

### 4.4 先显式支持，后扩展兼容

未知版本默认不盲 patch。

### 4.5 每个 phase 只做一个维度

根据约束：

- phase 中只能安排后端或者前端或者测试
- 不混做

---

## 5. 总体阶段安排

完整路线分为 12 个 phase。

顺序如下：

1. 后端：工程骨架与模型层
2. 后端：检测与兼容性系统
3. 后端：Patch Engine 基础版
4. 后端：签名、迁移、启动、验证闭环
5. 前端：主流程界面
6. 测试：核心链路验证
7. 前端：配置、诊断、设置体系
8. 后端：版本管理、失败恢复、规则更新
9. 测试：兼容矩阵与回归体系
10. 前端：分发体验与安装引导
11. 后端：发布支持与运维支撑
12. 测试：灰度发布与正式发布验收

后文会把每个 phase 具体展开。

---

## 6. Phase 1：后端

### 6.1 目标

建立工程基础设施，让后续所有功能有稳定落点。

### 6.2 任务

- 初始化 `launcher/` 工程
- 建立目录结构
- 建立 `Models / Services / Utilities / Compatibility / Resources`
- 建立 `CommandRunner`
- 建立 `FileSystemPaths`
- 建立统一日志写入工具
- 定义核心数据模型

### 6.3 必建模型

- `AppStatus`
- `AppInfo`
- `PatchMetadata`
- `ProxyConfig`
- `CompatibilityRule`
- `PatchResult`
- `DiagnosticSnapshot`

### 6.4 输出物

- 可编译的基础工程
- 核心模型与工具类
- 基础日志和路径系统

### 6.5 完成标准

- 后续服务已有统一模型可依赖
- 已不存在“所有逻辑塞进一个 service”的风险

---

## 7. Phase 2：后端

### 7.1 目标

建立“识别目标 App 并判断是否支持”的能力。

### 7.2 任务

- 实现 `AppDetectionService`
- 扫描原版 App 路径
- 读取 `Info.plist`
- 读取版本、Bundle ID、主执行路径、架构信息
- 建立 `CompatibilityService`
- 设计并落地 `compatibility.json`
- 建立“不支持原因”的结构化表达

### 7.3 输出物

- 可以明确判断：
  - 是否安装原版 App
  - 是否为支持版本
  - 是否具备 patch 前提

### 7.4 完成标准

- GUI 尚未接入，但代码层已经能给出明确状态
- 未知版本不会被错误放行

---

## 8. Phase 3：后端

### 8.1 目标

完成 Patch Engine 的主链路基础版。

### 8.2 任务

- 实现 `PatchService`
- 建立工作目录策略
- 实现原版 App 复制
- 实现 `xattr` 清理
- 实现运行时资源嵌入
- 实现配置文件生成与写入
- 实现 `Info.plist` 修改
- 建立 patch 元数据写入

### 8.3 需要产出的核心函数

- `detectInstalledTargetApp()`
- `preparePatchedBundle()`
- `embedRuntimeAssets()`
- `rewriteInfoPlist()`
- `persistPatchMetadata()`

### 8.4 输出物

- 一个可执行的 patch 基础流程

### 8.5 完成标准

- 能正确生成 patched app 目录结构
- 资源和配置能被嵌入到目标位置

---

## 9. Phase 4：后端

### 9.1 目标

把 patch 基础版补齐成完整闭环。

### 9.2 任务

- 实现 `SigningService`
- 枚举 Mach-O 并 inside-out 重签名
- 顶层 bundle 重签
- 实现 `MigrationService`
- 实现 `LaunchService`
- 实现 patch 后验证逻辑
- 建立统一错误码和错误原因

### 9.3 增加的验证点

- `codesign --verify`
- 主执行文件存在
- `dylib` 在位
- 配置文件在位
- `LSEnvironment` 正确

### 9.4 输出物

- detect -> patch -> migrate -> launch -> verify 全链路后端闭环

### 9.5 完成标准

- 在无 GUI 条件下，代码层已能稳定完成完整流程

---

## 10. Phase 5：前端

### 10.1 目标

做第一个能让用户真正使用的 Launcher 主界面。

### 10.2 任务

- 建立 `AppViewModel`
- 首页状态卡片
- 检测结果展示
- `修复并启动`
- `重新修复`
- patch 进度显示
- 基础错误提示
- patch 完成后结果提示

### 10.3 输出物

- 第一个可双击使用的 Launcher 主流程

### 10.4 完成标准

- 用户无需终端即可完成主流程

---

## 11. Phase 6：测试

### 11.1 目标

验证后端闭环和首个 GUI 主流程是否可靠。

### 11.2 测试范围

- 已安装原版 App
- 未安装原版 App
- 支持版本
- 不支持版本
- 首次 patch
- 重复 patch
- patch 后首次启动
- 代理在线
- 代理离线

### 11.3 输出物

- 第一版核心链路测试清单
- 第一版失败场景清单

### 11.4 完成标准

- 主流程的高频错误已被识别并记录

---

## 12. Phase 7：前端

### 12.1 目标

补齐真正可用的桌面产品界面，不只是一页按钮。

### 12.2 任务

- 配置页
- 日志入口
- 诊断页
- 设置页
- 路径展示
- patch 元数据显示
- 版本与兼容状态展示

### 12.3 配置页内容

- host
- port
- type
- connect/send/recv timeout
- log level
- child injection

### 12.4 诊断页内容

- 原版 App 路径
- patched App 路径
- 最近 patch 时间
- 最近错误
- 签名校验摘要
- 导出诊断按钮

### 12.5 输出物

- 一个结构完整的 Launcher UI

### 12.6 完成标准

- 用户能够通过 GUI 完成配置、修复、启动和问题导出

---

## 13. Phase 8：后端

### 13.1 目标

提升可维护性和线上稳定性。

### 13.2 任务

- 实现失败恢复逻辑
- 实现 patch 清理逻辑
- 建立 patch 版本与资源版本关系
- 支持兼容规则更新
- 支持 patch 元数据升级
- 建立更细的错误分类
- 支持诊断包导出

### 13.3 需要补的能力

- patch 失败后自动清理半成品
- 检测 patched app 是否过期
- 检测原版 App 是否升级
- 判断是否需要重新修复

### 13.4 输出物

- 更稳定、可持续维护的 Patch Engine

### 13.5 完成标准

- 不再只能处理“理想路径”
- 对失败、中断、升级场景有明确恢复机制

---

## 14. Phase 9：测试

### 14.1 目标

建立兼容矩阵与回归测试体系。

### 14.2 测试维度

- macOS 多版本
- arm64
- x64
- 多个上游 App 版本
- 原版 App 升级后重新修复
- 多次 patch / 多次启动
- 日志与诊断导出
- patched app 清理与重建

### 14.3 输出物

- 兼容矩阵文档
- 回归测试 checklist
- 已知不支持版本清单

### 14.4 完成标准

- 发布前不再只靠人工印象判断“应该能跑”

---

## 15. Phase 10：前端

### 15.1 目标

补齐分发体验，让产品更接近正式发布形态。

### 15.2 任务

- 安装引导页面
- 未安装原版 App 的引导
- 不支持版本时的清晰说明
- 更新提醒 UI
- 分发文案整合
- 首次使用引导
- 常见问题入口

### 15.3 输出物

- 更完整的用户使用体验

### 15.4 完成标准

- 用户第一次打开产品时不会只看到“失败”
- 常见问题能被 UI 承接一部分

---

## 16. Phase 11：后端

### 16.1 目标

建设发布支持与后续维护支撑能力。

### 16.2 任务

- DMG 打包脚本
- ZIP 兜底打包
- 资源版本校验
- 发布包内容校验
- 兼容规则版本化
- 远程版本信息读取
- 发布日志模板

### 16.3 输出物

- 可重复执行的发布流程

### 16.4 完成标准

- 每次发版不再靠手工拼装资源和临时记忆

---

## 17. Phase 12：测试

### 17.1 目标

在正式公开发布前做灰度验证和最终验收。

### 17.2 测试内容

- 小范围用户安装
- 下载包损坏测试
- 首次运行体验测试
- patch 失败反馈收集
- 诊断包采样验证
- 发布包完整性验证

### 17.3 输出物

- 灰度反馈清单
- 正式发布阻断项列表
- 最终发布验收记录

### 17.4 完成标准

- 有明确的“可以发布 / 暂不发布”依据

---

## 18. 详细模块规划

为了避免 phase 结束后还不清楚文件怎么落，下面补齐模块级规划。

### 18.1 Models

建议文件：

- `AppStatus.swift`
- `AppInfo.swift`
- `PatchMetadata.swift`
- `ProxyConfig.swift`
- `CompatibilityRule.swift`
- `PatchResult.swift`
- `DiagnosticSnapshot.swift`

### 18.2 Services

建议文件：

- `AppDetectionService.swift`
- `CompatibilityService.swift`
- `PatchService.swift`
- `SigningService.swift`
- `MigrationService.swift`
- `LaunchService.swift`
- `DiagnosticsService.swift`
- `UpdateService.swift`

### 18.3 Utilities

建议文件：

- `CommandRunner.swift`
- `FileSystemPaths.swift`
- `PlistEditor.swift`
- `Logger.swift`
- `BundleInspector.swift`
- `MachOScanner.swift`

### 18.4 State

建议文件：

- `AppViewModel.swift`
- `PatchProgressState.swift`
- `SettingsStore.swift`

### 18.5 Views

建议文件：

- `HomeView.swift`
- `ConfigView.swift`
- `DiagnosticsView.swift`
- `SettingsView.swift`
- `UnsupportedVersionView.swift`
- `InstallGuideView.swift`

---

## 19. 资源与路径规划

### 19.1 Launcher 内置资源

- `libAntigravityTun.dylib`
- `entitlements.plist`
- `proxy_config.template.json`
- `compatibility.json`

### 19.2 用户配置路径

建议：

- `~/Library/Application Support/AntigravityProxy/config/proxy_config.json`

### 19.3 Patched App 路径

建议主路径：

- `~/Applications/Antigravity Proxy/Antigravity_Unlocked.app`

备用路径：

- `~/Library/Application Support/AntigravityProxy/patched/Antigravity_Unlocked.app`

### 19.4 日志路径

- `~/Library/Logs/AntigravityProxy/launcher.log`
- `~/Library/Logs/AntigravityProxy/patch.log`
- `~/Library/Logs/AntigravityProxy/runtime.log`

### 19.5 诊断输出路径

- `~/Desktop/AntigravityProxy-Diagnostics-<timestamp>/`

---

## 20. 状态机规划

建议状态枚举保持如下：

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

状态转换主路径：

1. `targetAppMissing`
2. `targetAppInstalled`
3. `patchedAppMissing`
4. `patching`
5. `patchedReady`
6. `launching`
7. `running`

异常路径：

- 原版升级 -> `repairRequired`
- 版本不支持 -> `targetAppUnsupportedVersion`
- patch 失败 -> `error`

---

## 21. 配置体系规划

配置需要分成三类：

### 21.1 用户运行配置

- 代理地址
- 端口
- 超时
- 日志级别
- child injection

### 21.2 Patch 系统配置

- patched app 路径
- 是否自动检测重修复
- 是否启用实验性兼容

### 21.3 产品配置

- Launcher 自身版本
- 兼容规则版本
- 发布通道

---

## 22. 诊断体系规划

诊断包至少包含：

- Launcher 版本
- 当前 macOS 版本
- 当前架构
- 原版 App 信息
- patched App 信息
- patch 元数据
- 当前配置摘要
- patch 日志
- runtime 日志
- 最近错误
- `codesign` 校验摘要

诊断目标：

- 用户反馈可复现
- 团队定位问题快
- 发布前后问题可以归类

---

## 23. 分发规划

### 23.1 分发格式

- 主格式：DMG
- 备用格式：ZIP

### 23.2 架构策略

- `macos-arm64`
- `macos-x64`

### 23.3 下载页信息

下载页至少要写清楚：

- 支持的 macOS 版本
- 支持的 Antigravity 版本
- Apple Silicon / Intel 区分
- 安装后若被拦截如何处理
- 已知问题

---

## 24. 文档规划

最终 docs 目录不应只有两篇文档。

建议后续补充：

- `launcher_architecture.md`
- `compatibility.md`
- `diagnostics.md`
- `release_process.md`
- `qa_checklist.md`
- `known_issues.md`

---

## 25. 先后顺序的核心逻辑

为什么是这个顺序，而不是先做 UI 或先做分发？

原因如下：

1. 没有后端骨架，后续所有功能都会漂移
2. 没有 Patch Engine 闭环，GUI 没有意义
3. 没有测试兜底，修复功能会反复回归
4. 没有配置和诊断页，产品难以支撑真实用户
5. 没有分发和发布流程，工程永远停留在内部工具

这也是为什么本路线是：

- 先后端
- 再前端
- 再测试
- 再补前端
- 再补后端
- 再做发布与灰度

---

## 26. 每阶段是否可发布

不同 phase 结束后，产品成熟度不同。

### Phase 1-2 后

- 不可发布
- 仅工程基础阶段

### Phase 3-4 后

- 不建议公开发布
- 可内部技术验证

### Phase 5-6 后

- 可小范围内部试用

### Phase 7-9 后

- 可小范围外部测试

### Phase 10-12 后

- 才适合正式公开分发

---

## 27. 最终建议

这条路线的核心不是“先做一个最小版本凑合上线”，而是：

- 从一开始就按完整产品思路设计
- 但在执行上明确先后顺序
- 每个阶段只解决一个维度的问题

最终推荐执行顺序再次总结如下：

1. 后端：工程骨架与模型层
2. 后端：检测与兼容性系统
3. 后端：Patch Engine 基础版
4. 后端：签名、迁移、启动、验证闭环
5. 前端：主流程界面
6. 测试：核心链路验证
7. 前端：配置、诊断、设置体系
8. 后端：版本管理、失败恢复、规则更新
9. 测试：兼容矩阵与回归体系
10. 前端：分发体验与安装引导
11. 后端：发布支持与运维支撑
12. 测试：灰度发布与正式发布验收

如果严格按这个顺序推进，项目会从“当前可行的技术能力”逐步过渡为“类似 figmaEX 的可分发产品”。
