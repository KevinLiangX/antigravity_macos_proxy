# 1. antigravity-macos- proxy
主要针对MacOS用户采用proxifier和代理软件或者tun模式使用antigravity IDE 工具的场景进行优化。使用MacOS的DYLD透明注入的方式，实现antigravity无全局代理方式使用。

## 1.1 功能特性 (Features)

- ✅ **透明代理**：无需修改应用程序，自动拦截网络请求
- ✅ **FakeIP 技术**：将域名映射到虚假 IP，实现域名级别的流量控制
- ✅ **SOCKS5 支持**：通过 SOCKS5 代理转发流量
- ✅ **多进程支持**：通过共享内存在多进程间同步 FakeIP 映射
- ✅ **灵活配置**：支持 JSON 配置文件，可自定义代理、端口、超时等参数
- ✅ **进程过滤**：可选择性地只对特定进程生效
- ✅ **Socket 适配**：完美适配阻塞与非阻塞 Socket 模式，解决 Agent 与代理交互问题

# 2. 为什么要搞这个？
macOS 更新到最新版本，使用代理动不动网络就异常。使用VPN也是tun模式，要是开启clash的tun模式，简直是灾难。
主要参考 `yuaotian/antigravity-proxy`和`Mac-XK/AntigravityTun`两位大佬的项目。
1. antigravity-proxy 项目，在win11和 wsl2上面都可以使用，使用win11或者wsl2的用户可以使用。
2. Mac-XK/AntigravityTun项目，好像该大佬不维护了，我试了好几次，都没成功。提供了扩展思路

# 3. 整体问题分析过程
动态链接库的侵入，可以看下Mac-XK/AntigravityTun项目。该大佬讲的很明白。但是该大佬项目为啥不行？

目标应用（antigravity）开启了 macOS 的 **Hardened Runtime** (强化运行时) 安全机制，且缺失了允许注入的关键 Entitlements（权限）：
1.  **缺少** `com.apple.security.cs.disable-library-validation`: 这导致系统强制要求所有加载的动态库必须由同一开发者签名或由 Apple 签名。我们的 dylib 是本地编译的，因此被拒绝。
2.  **缺少** `com.apple.security.cs.allow-dyld-environment-variables`: 这导致系统忽略 `DYLD_INSERT_LIBRARIES` 环境变量。
3.  **缺少** `language_server_macos_arm`的签名，导致后面已经到了代理，Agent依然没法加载。

# 4. 解决方案 (Solution)

## 4.1 工作原理 (How it Works)

```
应用程序调用 getaddrinfo("example.com")
         ↓
被 Hook 拦截，返回 FakeIP (198.18.x.x)
         ↓
应用程序调用 connect(198.18.x.x:443)
         ↓
被 Hook 拦截，识别为 FakeIP
         ↓
连接到 SOCKS5 代理服务器
         ↓
发送真实域名 "example.com" 给代理
         ↓
代理完成实际连接
```

## 4.2 解锁方案 (Unlock Mechanism)

**核心思路**: 对目标应用进行 **重签名 (Re-sign)**，植入一个宽松的 `entitlements.plist`，使其允许加载任意库。

### 修改内容 (Changes)

1.  **`entitlements.plist`**:
    创建了一个包含以下关键键值的权限文件：
    *   `<key>com.apple.security.cs.disable-library-validation</key> <true/>` (允许加载未签名/第三方库)
    *   `<key>com.apple.security.cs.allow-dyld-environment-variables</key> <true/>` (允许环境变量注入)
    *   `<key>com.apple.security.cs.allow-jit</key> <true/>` (Electron 应用运行所需)

2.  **`robust_unlock.sh` (重签名脚本)**:
    为了应对复杂的 App 结构（包含多个 Frameworks 和辅助进程），编写了此脚本执行 **Deepest-First (由内向外)** 的递归重签名：
    *   **Step 1**: 复制 `Antigravity.app` 为 `Antigravity_Unlocked.app`。
    *   **Step 2**: 清除所有文件的扩展属性 (`xattr -cr`)。
    *   **Step 3**: 遍历 App 包内所有 Mach-O 二进制文件，按路径深度排序。
    *   **Step 4**: 先移除原有签名，再使用本地 Ad-Hoc 证书 (`--sign -`) 和新的 `entitlements.plist` 重新签名。

### 使用的问题

由于我们移除了原厂签名（Re-signed with ad-hoc identity）：

✅ 核心功能: Electron 应用的 Web 渲染、本地逻辑通常不受影响。

⚠️ iCloud/推送: 如果原应用依赖 Apple 的云服务或推送通知（APS），这些功能会失效（因为它们强绑定签名的 Team ID）。

⚠️ 钥匙串访问: 可能会提示“是否允许访问钥匙串”，需要输入密码授权（因为签名改变了）。**√ 这个是一定会出现的。输入登录你macos的密码就行了。**

⚠️ 自动更新: 内置的自动更新功能通常无法验证新包的签名，可能会破坏解锁状态，建议关闭自动更新。**建议是把原来安装的app留着，方便更新。更新后重新解锁，继续使用。**


# 5. 环境与构建依赖 (Environment & Prerequisites)

在开始之前，请确保你的开发环境满足以下要求：

### 系统要求 (OS)
*   **macOS**: 必须是 macOS 系统 (推荐 macOS 12 Monterey 及以上)，因为项目依赖 `DYLD_INSERT_LIBRARIES` 注入机制。

### 构建工具 (Build Tools)
*   **Xcode**: 这里不安装全部的Xcode，仅安装 Command Line Tools (CLT)。直接使用compile_without_xcode.sh即可
*   **C++ 编译器**: Clang (随 Xcode 附带)，支持 C++17 标准。
*   **Python 3**: 用于运行测试脚本 (`mock_socks5.py`, `test_request.py`)。

### 依赖组件 (Dependencies)
*   本项目无第三方 C++ 库依赖，仅使用 macOS SDK 标准库 (`dlfcn.h`, `sys/socket.h` 等)。

# 6. 使用指南 (Usage Guide)

按照以下步骤即可完成配置并启动。

### 6.1 获取项目与环境准备 (Clone & Prepare)

1.  **下载代码**:
    ```bash
    git clone git@github.com:KevinLiangX/antigravity_macos_proxy.git
    cd antigravity_macos_proxy
    ```

### 6.2 编译动态库 (Build Dylib)

> **选择 A (推荐)**: 运行轻量级编译脚本 (仅需 Command Line Tools，无需安装完整 Xcode)。
> ```bash
> ./compile_without_xcode.sh
> ```

> **选择 B (源码编译)**: 使用 Xcode 项目构建 (需安装完整 Xcode)。
>
> **选择 B (源码编译)**: 如果你是 clone 的源码，修改了源码，可以进行手动编译：

```bash
# 清空干扰项
export DYLD_INSERT_LIBRARIES=""

# 编译生成 dylib
xcodebuild -project AntigravityTun.xcodeproj -scheme AntigravityTun -configuration Release

# (可选) 将编译产物复制到根目录，方便脚本调用
# cp build/Release/libAntigravityTun.dylib .
```

### 6.3 应用解锁 (Unlock App)

此步骤将复制原版应用 (`/Applications/Antigravity.app`)，并进行重签名以注入权限。

```bash
# 确保 entitlements.plist 和 robust_unlock.sh 在当前目录
./robust_unlock.sh
```

*   **执行结果**: 当前目录下会生成一个新的 `Antigravity_Unlocked.app`。

### 6.4 启动运行 (Run)

使用启动脚本加载代理配置并运行解锁后的应用：

```bash
# 1. 修改配置 (如果需修改代理端口)
cp proxy_config.json.example config.json
vim config.json

# 2. 启动应用
./run_unlocked.sh
```
*   **注意**: 过程中可能会弹出“是否允许访问钥匙串”或要求输入密码，请输入当前用户登录密码以授权重签名。
*   
# 7. 配置指南 (Configuration)

## 7.1 创建配置文件

在以下任一位置创建 `proxy_config.json` 配置文件：

- `~/.config/antigravity/config.json` （推荐）
- `./config.json` （当前目录）
- `/tmp/config.json`
- 或通过环境变量 `ANTIGRAVITY_CONFIG` 指定路径

## 7.2 配置文件示例

```json
{
  "log_level": "info",
  "proxy": {
    "host": "127.0.0.1",
    "port": 7890,
    "type": "socks5"
  },
  "fake_ip": {
    "enabled": true,
    "cidr": "198.18.0.0/15"
  },
  "timeout": {
    "connect": 5000,
    "send": 5000,
    "recv": 5000
  },
  "proxy_rules": {
    "allowed_ports": [80, 443, 8080],
    "dns_mode": "direct",
    "ipv6_mode": "proxy",
    "udp_mode": "block"
  },
  "traffic_logging": false,
  "child_injection": true,
  "target_processes": []
}
```

## 7.3 配置项说明

### proxy（代理设置）

| 参数   | 类型   | 默认值        | 说明                          |
| ------ | ------ | ------------- | ----------------------------- |
| `host` | string | `"127.0.0.1"` | SOCKS5 代理服务器地址         |
| `port` | number | `7890`        | SOCKS5 代理服务器端口         |
| `type` | string | `"socks5"`    | 代理类型（目前仅支持 socks5） |

**修改代理地址和端口示例：**

```json
{
  "proxy": {
    "host": "192.168.1.100",
    "port": 1080,
    "type": "socks5"
  }
}
```

### fake_ip（FakeIP 设置）

| 参数      | 类型    | 默认值            | 说明                       |
| --------- | ------- | ----------------- | -------------------------- |
| `enabled` | boolean | `true`            | 是否启用 FakeIP            |
| `cidr`    | string  | `"198.18.0.0/15"` | FakeIP 地址段（CIDR 格式） |

### timeout（超时设置）

| 参数      | 类型   | 默认值 | 说明                 |
| --------- | ------ | ------ | -------------------- |
| `connect` | number | `5000` | 连接超时时间（毫秒） |
| `send`    | number | `5000` | 发送超时时间（毫秒） |
| `recv`    | number | `5000` | 接收超时时间（毫秒） |

### proxy_rules（代理规则）

| 参数            | 类型   | 默认值      | 说明                                         |
| --------------- | ------ | ----------- | -------------------------------------------- |
| `allowed_ports` | array  | `[80, 443]` | 允许代理的端口列表（空数组表示允许所有端口） |
| `dns_mode`      | string | `"direct"`  | DNS 处理模式                                 |
| `ipv6_mode`     | string | `"proxy"`   | IPv6 处理模式                                |
| `udp_mode`      | string | `"block"`   | UDP 处理模式                                 |

### 其他设置

| 参数               | 类型    | 默认值   | 说明                               |
| ------------------ | ------- | -------- | ---------------------------------- |
| `log_level`        | string  | `"info"` | 日志级别（debug/info/warn/error）  |
| `traffic_logging`  | boolean | `false`  | 是否记录流量日志                   |
| `child_injection`  | boolean | `true`   | 是否注入子进程                     |
| `target_processes` | array   | `[]`     | 目标进程列表（空数组表示所有进程） |

**只对特定进程生效示例：**

```json
{
  "target_processes": ["curl", "wget", "chrome"]
}
```

# 8. 故障排查 (Troubleshooting)

## 8.1 常见问题

### 1. 动态库未加载

**问题**：程序运行但没有通过代理

**解决方案**：
- 检查 `DYLD_INSERT_LIBRARIES` 环境变量是否正确设置
- 确认动态库文件路径正确
- 查看日志文件确认是否有加载信息

### 2. 无法连接到代理

**问题**：日志显示 "Failed to connect to proxy"

**解决方案**：
- 确认 SOCKS5 代理服务器正在运行
- 检查配置文件中的 `host` 和 `port` 是否正确
- 测试代理连接：`nc -zv 127.0.0.1 7890`

### 3. 配置文件未生效

**问题**：修改配置后没有变化

**解决方案**：
- 确认配置文件路径正确
- 检查 JSON 格式是否正确（使用 `jsonlint` 验证）
- 查看日志确认配置是否被加载


# 9. 贡献
欢迎提交 Issue 和 Pull Request！

**免责声明 (Disclaimer)**

**本项目仅供技术研究和教育目的使用。**

1.  本工具主要用于解决特定环境下的网络连接问题，开发者不提供任何形式的保证。
2.  使用者在使用本工具时，必须遵守当地法律法规以及相关网络安全规定。
3.  严禁将本工具用于非法用途（如网络攻击、绕过安全监管等）。
4.  **免责条款**：使用此工具产生的任何直接或间接后果（包括但不限于数据丢失、法律纠纷、系统故障等）均由使用者自行承担，开发者不承担任何法律及连带责任。
5.  如果您下载、复制、编译或运行了本项目代码，即视为您已阅读并同意本声明。
