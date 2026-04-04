#include <arpa/inet.h>
#include <poll.h>
#include <algorithm>
#include <cerrno>
#include <cctype>
#include <cstring>
#include <dlfcn.h>
#include <iostream>
#include <map>
#include <mutex>
#include <netinet/in.h>
#include <string>
#include <sys/socket.h>

#include "Config.hpp"
#include "FakeIP.hpp"
#include "Logger.hpp"
#include "Socks5.hpp"
#include "interpose.h"

// 阶段5: 连接生命周期追踪（仅追踪被我们代理的 fd）
namespace {
struct TrackedConn {
  std::string domain;
  uint16_t port;
  bool proxied; // 是否成功建立 SOCKS 隧道
};
std::map<int, TrackedConn> g_trackedFds;
std::mutex g_trackMutex;

// 添加追踪
void TrackFd(int fd, const std::string &domain, uint16_t port) {
  std::lock_guard<std::mutex> lock(g_trackMutex);
  g_trackedFds[fd] = {domain, port, true};
}

// 移除追踪
void UntrackFd(int fd) {
  std::lock_guard<std::mutex> lock(g_trackMutex);
  g_trackedFds.erase(fd);
}

// 检查是否被追踪
bool IsTracked(int fd, TrackedConn *out = nullptr) {
  std::lock_guard<std::mutex> lock(g_trackMutex);
  auto it = g_trackedFds.find(fd);
  if (it != g_trackedFds.end()) {
    if (out) *out = it->second;
    return true;
  }
  return false;
}
} // namespace

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

  // 目前只处理 IPv4 目标地址，因为 FakeIP 是 IPv4
  if (addr->sa_family == AF_INET) {
    const struct sockaddr_in *sin = (const struct sockaddr_in *)addr;
    uint32_t ip = sin->sin_addr.s_addr;
    uint16_t port = ntohs(sin->sin_port);

    // 检查是否为 FakeIP
    if (Network::FakeIP::Instance().IsFakeIP(ip)) {
      std::string domain = Network::FakeIP::Instance().GetDomain(ip);
      if (!domain.empty()) {
        Core::Logger::Info("Hook: connect to FakeIP " + domain +
                           " (Orig: " + domain + ")");

        auto &config = Core::Config::Instance();

        // 优化：用 getsockopt 判断 socket 类型，避免试错 connect
        // 尝试获取 IPV6_V6ONLY 选项，如果成功说明是 IPv6 socket
        int v6only = 0;
        socklen_t optlen = sizeof(v6only);
        bool isIpv6Socket = (getsockopt(sockfd, IPPROTO_IPV6, IPV6_V6ONLY, &v6only, &optlen) == 0);
        
        int res = -1;
        int saved_errno = 0;
        
        if (isIpv6Socket) {
          // IPv6 socket：解析配置的 proxy.host
          struct sockaddr_in6 proxyAddr6;
          memset(&proxyAddr6, 0, sizeof(proxyAddr6));
          proxyAddr6.sin6_family = AF_INET6;
          proxyAddr6.sin6_port = htons(config.proxy.port);
          
          // 首先尝试解析为真正的 IPv6 地址
          if (inet_pton(AF_INET6, config.proxy.host.c_str(), &proxyAddr6.sin6_addr) != 1) {
            // 如果解析失败，尝试解析为 IPv4 地址，并转化为 IPv4-Mapped IPv6 (::ffff:x.x.x.x)
            struct in_addr ipv4;
            if (inet_pton(AF_INET, config.proxy.host.c_str(), &ipv4) == 1) {
              proxyAddr6.sin6_addr.s6_addr[10] = 0xff;
              proxyAddr6.sin6_addr.s6_addr[11] = 0xff;
              memcpy(&proxyAddr6.sin6_addr.s6_addr[12], &ipv4.s_addr, 4);
            } else {
              Core::Logger::Error("Invalid Proxy IP for IPv6 Socket: " + config.proxy.host);
              errno = EINVAL;
              return -1;
            }
          }
          
          Core::Logger::Debug("Connecting to Proxy (IPv6/Mapped): " + config.proxy.host + ":" + std::to_string(config.proxy.port));
          res = connect(sockfd, (struct sockaddr *)&proxyAddr6, sizeof(proxyAddr6));
          saved_errno = errno;
        } else {
          // IPv4 socket：使用 127.0.0.1:port
          struct sockaddr_in proxyAddr;
          memset(&proxyAddr, 0, sizeof(proxyAddr));
          proxyAddr.sin_family = AF_INET;
          proxyAddr.sin_port = htons(config.proxy.port);
          if (inet_pton(AF_INET, config.proxy.host.c_str(), &proxyAddr.sin_addr) != 1) {
            Core::Logger::Error("Invalid Proxy IP: " + config.proxy.host);
            errno = EINVAL;
            return -1;
          }
          Core::Logger::Debug("Connecting to " + config.proxy.host + ":" + 
                             std::to_string(config.proxy.port));
          res = connect(sockfd, (struct sockaddr *)&proxyAddr, sizeof(proxyAddr));
          saved_errno = errno;
        }
        
        if (res != 0 && saved_errno != EINPROGRESS) {
          Core::Logger::Error("Connect failed, errno=" + std::to_string(saved_errno));
        }
        if (res != 0) {
          if (errno == EINPROGRESS) {
             // 对于非阻塞 socket，我们需要等待连接完成
             // 使用 poll 替代 select，避免 FD_SETSIZE 限制
             struct pollfd pfd;
             pfd.fd = sockfd;
             pfd.events = POLLOUT;
             pfd.revents = 0;
             
             int timeoutMs = config.timeout.connect_ms;
             int pollRes = -1;
             
             // 带 EINTR 重试的 poll
             do {
               pollRes = poll(&pfd, 1, timeoutMs);
             } while (pollRes == -1 && errno == EINTR);
             
             if (pollRes > 0) {
                // 检查是否有错误
                int so_error;
                socklen_t len = sizeof(so_error);
                if (getsockopt(sockfd, SOL_SOCKET, SO_ERROR, &so_error, &len) < 0) {
                    Core::Logger::Error("getsockopt failed, fd=" + std::to_string(sockfd));
                    return -1;
                }
                if (so_error != 0) {
                    Core::Logger::Error("Async connect failed, fd=" + std::to_string(sockfd) + 
                                        ", so_error=" + std::to_string(so_error));
                    errno = so_error;
                    return -1;
                }
                Core::Logger::Debug("Async connect succeeded via poll, fd=" + std::to_string(sockfd));
                // 连接成功
             } else if (pollRes == 0) {
                 Core::Logger::Error("Async connect timeout, fd=" + std::to_string(sockfd));
                 errno = ETIMEDOUT;
                 return -1;
             } else {
                 Core::Logger::Error("poll failed, fd=" + std::to_string(sockfd) + 
                                     ", errno=" + std::to_string(errno));
                 return -1;
             }
          } else {
              Core::Logger::Error("Failed to connect to proxy, fd=" + std::to_string(sockfd) + 
                                  ", errno=" + std::to_string(errno));
              return -1;
          }
        }

        // SOCKS5 握手
        // 注意：Socks5Client 此时是同步阻塞实现的。
        // 如果原始 socket 是非阻塞的，我们需要临时切换为阻塞模式。
        Core::Logger::Debug("Preparing for SOCKS5 handshake, fd=" + std::to_string(sockfd));
        int flags = fcntl(sockfd, F_GETFL, 0);
        if (flags < 0) {
            Core::Logger::Error("Failed to get socket flags, fd=" + std::to_string(sockfd));
            return -1;
        }
        bool isNonBlock = (flags & O_NONBLOCK);
        Core::Logger::Debug("Socket flags=" + std::to_string(flags) + ", isNonBlock=" + std::to_string(isNonBlock));
        
        if (isNonBlock) {
            Core::Logger::Debug("Temporarily setting socket to blocking mode");
            if (fcntl(sockfd, F_SETFL, flags & ~O_NONBLOCK) < 0) {
                Core::Logger::Error("Failed to set blocking mode, fd=" + std::to_string(sockfd));
                return -1;
            }
        }

        Core::Logger::Debug("Starting SOCKS5 handshake...");
        bool handshakeSuccess = Network::Socks5Client::Handshake(sockfd, domain, port);
        Core::Logger::Debug("SOCKS5 handshake result: " + std::string(handshakeSuccess ? "success" : "failed"));

        // 恢复原始 flags
        if (isNonBlock) {
            Core::Logger::Debug("Restoring socket to non-blocking mode");
            if (fcntl(sockfd, F_SETFL, flags) < 0) {
                Core::Logger::Error("Failed to restore non-blocking mode, fd=" + std::to_string(sockfd));
            }
        }

        if (handshakeSuccess) {
          // 阶段5: 追踪成功建立隧道的连接
          TrackFd(sockfd, domain, port);
          Core::Logger::Info("Hook: SOCKS5 tunnel established to " + domain + ":" + std::to_string(port) + ", fd=" + std::to_string(sockfd));
          return 0; // 成功建立隧道
        } else {
           Core::Logger::Error("SOCKS5 Handshake failed, fd=" + std::to_string(sockfd) + ", domain=" + domain);
           errno = ECONNREFUSED;
           return -1;
        }

      }
    }
  }

  return connect(sockfd, addr, addrlen);
}

// 阶段5: Hook recv - 追踪连接关闭事件
ssize_t my_recv(int sockfd, void *buf, size_t len, int flags) {
  TrackedConn conn;
  bool tracked = IsTracked(sockfd, &conn);
  
  ssize_t res = recv(sockfd, buf, len, flags);
  
  if (tracked) {
    if (res == 0) {
      // 对端正常关闭 (FIN)
      Core::Logger::Debug("Tracked fd=" + std::to_string(sockfd) + 
                         " recv=0 (peer FIN) for " + conn.domain);
      // 可选：取消追踪，因为连接已关闭
      UntrackFd(sockfd);
    } else if (res < 0) {
      int saved_errno = errno;
      // 记录错误类型
      if (saved_errno == ECONNRESET) {
        Core::Logger::Warn("Tracked fd=" + std::to_string(sockfd) + 
                          " recv error: ECONNRESET for " + conn.domain);
      } else if (saved_errno == ETIMEDOUT) {
        Core::Logger::Warn("Tracked fd=" + std::to_string(sockfd) + 
                          " recv error: ETIMEDOUT for " + conn.domain);
      } else if (saved_errno == EPIPE) {
        Core::Logger::Warn("Tracked fd=" + std::to_string(sockfd) + 
                          " recv error: EPIPE for " + conn.domain);
      }
      // 其他错误不记录，避免日志过多
    }
  }
  
  return res;
}

// 阶段5: Hook close - 追踪本进程主动关闭
int my_close(int fd) {
  TrackedConn conn;
  bool tracked = IsTracked(fd, &conn);
  
  if (tracked) {
    Core::Logger::Debug("Tracked fd=" + std::to_string(fd) + 
                       " close() by local for " + conn.domain);
    UntrackFd(fd);
  }
  
  return close(fd);
}

DYLD_INTERPOSE(my_recv, recv)
DYLD_INTERPOSE(my_close, close)

// Hook getaddrinfo 返回 FakeIP
int my_getaddrinfo(const char *node, const char *service,
                   const struct addrinfo *hints, struct addrinfo **res) {
  auto ShouldMapAsDomain = [](const char *name) -> bool {
    if (!name || name[0] == '\0')
      return false;

    std::string host(name);
    if (host.size() > 253)
      return false;

    // 跳过明显不是域名的模式字符串或规则字符串
    static const char *kBadChars = "/*\\ <>%";
    if (host.find("://") != std::string::npos ||
        host.find_first_of(kBadChars) != std::string::npos) {
      return false;
    }

    std::string lower = host;
    std::transform(lower.begin(), lower.end(), lower.begin(),
                   [](unsigned char c) { return std::tolower(c); });
    if (lower == "localhost" || lower.rfind("localhost.", 0) == 0 ||
        lower.find(".local") != std::string::npos) {
      return false;
    }

    if (host.front() == '.' || host.back() == '.')
      return false;

    bool hasDot = false;
    bool hasAlpha = false;
    size_t labelLen = 0;
    for (char c : host) {
      if (c == '.') {
        if (labelLen == 0)
          return false;
        hasDot = true;
        labelLen = 0;
        continue;
      }
      unsigned char uc = static_cast<unsigned char>(c);
      if (!(std::isalnum(uc) || c == '-'))
        return false;
      if (std::isalpha(uc))
        hasAlpha = true;
      labelLen++;
      if (labelLen > 63)
        return false;
    }
    if (labelLen == 0)
      return false;
    if (!hasDot || !hasAlpha)
      return false;

    return true;
  };

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

  if (hints && (hints->ai_flags & AI_NUMERICHOST)) {
    return getaddrinfo(node, service, hints, res);
  }

  if (node && Core::Config::Instance().fakeIp.enabled) {
    // 只映射合法域名，避免把 bypass 规则字符串映射成 FakeIP
    if (!IsIpLiteral(node) && ShouldMapAsDomain(node)) {
      // 分配 FakeIP
      uint32_t fakeIpNet = Network::FakeIP::Instance().Alloc(node);
      if (fakeIpNet != 0) {
        // 转换为字符串 "198.18.x.x"
        char fakeIpStr[64];
        struct in_addr in;
        in.s_addr = fakeIpNet;
        if (inet_ntop(AF_INET, &in, fakeIpStr, sizeof(fakeIpStr))) {
        Core::Logger::Info("Hook: getaddrinfo mapped " + (node ? std::string(node) : "<null>") +
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
