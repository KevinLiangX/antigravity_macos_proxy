# AntigravityProxyApp 模型配额监控实施方案

## 1. 目标

本方案用于在 `AntigravityProxyApp` 中新增：

- Google 账户授权登录
- Access Token / Refresh Token 管理
- 模型配额查询
- 配额轮询刷新
- GUI 展示当前模型使用情况

设计原则：

- **授权方式参考** `AntigravityQuotaWatcherDesktop`
- **模型配额监控架构参考** `AntigravityQuotaWatcherDesktop`
- **代码不直接复制**，在 `AntigravityProxyApp` 中使用 Swift 重写
- **Token 存储改用 Keychain**
- **监控模块与 Launcher patch 模块解耦**

---

## 2. 参考来源

本方案主要参考以下模块的职责划分和流程设计：

- `src/main/auth/googleAuthService.ts`
- `src/main/auth/callbackServer.ts`
- `src/main/auth/tokenStorage.ts`
- `src/shared/api/googleCloudCodeClient.ts`
- `src/main/quota/quotaService.ts`
- `src/shared/types.ts`

参考仓库：

- [AntigravityQuotaWatcherDesktop](/Users/kevinliangx/Developer/Repos/PublicCodeHub/KevinLiangX/AntigravityQuotaWatcherDesktop)

注意：

- `AntigravityQuotaWatcherDesktop` 为 GPL-3.0 项目
- 本方案只参考其架构与职责划分
- `AntigravityProxyApp` 中应使用 Swift 自行实现

---

## 3. 最终能力范围

新增功能完成后，`AntigravityProxyApp` 应支持：

### 3.1 授权能力

- 系统浏览器打开 Google 登录页
- 本地回调服务接收授权码
- PKCE
- `state` 防 CSRF
- 交换 access token / refresh token
- 获取用户账户信息
- Keychain 安全存储 token
- token 过期自动刷新

### 3.2 配额能力

- 查询当前账户 project info
- 查询模型可用配额
- 过滤并解析目标模型
- 本地缓存快照
- 手动刷新
- 定时轮询
- 错误重试
- 认证失效提示重新登录

### 3.3 UI 能力

- 账户登录 / 登出
- 当前账户展示
- 配额概览页
- 模型配额列表
- 上次刷新时间
- 刷新状态
- 错误状态

---

## 4. 总体架构

推荐拆分为四层。

### 4.1 Auth Layer

职责：

- Google 登录
- 回调接收
- token 交换
- token 刷新
- token 存储

### 4.2 Quota API Layer

职责：

- 调用 Google Cloud Code 相关 API
- 获取 project info
- 获取模型配额
- 解析返回结构
- 错误分类

### 4.3 Quota Polling Layer

职责：

- 轮询
- 缓存
- 重试
- 状态通知

### 4.4 UI Layer

职责：

- 账户页
- 配额页
- 登录状态展示
- 刷新结果展示

---

## 5. 模块拆分

建议新增以下文件。

### 5.1 Models

```text
launcher/Sources/Models/GoogleAccount.swift
launcher/Sources/Models/OAuthToken.swift
launcher/Sources/Models/LoginFlowState.swift
launcher/Sources/Models/QuotaSnapshot.swift
launcher/Sources/Models/ModelQuotaInfo.swift
launcher/Sources/Models/QuotaStatus.swift
launcher/Sources/Models/ProjectInfo.swift
```

### 5.2 Services

```text
launcher/Sources/Services/GoogleOAuthService.swift
launcher/Sources/Services/OAuthCallbackServer.swift
launcher/Sources/Services/TokenStoreService.swift
launcher/Sources/Services/QuotaApiClient.swift
launcher/Sources/Services/QuotaPollingService.swift
launcher/Sources/Services/QuotaCacheService.swift
launcher/Sources/Services/UserInfoService.swift
```

### 5.3 State

```text
launcher/Sources/State/AuthViewModel.swift
launcher/Sources/State/QuotaViewModel.swift
```

### 5.4 Views

```text
launcher/Sources/Views/AccountsView.swift
launcher/Sources/Views/QuotaView.swift
```

---

## 6. 授权实现方案

### 6.1 授权方式

采用：

- **Authorization Code Flow + PKCE**
- **系统浏览器**
- **本地回调 HTTP Server**

不建议：

- 内嵌 WebView 登录
- 通过 cookie / session 逆向方式获取凭证

### 6.2 登录流程

登录流程设计如下：

1. 用户点击“登录 Google”
2. `GoogleOAuthService` 生成：
   - `state`
   - `codeVerifier`
   - `codeChallenge`
3. `OAuthCallbackServer` 启动在 `127.0.0.1` 的临时端口
4. 构造授权 URL
5. 使用系统浏览器打开授权 URL
6. 用户完成授权
7. Google 回调到本地 `http://127.0.0.1:<port>/callback`
8. 本地服务接收 `code` 和 `state`
9. 校验 `state`
10. 用授权码换取 token
11. 拉取用户信息
12. 将 token 写入 Keychain
13. 将账户信息写入本地配置或账户存储
14. 更新 UI 状态为已登录

### 6.3 登录状态枚举

建议定义：

- `idle`
- `preparing`
- `openingBrowser`
- `waitingAuthorization`
- `exchangingToken`
- `success`
- `error`
- `cancelled`

该状态机可直接参考 `AntigravityQuotaWatcherDesktop` 的 UI 交互设计，但由 Swift 实现。

### 6.4 回调服务

`OAuthCallbackServer` 职责：

- 启动随机端口监听
- 生成 redirect URI
- 接收 callback
- 校验 path
- 校验 `state`
- 提供 timeout
- 提供取消能力

### 6.5 Token 存储

必须使用：

- **Keychain**

不建议沿用 `AntigravityQuotaWatcherDesktop` 的：

- `electron-store + safeStorage + auth.json`

原因：

- `AntigravityProxyApp` 是 macOS 原生项目
- Keychain 更符合平台习惯
- 也更适合长期管理 refresh token

### 6.6 存储策略

建议：

- Keychain 存：
  - access token
  - refresh token
  - expiresAt
  - tokenType
  - scope

- App Support 配置文件存：
  - accountId
  - email
  - 显示名称
  - 是否为活跃账户

### 6.7 Token 刷新

`GoogleOAuthService` 需要提供：

- `getValidAccessToken(accountId?)`

逻辑：

- 读取 Keychain token
- 判断是否将要过期
- 若即将过期，则使用 refresh token 刷新 access token
- 刷新后回写 Keychain
- 最终返回有效 access token

建议默认提前 5 分钟刷新。

---

## 7. 配额监控实现方案

### 7.1 核心思路

配额监控不应耦合在 Launcher 的 patch 流程里，而应作为独立服务存在。

依赖关系：

- 配额服务依赖认证服务提供 token
- UI 通过 ViewModel 订阅配额状态

### 7.2 `QuotaApiClient`

职责：

- 调用 Cloud Code API
- 获取 project info
- 获取模型配额
- 解析结构
- 错误分类
- 支持代理

建议提供方法：

- `loadProjectInfo(accessToken: String) async throws -> ProjectInfo`
- `fetchModelsQuota(accessToken: String, projectId: String) async throws -> [ModelQuotaInfo]`

### 7.3 `QuotaPollingService`

职责：

- 定时刷新
- 手动刷新
- 结果缓存
- 错误重试
- 认证失效后通知 UI

建议提供方法：

- `startPolling()`
- `stopPolling()`
- `refreshNow() async`
- `getCachedSnapshot()`
- `setPollingInterval(_:)`

### 7.4 `QuotaCacheService`

职责：

- 落盘最后一次快照
- 启动时读取旧数据
- 让 UI 在首次刷新前也有显示内容

建议存储位置：

- `~/Library/Application Support/AntigravityProxy/quota_snapshot.json`

### 7.5 模型过滤策略

参考 `AntigravityQuotaWatcherDesktop` 的做法：

- 过滤目标模型族
- 只显示有监控意义的模型

第一版建议保守一点：

- 先只展示 API 返回里带 quota 的模型
- 后面再做更细的白名单或别名策略

### 7.6 错误分类

建议至少分：

- `unauthorized`
- `tokenExpired`
- `networkError`
- `serverError`
- `rateLimited`
- `parseError`
- `unsupportedResponse`

这样 UI 才能区分：

- 需要重新登录
- 稍后重试
- 当前网络异常

---

## 8. 数据模型设计

### 8.1 `GoogleAccount`

字段建议：

- `id`
- `email`
- `name`
- `avatarURL`
- `isActive`

### 8.2 `OAuthToken`

字段建议：

- `accessToken`
- `refreshToken`
- `expiresAt`
- `tokenType`
- `scope`

### 8.3 `ProjectInfo`

字段建议：

- `projectId`
- `tier`

### 8.4 `ModelQuotaInfo`

字段建议：

- `modelId`
- `displayName`
- `remainingFraction`
- `remainingPercentage`
- `isExhausted`
- `resetTime`

### 8.5 `QuotaSnapshot`

字段建议：

- `timestamp`
- `userEmail`
- `tier`
- `models`

### 8.6 `QuotaStatus`

建议枚举：

- `idle`
- `fetching`
- `retrying(Int)`
- `ready`
- `reauthRequired`
- `error(String)`

---

## 9. UI 设计

先把“监控操作”直接塞进总览页右上那块空白区域，这样主流程还是一眼能看全：

左边：Patch / 启动 / 应用状态
右边：账户登录 / 配额监控 / 刷新状态
这是最自然的第一版。

我建议右侧这块直接做成一个 监控面板，内容分 4 段

账户状态
当前是否已登录
当前账户邮箱
登录 Google
登出
监控控制
立即刷新
自动刷新开关
轮询间隔展示
上次刷新时间
配额摘要
当前 tier
模型数量
剩余最低的 2-3 个模型
是否有耗尽模型
状态提示
未登录
正在登录
正在刷新
需要重新授权
刷新失败
落到你这张页面，我建议这样摆

总览页上半区改成左右两栏：

左栏保持现在的“已检测到应用”
右栏新增“Google 配额监控”
下半区保持不变：

左下：流程进度
右下：实时日志
也就是说，结构变成：

[标题]
[当前状态]

[左：应用信息卡]   [右：配额监控卡]

[按钮行]

[左：流程进度]     [右：实时日志]
这样改动最小，也不会破坏你现在已经做好的总览布局。

右侧监控卡建议的第一版内容

标题：

Google 配额监控
状态行：

状态：未登录 / 已登录 / 刷新中 / 错误
账户区：

账户：xxx@gmail.com
Tier：PRO
上次刷新：2 分钟前
按钮区：

登录
登出
立即刷新
模型区：

Gemini 3 Pro 72%
Gemini 3 Flash 18%
Claude ...
查看全部（后续可扩）
未登录时：

显示一段说明
只显示 登录 Google
实现上怎么接

你现在的 HomeView.swift 已经是左右分栏的风格，直接在“已检测到应用”那个卡片的右边补一张卡最合适。

建议新增：

QuotaSummaryCard.swift
AuthViewModel.swift
QuotaViewModel.swift
然后在 OverviewView 里改成：

左：AppInfoCard
右：QuotaSummaryCard
---

## 10. 与现有 Launcher 的集成方式

### 10.1 不要把 Quota 逻辑塞进 `LauncherAppState`

当前 `LauncherAppState` 已经负责：

- patch
- sign
- migrate
- launch
- diagnostics

不建议继续膨胀。

### 10.2 建议新增独立状态对象

- `AuthViewModel`
- `QuotaViewModel`

并在根视图中注入。

### 10.3 与 patch 模块关系

关系应当是：

- **共享同一个应用**
- **逻辑上独立**

也就是说：

- patch 流程失败，不影响 quota 页面存在
- quota 登录失败，不影响 patch 功能使用

---

## 11. 安全与边界

### 11.1 不直接复制 GPL 代码

必须自己重写。

### 11.2 不把 token 放入普通配置文件

必须走 Keychain。

### 11.3 不把 OAuth 敏感配置随意硬编码公开仓库

至少需要做到：

- 明确区分公开代码与发布时注入配置

### 11.4 不把监控能力与用户 patch 数据混在一起

认证存储、patch 配置、quota 快照要分目录管理。

---

## 12. 推荐目录补充

建议在 `AntigravityProxyApp/launcher` 中增加：

```text
Sources/
  Models/
    GoogleAccount.swift
    OAuthToken.swift
    LoginFlowState.swift
    ProjectInfo.swift
    ModelQuotaInfo.swift
    QuotaSnapshot.swift
    QuotaStatus.swift
  Services/
    GoogleOAuthService.swift
    OAuthCallbackServer.swift
    TokenStoreService.swift
    QuotaApiClient.swift
    QuotaPollingService.swift
    QuotaCacheService.swift
  State/
    AuthViewModel.swift
    QuotaViewModel.swift
  Views/
    AccountsView.swift
    QuotaView.swift
```

---

## 13. 最终建议

推荐路线是：

- 授权流程参考 `AntigravityQuotaWatcherDesktop`
- 配额监控架构参考 `QuotaApiClient + QuotaPollingService`
- 在 `AntigravityProxyApp` 中全部用 Swift 重写
- Keychain 替代 `auth.json + safeStorage`
- 先做单账户，再做多账户

这是在技术可行性、工程整洁度和项目边界上最稳的方案。
