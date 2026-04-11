# Release Note - Antigravity macOS Proxy

## 版本更新

### 修复内容

#### 1. 修复 SOCKS5 握手超时问题
**问题描述**: 当连接到 FakeIP 时，SOCKS5 握手阶段会出现超时，导致连接卡住约 50 秒后失败。

**修复详情**:
- **文件**: `AntigravityTun/AntigravityTun/Socks5.hpp`
- 修复了 `WaitForFd` 函数的超时计算逻辑
  - 原逻辑使用循环递减方式计算剩余时间，存在精度问题
  - 新逻辑直接使用 `poll` 的超时参数，更加简洁可靠
  - 添加了详细的调试日志，便于诊断超时原因

- 修复了 `ReadExact` 和 `SendAll` 函数的超时计算
  - 使用 `std::chrono::steady_clock` 精确计算已用时间
  - 每次循环动态计算剩余超时时间
  - 添加了超时和错误的调试日志

#### 2. 增强调试日志功能
**文件**: `AntigravityTun/AntigravityTun/Socks5.hpp` 和 `AntigravityTun/AntigravityTun/AntigravityTun.cpp`

**改进内容**:
- SOCKS5 握手每个阶段都添加了详细的日志输出
  - `SOCKS5: Handshake start to {host}:{port}`
  - `SOCKS5: Sending auth request`
  - `SOCKS5: Auth succeeded`
  - `SOCKS5: Building connect request`
  - `SOCKS5: Tunnel established to {host}`
  
- 增强了 `my_connect` 函数的错误处理
  - 添加了对 `fcntl` 返回值的检查
  - 添加了 socket 模式切换的调试日志
  - 改进了错误信息，包含域名和文件描述符

#### 3. 配置更新
**文件**: `config.json`
- 更新了代理配置，确保与本地 SOCKS5 代理服务器兼容

#### 4. 应用包配置
**文件**: `Antigravity_Unlocked.app/Contents/Info.plist`
- 添加了 `ANTIGRAVITY_LOG_FILE` 环境变量到 `LSEnvironment`
- 允许从 Finder 启动应用时也能记录日志（需设置环境变量）

### 技术细节

#### 超时处理改进
```cpp
// 修复前: 使用循环递减，精度差
int remaining = timeoutMs;
while (remaining > 0) {
    int pollRes = poll(&pfd, 1, remaining);
    // ...
    remaining -= 10; // 每次重试扣 10ms
}

// 修复后: 使用 chrono 精确计时
auto startTime = std::chrono::steady_clock::now();
while (total < len) {
    auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - startTime).count();
    int remaining = timeoutMs - elapsed;
    // ...
}
```

### 使用说明

#### 启用文件日志
默认情况下，日志只输出到终端（stderr）。如需启用文件日志，可在运行前设置环境变量：

```bash
export ANTIGRAVITY_LOG_FILE=1
./run_unlocked.sh
```

日志文件将保存在 `/tmp/antigravity_proxy.log`

#### 查看日志
```bash
# 实时查看日志
tail -f /tmp/antigravity_proxy.log

# 查看带 PID 的日志文件
ls -la /tmp/antigravity_proxy.*.log
```

### 修改文件列表
- `AntigravityTun/AntigravityTun/Socks5.hpp` - 修复 SOCKS5 握手超时和日志
- `AntigravityTun/AntigravityTun/AntigravityTun.cpp` - 增强调试日志和错误处理
- `config.json` - 更新代理配置
- `Antigravity_Unlocked.app/Contents/Info.plist` - 添加日志环境变量
- `libAntigravityTun.dylib` - 重新编译的动态库

### 测试验证
- [x] SOCKS5 握手超时问题已修复
- [x] 连接稳定性提升
- [x] 调试日志功能正常
- [x] 与本地代理服务器（verge-mih）兼容

---

**提交日期**: 2026-03-25  
**提交者**: kevinliangx
