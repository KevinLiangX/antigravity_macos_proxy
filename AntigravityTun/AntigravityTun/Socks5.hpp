#pragma once

#include "Config.hpp"
#include "Logger.hpp"
#include <arpa/inet.h>
#include <chrono>
#include <fcntl.h>
#include <poll.h>
#include <iomanip>
#include <netdb.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sstream>
#include <string>
#include <sys/socket.h>
#include <unistd.h>
#include <vector>
#include <cerrno>

namespace Network {

class Socks5Client {
private:
  static std::string HexDump(const uint8_t *data, size_t len, size_t maxBytes) {
    if (!data)
      return "";
    std::ostringstream oss;
    oss << std::hex << std::uppercase << std::setfill('0');
    for (size_t i = 0; i < std::min(len, maxBytes); ++i) {
      if (i)
        oss << " ";
      oss << std::setw(2) << (int)data[i];
    }
    return oss.str();
  }

  // 等待 fd 变为可写(写)或可读(读)，带超时
  static bool WaitForFd(int fd, bool write, int timeoutMs) {
    struct pollfd pfd;
    pfd.fd = fd;
    pfd.events = write ? POLLOUT : POLLIN;
    pfd.revents = 0;
    
    int pollRes = poll(&pfd, 1, timeoutMs);
    if (pollRes > 0) {
      if (pfd.revents & (write ? POLLOUT : POLLIN)) {
        return true; // 就绪
      }
      if (pfd.revents & (POLLERR | POLLHUP | POLLNVAL)) {
        Core::Logger::Debug("WaitForFd: socket error, revents=" + std::to_string(pfd.revents));
        return false; // 错误
      }
    } else if (pollRes == 0) {
      Core::Logger::Debug("WaitForFd: timeout after " + std::to_string(timeoutMs) + "ms");
      return false; // 超时
    } else if (pollRes < 0) {
      Core::Logger::Debug("WaitForFd: poll failed, errno=" + std::to_string(errno));
      return false; // poll 错误
    }
    return false;
  }

  static bool ReadExact(int fd, uint8_t *buf, int len, int timeoutMs) {
    int total = 0;
    auto startTime = std::chrono::steady_clock::now();
    
    while (total < len) {
      // 计算剩余超时时间
      auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
          std::chrono::steady_clock::now() - startTime).count();
      int remaining = timeoutMs - elapsed;
      if (remaining <= 0) {
        Core::Logger::Debug("ReadExact: timeout, read " + std::to_string(total) + "/" + std::to_string(len));
        return false;
      }
      
      // 等待可读
      if (!WaitForFd(fd, false, remaining))
        return false;
      
      ssize_t n = recv(fd, buf + total, len - total, 0);
      if (n > 0) {
        total += n;
      } else if (n == 0) {
        Core::Logger::Debug("ReadExact: peer closed connection");
        return false; // 对端关闭
      } else if (errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK) {
        continue; // 重试
      } else {
        Core::Logger::Debug("ReadExact: recv error, errno=" + std::to_string(errno));
        return false; // 其他错误
      }
    }
    return true;
  }

  static bool SendAll(int fd, const void *buf, int len, int timeoutMs) {
    int total = 0;
    const uint8_t *p = static_cast<const uint8_t *>(buf);
    auto startTime = std::chrono::steady_clock::now();
    
    while (total < len) {
      // 计算剩余超时时间
      auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
          std::chrono::steady_clock::now() - startTime).count();
      int remaining = timeoutMs - elapsed;
      if (remaining <= 0) {
        Core::Logger::Debug("SendAll: timeout, sent " + std::to_string(total) + "/" + std::to_string(len));
        return false;
      }
      
      // 等待可写
      if (!WaitForFd(fd, true, remaining))
        return false;
      
      ssize_t n = send(fd, p + total, len - total, MSG_NOSIGNAL);
      if (n > 0) {
        total += n;
      } else if (errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK) {
        continue; // 重试
      } else {
        Core::Logger::Debug("SendAll: send error, errno=" + std::to_string(errno));
        return false; // 其他错误
      }
    }
    return true;
  }

public:
  static bool Handshake(int sock, const std::string &targetHost,
                        uint16_t targetPort) {
    Core::Logger::Info("SOCKS5: Handshake start to " + targetHost + ":" + std::to_string(targetPort));

    // 1. 认证请求（无认证）
    Core::Logger::Debug("SOCKS5: Sending auth request");
    uint8_t authReq[] = {0x05, 0x01, 0x00};
    if (!SendAll(sock, authReq, 3, 5000)) {
      Core::Logger::Error("SOCKS5: Failed to send auth request");
      return false;
    }

    Core::Logger::Debug("SOCKS5: Waiting for auth response");
    uint8_t authResp[2];
    if (!ReadExact(sock, authResp, 2, 5000)) {
      Core::Logger::Error("SOCKS5: Failed to read auth response");
      return false;
    }

    if (authResp[0] != 0x05 || authResp[1] != 0x00) {
      Core::Logger::Error("SOCKS5: Auth failed, ver=" + std::to_string(authResp[0]) + 
                          ", method=" + std::to_string(authResp[1]));
      return false;
    }
    Core::Logger::Debug("SOCKS5: Auth succeeded");

    // 2. 连接请求
    Core::Logger::Debug("SOCKS5: Building connect request");
    std::vector<uint8_t> req;
    req.push_back(0x05); // VER
    req.push_back(0x01); // CMD (CONNECT)
    req.push_back(0x00); // RSV

    struct in_addr addr4;
    struct in6_addr addr6;
    if (inet_pton(AF_INET, targetHost.c_str(), &addr4) == 1) {
      // IPv4 地址
      req.push_back(0x01);
      uint32_t ip = addr4.s_addr;
      req.insert(req.end(), (uint8_t *)&ip, (uint8_t *)&ip + 4);
      Core::Logger::Debug("SOCKS5: Using IPv4 address");
    } else if (inet_pton(AF_INET6, targetHost.c_str(), &addr6) == 1) {
      // IPv6 地址
      req.push_back(0x04);
      req.insert(req.end(), addr6.s6_addr, addr6.s6_addr + 16);
      Core::Logger::Debug("SOCKS5: Using IPv6 address");
    } else {
      // 域名
      req.push_back(0x03);
      req.push_back((uint8_t)targetHost.length());
      for (char c : targetHost)
        req.push_back(c);
      Core::Logger::Debug("SOCKS5: Using domain name: " + targetHost);
    }

    // 端口（网络字节序）
    req.push_back((targetPort >> 8) & 0xFF);
    req.push_back(targetPort & 0xFF);

    Core::Logger::Debug("SOCKS5: Sending connect request, size=" + std::to_string(req.size()));
    if (!SendAll(sock, req.data(), (int)req.size(), 5000)) {
      Core::Logger::Error("SOCKS5: Failed to send connect request");
      return false;
    }

    // 3. 响应
    Core::Logger::Debug("SOCKS5: Waiting for connect response");
    uint8_t header[4];
    if (!ReadExact(sock, header, 4, 5000)) {
      Core::Logger::Error("SOCKS5: Failed to read connect response");
      return false;
    }

    if (header[1] != 0x00) {
      Core::Logger::Error("SOCKS5: Connect failed with code " +
                          std::to_string(header[1]));
      return false;
    }
    Core::Logger::Debug("SOCKS5: Connect response received, atyp=" + std::to_string(header[3]));

    uint8_t atyp = header[3];
    int len = 0;
    if (atyp == 0x01)
      len = 4;
    else if (atyp == 0x04)
      len = 16;
    else if (atyp == 0x03) {
      uint8_t domainLen;
      if (!ReadExact(sock, &domainLen, 1, 5000))
        return false;
      len = domainLen;
    }

    if (len > 0) {
      std::vector<uint8_t> trash(len);
      if (!ReadExact(sock, trash.data(), len, 5000))
        return false;
    }

    uint8_t portBuf[2];
    if (!ReadExact(sock, portBuf, 2, 5000))
      return false;

    // 阶段4: 优化 TCP 参数（仅对已建立的连接）
    // TCP_NODELAY: 减少小包延迟
    int nodelay = 1;
    setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));
    
    // SO_KEEPALIVE: 保持长连接，避免中间设备 idle timeout
    int keepalive = 1;
    if (setsockopt(sock, SOL_SOCKET, SO_KEEPALIVE, &keepalive, sizeof(keepalive)) == 0) {
      // macOS: TCP_KEEPALIVE 参数（空闲后开始探测的时间，秒）
      int keepidle = 30; // 30秒空闲后开始探测
      setsockopt(sock, IPPROTO_TCP, TCP_KEEPALIVE, &keepidle, sizeof(keepidle));
      
      // 探测间隔和次数（如果系统支持）
      int keepintvl = 10; // 探测间隔10秒
      int keepcnt = 3;    // 探测3次失败则断开
      setsockopt(sock, IPPROTO_TCP, TCP_KEEPINTVL, &keepintvl, sizeof(keepintvl));
      setsockopt(sock, IPPROTO_TCP, TCP_KEEPCNT, &keepcnt, sizeof(keepcnt));
    }
    
    // SO_NOSIGPIPE: 避免发送时触发 SIGPIPE 信号
    int nosigpipe = 1;
    setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &nosigpipe, sizeof(nosigpipe));

    Core::Logger::Info("SOCKS5: Tunnel established to " + targetHost);
    return true;
  }
};
} // namespace Network
