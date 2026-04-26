# Antigravity Proxy Launcher 代码分析报告

## 1. 项目概述

**项目名称**: Antigravity Proxy Launcher  
**版本**: v2.0  
**用途**: 通过动态库（dylib）注入与 macOS 环境重配机制，对目标应用进行代理增强与规则修补。

### 1.1 项目结构

```
AntigravityProxyLauncher/
├── AntigravityTun/           # 核心注入层 (C++/Objective-C)
│   └── AntigravityTun/       # 动态库源码
│       ├── AntigravityTun.cpp    # 主实现文件
│       ├── AntigravityTun.h      # 头文件
│       ├── Config.hpp            # 配置管理
│       ├── FakeIP.hpp            # FakeIP 映射
│       ├── Socks5.hpp            # SOCKS5 客户端
│       ├── Logger.hpp            # 日志系统
│       └── interpose.h           # DYLD 注入宏
│   └── build/                # 编译产物
├── launcher/                   # 原生交互层 (Swift/SwiftUI)
│   ├── Sources/
│   │   ├── App/                # 应用入口
│   │   ├── CLI/                # 命令行接口
│   │   ├── Models/             # 数据模型
│   │   ├── Services/           # 业务服务
│   │   ├── State/              # 状态管理
│   │   ├── Utilities/          # 工具类
│   │   └── Views/              # SwiftUI 视图
│   ├── Resources/              # 资源文件
│   ├── scripts/                # 构建脚本
│   └── Package.swift           # Swift Package 配置
├── docs/                       # 文档
├── tools/                      # 辅助工具
└── README.md                   # 主文档
```

---

## 2. 核心注入层 (AntigravityTun) 分析

### 2.1 技术原理

采用 **DYLD_INSERT_LIBRARIES** 注入机制，通过函数拦截（Hook）实现透明代理。

#### Hook 的函数列表

| 函数名 | 用途 |
|--------|------|
| `connect` | 拦截 socket 连接请求，重定向到 SOCKS5 代理 |
| `getaddrinfo` | 返回 FakeIP 替代真实域名解析 |
| `getpeername` | 返回原始目标地址（FakeIP）而非代理地址 |
| `close` | 清理 socket 映射表 |

### 2.2 核心文件分析

#### 2.2.1 `AntigravityTun.cpp` - 主实现

**关键流程**:
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

**代码结构**:
- **初始化**: 静态初始化块，配置加载，日志初始化
- **connect Hook** (`my_connect`): 
  - 检查是否为 IPv4 或 IPv4-Mapped IPv6
  - 判断是否为 FakeIP
  - 支持 IPv6 socket 和 IPv4 socket
  - 非阻塞 socket 的 poll 处理
  - SOCKS5 握手
- **getaddrinfo Hook** (`my_getaddrinfo`):
  - 域名合法性验证
  - FakeIP 分配
- **getpeername Hook** (`my_getpeername`):
  - 返回原始目标地址
- **close Hook** (`my_close`):
  - 清理映射表

#### 2.2.2 `FakeIP.hpp` - FakeIP 管理

**核心功能**:
- **CIDR 解析**: 支持 `198.18.0.0/15` 格式
- **IP 分配**: 循环使用 FakeIP 地址池
- **共享内存**: 多进程间同步 FakeIP 映射

**共享内存实现**:
```cpp
// 使用 shm_open + mmap 实现跨进程共享
// 回退机制: 如果 shm 失败，使用文件 /tmp/antigravity_fakeip_map_<uid>.bin
// 文件锁: /tmp/antigravity_fakeip.lock
```

**数据结构**:
```cpp
struct SharedEntry {
    uint32_t ip;           // 主机字节序
    uint64_t tick;         // 时间戳
    char domain[256];      // 域名
};
```

#### 2.2.3 `Socks5.hpp` - SOCKS5 客户端

**握手流程**:
1. 认证请求 (无认证: 0x05 0x01 0x00)
2. 认证响应
3. 连接请求 (CONNECT 命令)
4. 连接响应
5. TCP 参数优化 (TCP_NODELAY, SO_KEEPALIVE, SO_NOSIGPIPE)

**关键优化**:
- 使用 poll 替代 select，避免 FD_SETSIZE 限制
- 超时控制: connect 5s, send/recv 5s
- 非阻塞 socket 临时切换为阻塞模式进行握手

#### 2.2.4 `Config.hpp` - 配置管理

**配置结构**:
```cpp
struct ProxyConfig {
    std::string host = "127.0.0.1";
    int port = 7897;
    std::string type = "socks5";
};

struct FakeIPConfig {
    bool enabled = true;
    std::string cidr = "198.18.0.0/15";
};

struct TimeoutConfig {
    int connect_ms = 5000;
    int send_ms = 5000;
    int recv_ms = 5000;
};
```

**配置加载优先级**:
1. 环境变量 `ANTIGRAVITY_CONFIG`
2. `@executable_path/../Resources/proxy_config.json`
3. `~/.config/antigravity/config.json`
4. `./config.json`
5. `/tmp/config.json`

---

## 3. 原生交互层 (Launcher) 分析

### 3.1 架构模式

采用 **MVVM** 架构:
- **Model**: 数据模型定义
- **View**: SwiftUI 视图
- **ViewModel**: 状态管理 (`LauncherAppState`, `AuthViewModel`, `QuotaViewModel`)
- **Service**: 业务逻辑封装

### 3.2 核心模块分析

#### 3.2.1 应用入口 (`AntigravityProxyLauncherApp.swift`)

**启动流程**:
1. 确保运行时目录存在
2. 解析命令行参数 (CLI 模式)
3. 检查 Bundle Identifier (防止非 .app 方式启动 GUI)
4. 激活应用窗口

**CLI 支持**:
- `--doctor`: 诊断检查
- `--export-diagnostics`: 导出诊断包
- `--verify-patched`: 验证 patched app
- `--patch-and-launch`: 修复并启动

#### 3.2.2 状态管理 (`LauncherAppState.swift`)

**核心职责**:
- 管理应用状态 (`status`)
- 执行修复工作流 (`runWorkflow`)
- 代理配置管理
- 设置管理
- 更新检查

**修复工作流步骤**:
1. **detect**: 检测目标应用
2. **compatibility**: 兼容性检查
3. **migration**: 沙盒数据迁移
4. **patch**: 修复包处理
5. **verify**: 验证修复结果
6. **launch**: 启动应用

#### 3.2.3 修复服务 (`PatchService.swift`)

**核心功能**:
- 复制原版应用到沙盒目录
- 清理扩展属性 (`xattr -cr`)
- 嵌入运行时资源 (dylib, config)
- 重写 Info.plist (注入 LSEnvironment)
- Inside-out 重签名

**重签名原理**:
```
1. 先签名最深层的 Frameworks
2. 再签名外层
3. 最后签名主可执行文件
4. 使用 ad-hoc 签名 (`--sign -`)
```

**注入的环境变量**:
```xml
<key>LSEnvironment</key>
<dict>
    <key>DYLD_INSERT_LIBRARIES</key>
    <string>@executable_path/../Resources/libAntigravityTun.dylib</string>
    <key>ANTIGRAVITY_CONFIG</key>
    <string>@executable_path/../Resources/proxy_config.json</string>
</dict>
```

#### 3.2.4 启动服务 (`LaunchService.swift`)

**启动流程**:
1. 停止已运行的修复版应用
2. 配置环境变量
3. 使用 `NSWorkspace.shared.openApplication` 启动

**环境变量**:
- `DYLD_INSERT_LIBRARIES`: dylib 路径
- `ANTIGRAVITY_CONFIG`: 配置文件路径
- `ANTIGRAVITY_LOG_FILE`: 启用日志
- `ANTIGRAVITY_LOG_LEVEL`: 日志级别
- `ANTIGRAVITY_LOG_PATH`: 日志路径

#### 3.2.5 兼容性服务 (`CompatibilityService.swift`)

**功能**:
- 加载兼容性规则 (本地 + 远程)
- 验证目标应用版本是否在支持范围内
- 支持远程规则更新

**规则格式** (`compatibility.json`):
```json
{
  "schemaVersion": 1,
  "rules": [
    {
      "minVersion": "0.1.0",
      "maxVersion": "99.99.99",
      "bundleIdentifier": "com.google.antigravity",
      "executableRelativePath": "Contents/MacOS/Electron"
    }
  ]
}
```

### 3.3 数据模型

#### 3.3.1 核心模型列表

| 模型 | 用途 |
|------|------|
| `AppInfo` | 目标应用信息 (版本、路径、Bundle ID) |
| `AppStatus` | 应用状态枚举 |
| `ProxyConfig` | 代理配置 |
| `AppSettings` | 应用设置 |
| `PatchMetadata` | 修复元数据 |
| `CompatibilityRule` | 兼容性规则 |
| `ReleaseUpdateInfo` | 更新信息 |
| `DiagnosticSnapshot` | 诊断快照 |

#### 3.3.2 状态枚举

```swift
enum AppStatus {
    case targetAppMissing          // 未找到目标应用
    case targetAppUnsupportedVersion(String)  // 版本不支持
    case patching                  // 修复中
    case patchedAppMissing         // 修复包缺失
    case patchedAppOutdated        // 修复包过期
    case repairRequired(String)    // 需要修复
    case patchedReady              // 修复完成，可启动
    case launching                 // 启动中
    case running                   // 运行中
    case cleaning                  // 清理中
    case error(String)             // 错误状态
}
```

### 3.4 视图层

#### 3.4.1 主要视图

| 视图 | 功能 |
|------|------|
| `HomeView` | 总览页 (Dashboard) |
| `ConfigView` | 代理配置页 |
| `QuotaView` | 配额管理页 |
| `DiagnosticsView` | 诊断与 FAQ 页 |
| `RuntimeLogsView` | 运行时日志页 |
| `SettingsView` | 偏好设置页 |

---

## 4. 关键技术点分析

### 4.1 动态库注入机制

**DYLD_INSERT_LIBRARIES** 是 macOS 提供的动态库注入机制：

```c
// 通过环境变量指定要注入的动态库
setenv("DYLD_INSERT_LIBRARIES", "/path/to/lib.dylib", 1);
```

**interpose.h 宏定义**:
```c
#define DYLD_INTERPOSE(_replacment,_replacee) \
    __attribute__((used)) static struct{ \
        const void* replacement; \
        const void* replacee; \
    } _interpose_##_replacee \
    __attribute__ ((section ("__DATA,__interpose"))) = { \
        (const void*)(unsigned long)&_replacment, \
        (const void*)(unsigned long)&_replacee \
    };
```

### 4.2 FakeIP 技术

**原理**: 将域名映射到虚拟 IP 地址段 (198.18.0.0/15)，在 connect 时再解析回域名。

**优势**:
- 无需修改应用的 DNS 解析逻辑
- 支持域名级别的流量控制
- 兼容现有的 socket API

**IP 段选择**: 198.18.0.0/15 是 RFC 规定用于基准测试的地址段，不会与真实网络冲突。

### 4.3 重签名机制

**为什么需要重签名**:
- 目标应用开启 Hardened Runtime
- 缺少 `com.apple.security.cs.disable-library-validation`
- 缺少 `com.apple.security.cs.allow-dyld-environment-variables`

**entitlements.plist**:
```xml
<key>com.apple.security.cs.disable-library-validation</key>
<true/>
<key>com.apple.security.cs.allow-dyld-environment-variables</key>
<true/>
<key>com.apple.security.cs.allow-jit</key>
<true/>
```

### 4.4 多进程支持

**挑战**: Electron 应用包含主进程 + 多个 Renderer 进程 + Helper 进程

**解决方案**:
1. 共享内存同步 FakeIP 映射
2. 每个 Helper 的 Resources 目录也嵌入 dylib 和 config
3. 通过 LSEnvironment 自动传递环境变量给子进程

---

## 5. 配置文件详解

### 5.1 `proxy_config.json`

```json
{
  "log_level": "warn",
  "proxy": {
    "host": "127.0.0.1",
    "port": 7897,
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
    "allowed_ports": [80, 443],
    "dns_mode": "direct",
    "ipv6_mode": "proxy",
    "udp_mode": "block"
  },
  "traffic_logging": false,
  "child_injection": true,
  "target_processes": []
}
```

### 5.2 配置项说明

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `log_level` | string | "warn" | debug/info/warn/error |
| `proxy.host` | string | "127.0.0.1" | SOCKS5 代理地址 |
| `proxy.port` | int | 7897 | SOCKS5 代理端口 |
| `fake_ip.enabled` | bool | true | 启用 FakeIP |
| `fake_ip.cidr` | string | "198.18.0.0/15" | FakeIP 地址段 |
| `timeout.connect` | int | 5000 | 连接超时 (ms) |
| `target_processes` | array | [] | 目标进程列表 |

---

## 6. 安全与风险分析

### 6.1 安全风险

| 风险点 | 说明 | 缓解措施 |
|--------|------|----------|
| 重签名破坏 | 移除了原厂签名 | 隔离到单独目录 `~/Applications/` |
| 钥匙串访问 | 签名改变导致钥匙串提示 | 用户授权 |
| iCloud/推送 | 依赖 Team ID 的服务失效 | 仅影响特定功能 |
| 自动更新 | 更新可能破坏解锁状态 | 提供更新检测，手动修复 |

### 6.2 代码安全

- **输入验证**: 域名合法性检查，防止注入攻击
- **路径处理**: 使用 `realpath` 解析绝对路径
- **错误处理**: 完善的错误码和日志记录
- **资源清理**: 自动回滚机制

---

## 7. 性能分析

### 7.1 性能优化点

1. **共享内存**: 避免重复 DNS 解析
2. **poll 替代 select**: 支持更多文件描述符
3. **TCP_NODELAY**: 减少小包延迟
4. **SO_KEEPALIVE**: 保持长连接
5. **日志级别控制**: 生产环境使用 warn 级别

### 7.2 潜在性能瓶颈

- 每个连接需要 SOCKS5 握手 (RTT)
- 非阻塞 socket 的临时切换
- 共享内存的文件锁竞争

---

## 8. 调试与故障排查

### 8.1 日志文件位置

| 日志 | 路径 | 说明 |
|------|------|------|
| dylib 日志 | `/tmp/antigravity_proxy.<PID>.log` | 需要设置 `ANTIGRAVITY_LOG_FILE=1` |
| FakeIP 映射 | `/tmp/antigravity_fakeip_map_<uid>.bin` | 共享内存回退文件 |
| 修复日志 | `~/Library/Application Support/AntigravityProxyLauncher/patch.log` | 修复过程日志 |

### 8.2 常用调试命令

```bash
# 检查 SOCKS 端口
lsof -nP -iTCP:7897 -sTCP:LISTEN

# 检查 dylib 是否加载
vmmap <PID> | grep "libAntigravityTun.dylib"

# 检查 SOCKS 连接
lsof -nP -p <PID> -a -iTCP | grep "7897"

# 查看 Info.plist 环境变量
/usr/libexec/PlistBuddy -c "Print :LSEnvironment" "Antigravity_Unlocked.app/Contents/Info.plist"
```

---

## 9. 总结

### 9.1 架构优势

1. **分层设计**: 注入层与交互层分离，职责清晰
2. **工程化**: 使用标准构建工具 (Xcode, Swift Package Manager)
3. **用户体验**: 原生 GUI 替代命令行脚本
4. **可维护性**: 模块化设计，易于扩展

### 9.2 技术亮点

1. **DYLD 注入**: 巧妙的函数 Hook 实现透明代理
2. **FakeIP**: 优雅的域名映射方案
3. **共享内存**: 多进程支持的关键实现
4. **自动回滚**: 健壮的失败处理机制
5. **兼容性引擎**: 支持远程规则更新

### 9.3 改进建议

1. **安全性**: 考虑添加代码签名验证
2. **性能**: 支持连接池复用 SOCKS5 连接
3. **兼容性**: 支持更多代理协议 (HTTP, Shadowsocks)
4. **监控**: 添加流量统计和实时监控
5. **文档**: 完善 API 文档和开发指南

---

*报告生成时间: 2026-04-23*  
*分析范围: 完整代码库*
