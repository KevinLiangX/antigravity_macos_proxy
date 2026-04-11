# AntigravityProxyApp 配额监控阶段状态

更新时间: 2026-04-11

## 当前总体状态

状态: In Progress

说明:

- 已完成对 `AntigravityQuotaWatcherDesktop` 的实现分析
- 已确定授权和配额监控的总体技术方案
- 已启动 Phase 1 落地，完成基础模型与 Keychain Token 存储层首版实现

参考设计文档：

- [quota_monitoring_design.md](/Users/kevinliangx/Developer/Repos/PublicCodeHub/KevinLiangX/AntigravityProxyApp/docs/quota_monitoring_design.md)

---

## Phase 1 后端: 模型层与存储层

状态: In Progress

目标:

- 建立账户、token、配额相关数据模型
- 建立 Keychain token 存储能力

任务:

- 新增 `GoogleAccount`
- 新增 `OAuthToken`
- 新增 `ProjectInfo`
- 新增 `ModelQuotaInfo`
- 新增 `QuotaSnapshot`
- 新增 `QuotaStatus`
- 新增 `TokenStoreService`

完成标准:

- Keychain 中可写入 / 读取 token
- 基础模型可被后续服务复用

当前进展:

- 已新增 `GoogleAccount` / `OAuthToken` / `ProjectInfo` / `ModelQuotaInfo` / `QuotaSnapshot` / `QuotaStatus` / `LoginFlowState`
- 已新增 `TokenStoreService`（基于 Keychain 的 save/load/delete/clear 能力）

---

## Phase 2 后端: Google 授权登录闭环

状态: In Progress

目标:

- 完成浏览器登录 + 本地回调 + token 交换 + token 持久化

任务:

- 实现 `GoogleOAuthService`
- 实现 `OAuthCallbackServer`
- 实现 PKCE
- 实现 `state` 校验
- 实现 token 交换
- 实现 user info 获取
- 实现登出流程

完成标准:

- 用户可以在本地完成一次完整登录
- 成功登录后 Keychain 中存在 token

当前进展:

- 已新增 `OAuthCallbackServer`，支持本地随机端口监听、state 校验、超时与取消
- 已新增 `GoogleOAuthService`，实现 PKCE、浏览器授权、code 换 token、userinfo、Keychain 持久化
- 已新增 `AccountStoreService` 管理本地账户列表与 active account
- OAuth 凭据改为环境变量读取（`AG_GOOGLE_CLIENT_ID` / `AG_GOOGLE_CLIENT_SECRET`）
- 已新增 `AuthViewModel` 并接入总览页认证面板（登录/取消/登出/Token 校验）

---

## Phase 3 测试: 授权链路验证

状态: Not Started

目标:

- 验证授权流程的稳定性

任务:

- 首次登录
- 取消登录
- 回调超时
- token 刷新
- Keychain 读写验证
- 错误提示验证

完成标准:

- 有一份授权测试清单和执行记录

---

## Phase 4 后端: 配额 API 与轮询能力

状态: In Progress

目标:

- 实现配额 API 客户端、轮询和缓存

任务:

- 实现 `QuotaApiClient`
- 实现 `QuotaPollingService`
- 实现 `QuotaCacheService`
- 实现 project info 拉取
- 实现 model quota 拉取
- 实现 retry 和错误分类
- 接入代理配置

完成标准:

- 可手动刷新并拿到 quota snapshot
- 可定时轮询刷新

当前进展:

- 已新增 `QuotaApiClient`（project info / models quota 拉取与错误分类）
- 已新增 `QuotaCacheService`（`quota_snapshot.json` 本地快照缓存）
- 已新增 `QuotaPollingService`（手动刷新、自动轮询、基础重试）
- 已新增 `QuotaViewModel` 并接入总览页，支持“立即刷新配额 / 开启自动刷新 / 顶部模型摘要展示”
- 已将配额自动刷新开关与轮询间隔接入 `AppSettings` 持久化，并在总览页按设置自动启动轮询
- 已细化 quota 错误提示（认证失效/限流/网络/服务端/解析）提升可诊断性
- 已实现多账户刷新与缓存隔离（按 accountId 存取快照），支持账户切换后显示对应快照
- 已新增独立 `QuotaView` 页面，提供账户切换、刷新全部账户、自动轮询和完整模型列表展示
- 已在 `QuotaView` 增加模型排序与筛选（按剩余升序/降序、按名称、仅看耗尽模型）
- 已将配额轮询状态摘要接入诊断导出（`summary.json` 含 quotaDiagnostics 字段）
- 已实现设置变更实时生效：自动刷新开关与轮询间隔修改后无需重启页面即可生效
- 已修复无活跃账户场景下的账户选择边界（支持空选择占位并安全回退到缓存账户）

---

## Phase 5 前端: 账户页与配额页

状态: Not Started

目标:

- 在 GUI 中展示授权状态和配额状态

任务:

- 实现 `AuthViewModel`
- 实现 `QuotaViewModel`
- 实现 `AccountsView`
- 实现 `QuotaView`
- 增加登录 / 登出按钮
- 增加手动刷新按钮
- 展示 tier / last refresh / 模型列表

完成标准:

- GUI 可完成登录并展示当前模型配额

---

## Phase 6 测试: 配额监控链路验证

状态: Not Started

目标:

- 验证配额监控链路

任务:

- 登录后刷新 quota
- 自动轮询
- 网络失败重试
- token 过期自动刷新
- 代理开启 / 关闭
- 配额缓存恢复

完成标准:

- 有一份 quota 测试清单和执行记录

---

## Phase 7 前端: 产品化增强

状态: Not Started

目标:

- 提升监控功能的实际可用性

任务:

- 上次刷新时间显示
- 错误状态与空状态
- tier 展示优化
- 模型别名或排序（可选）
- 自动刷新状态提示

完成标准:

- 配额监控具备稳定的日常使用体验

---

## Phase 8 后端: 多账户与稳定性扩展

状态: Not Started

目标:

- 支持多账户与更完整的缓存和错误恢复

任务:

- 多账户 token 管理
- 多账户轮询
- active account 切换
- quota snapshot 多账户缓存
- 统一诊断导出

完成标准:

- 多账户可切换并独立展示额度

---

## 当前优先顺序

1. Phase 1 后端: 模型层与存储层
2. Phase 2 后端: Google 授权登录闭环
3. Phase 3 测试: 授权链路验证
4. Phase 4 后端: 配额 API 与轮询能力
5. Phase 5 前端: 账户页与配额页
6. Phase 6 测试: 配额监控链路验证
7. Phase 7 前端: 产品化增强
8. Phase 8 后端: 多账户与稳定性扩展

---

## 当前结论

这条能力线适合独立推进，不建议直接掺进 patch 主线。

更准确的定位应当是：

- `AntigravityProxyApp` 主功能仍然是 Launcher / patch / repair
- quota monitoring 是新增的第二条能力线
- 应该通过独立的 Auth / Quota 模块接入，而不是塞进现有 patch 服务
