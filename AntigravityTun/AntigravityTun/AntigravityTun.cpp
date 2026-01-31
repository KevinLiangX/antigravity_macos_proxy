#include <arpa/inet.h>
#include <cerrno>
#include <cstring>
#include <dlfcn.h>
#include <iostream>
#include <netinet/in.h>
#include <sys/socket.h>

#include "Config.hpp"
#include "FakeIP.hpp"
#include "Logger.hpp"
#include "Socks5.hpp"
#include "interpose.h"

int my_connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
  if (!addr)
    return connect(sockfd, addr, addrlen);

  // 初始化配置（仅执行一次）
  static bool init = []() {
    Core::Logger::Init("/tmp/antigravity_proxy.log");
    Core::Config::Instance().Load();
    return true;
  }();
  (void)init;

  // 目前只处理 IPv4，因为 FakeIP 通常是 IPv4
  if (addr->sa_family == AF_INET) {
    const struct sockaddr_in *sin = (const struct sockaddr_in *)addr;
    uint32_t ip = sin->sin_addr.s_addr;
    uint16_t port = ntohs(sin->sin_port);

    // 检查是否为 FakeIP
    if (Network::FakeIP::Instance().IsFakeIP(ip)) {
      std::string domain = Network::FakeIP::Instance().GetDomain(ip);
      if (!domain.empty()) {
        Core::Logger::Info("Hook: connect to FakeIP " +
                           Network::FakeIP::Instance().GetDomain(ip) +
                           " (Orig: " + domain + ")");

        auto &config = Core::Config::Instance();

        // 连接到代理服务器
        struct sockaddr_in proxyAddr;
        memset(&proxyAddr, 0, sizeof(proxyAddr));
        proxyAddr.sin_family = AF_INET;
        proxyAddr.sin_port = htons(config.proxy.port);
        if (inet_pton(AF_INET, config.proxy.host.c_str(),
                      &proxyAddr.sin_addr) != 1) {
          Core::Logger::Error("Invalid Proxy IP");
          errno = EINVAL;
          return -1;
        }

        // 调用原始 connect 连接到代理
        int res =
            connect(sockfd, (struct sockaddr *)&proxyAddr, sizeof(proxyAddr));
        if (res != 0) {
          if (errno == EINPROGRESS) {
             // 对于非阻塞 socket，我们需要等待连接完成
             fd_set wset;
             FD_ZERO(&wset);
             FD_SET(sockfd, &wset);
             struct timeval tv;
             tv.tv_sec = config.timeout.connect_ms / 1000;
             tv.tv_usec = (config.timeout.connect_ms % 1000) * 1000;
             
             int sres = select(sockfd + 1, NULL, &wset, NULL, &tv);
             if (sres > 0) {
                // 连接可能有结果了，检查是否有错误
                int so_error;
                socklen_t len = sizeof(so_error);
                if (getsockopt(sockfd, SOL_SOCKET, SO_ERROR, &so_error, &len) < 0) {
                    Core::Logger::Error("getsockopt failed");
                    return -1;
                }
                if (so_error != 0) {
                    Core::Logger::Error("Async connect failed: " + std::to_string(so_error));
                    errno = so_error;
                    return -1;
                }
                // 连接成功
             } else if (sres == 0) {
                 Core::Logger::Error("Async connect timeout");
                 errno = ETIMEDOUT;
                 return -1;
             } else {
                 Core::Logger::Error("select failed");
                 return -1;
             }
          } else {
              Core::Logger::Error("Failed to connect to proxy: " +
                                  std::to_string(errno));
              return -1;
          }
        }

        // SOCKS5 握手
        // 注意：Socks5Client 此时是同步阻塞实现的。
        // 如果原始 socket 是非阻塞的，我们需要临时切换为阻塞模式。
        int flags = fcntl(sockfd, F_GETFL, 0);
        bool isNonBlock = (flags & O_NONBLOCK);
        if (isNonBlock) {
            fcntl(sockfd, F_SETFL, flags & ~O_NONBLOCK);
        }

        bool handshakeSuccess = Network::Socks5Client::Handshake(sockfd, domain, port);

        // 恢复原始 flags
        if (isNonBlock) {
            fcntl(sockfd, F_SETFL, flags);
        }

        if (handshakeSuccess) {
          Core::Logger::Info("Hook: connect to FakeIP " + domain + " (Orig: " + domain + ")");
          return 0; // 成功建立隧道
        } else {
           Core::Logger::Error("SOCKS5 Handshake failed");
           errno = ECONNREFUSED;
           return -1;
        }

        return 0;
      }
    }
  }

  return connect(sockfd, addr, addrlen);
}

// Hook getaddrinfo 返回 FakeIP
int my_getaddrinfo(const char *node, const char *service,
                   const struct addrinfo *hints, struct addrinfo **res) {
  // 检查是否为 IP 字面量，避免递归或映射 IP
  auto IsIpLiteral = [](const char *name) -> bool {
    struct in_addr a4;
    struct in6_addr a6;
    if (inet_pton(AF_INET, name, &a4) == 1)
      return true;
    if (inet_pton(AF_INET6, name, &a6) == 1)
      return true;
    return false;
  };

  // 初始化配置
  static bool init = []() {
    Core::Logger::Init("/tmp/antigravity_proxy_loader.log");
    Core::Config::Instance().Load();
    return true;
  }();
  (void)init;

  if (node && Core::Config::Instance().fakeIp.enabled) {
    // 跳过空字符串或 IP 字面量
    if (node[0] != '\0' && !IsIpLiteral(node)) {
      // 分配 FakeIP
      uint32_t fakeIpNet = Network::FakeIP::Instance().Alloc(node);
      if (fakeIpNet != 0) {
        // 转换为字符串 "198.18.x.x"
        char fakeIpStr[64];
        struct in_addr in;
        in.s_addr = fakeIpNet;
        if (inet_ntop(AF_INET, &in, fakeIpStr, sizeof(fakeIpStr))) {
          Core::Logger::Info("Hook: getaddrinfo mapped " + std::string(node) +
                             " -> " + fakeIpStr);

          // 使用 FakeIP 调用原始 getaddrinfo
          return getaddrinfo(fakeIpStr, service, hints, res);
        }
      }
    }
  }

  return getaddrinfo(node, service, hints, res);
}

DYLD_INTERPOSE(my_connect, connect)
DYLD_INTERPOSE(my_getaddrinfo, getaddrinfo)

// 构造函数
__attribute__((constructor)) void LoaderInit() {
  Core::Logger::Init("/tmp/antigravity_proxy_loader.log");
  Core::Logger::Info("AntigravityTun Loaded.");
}
