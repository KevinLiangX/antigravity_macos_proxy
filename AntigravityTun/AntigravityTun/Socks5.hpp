#pragma once

#include "Config.hpp"
#include "Logger.hpp"
#include <arpa/inet.h>
#include <iomanip>
#include <netdb.h>
#include <netinet/in.h>
#include <sstream>
#include <string>
#include <sys/socket.h>
#include <unistd.h>
#include <vector>

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

  static bool ReadExact(int fd, uint8_t *buf, int len, int timeoutMs) {
    int total = 0;
    while (total < len) {
      ssize_t n = recv(fd, buf + total, len - total, 0);
      if (n <= 0)
        return false;
      total += n;
    }
    return true;
  }

  static bool SendAll(int fd, const void *buf, int len, int timeoutMs) {
    int total = 0;
    const uint8_t *p = static_cast<const uint8_t *>(buf);
    while (total < len) {
      ssize_t n = send(fd, p + total, len - total, 0);
      if (n <= 0)
        return false;
      total += n;
    }
    return true;
  }

public:
  static bool Handshake(int sock, const std::string &targetHost,
                        uint16_t targetPort) {
    Core::Logger::Debug("SOCKS5: Handshake start to " + targetHost);

    // 1. 认证请求（无认证）
    uint8_t authReq[] = {0x05, 0x01, 0x00};
    if (!SendAll(sock, authReq, 3, 5000))
      return false;

    uint8_t authResp[2];
    if (!ReadExact(sock, authResp, 2, 5000))
      return false;

    if (authResp[0] != 0x05 || authResp[1] != 0x00) {
      Core::Logger::Error("SOCKS5: Auth failed");
      return false;
    }

    // 2. 连接请求
    std::vector<uint8_t> req;
    req.push_back(0x05); // VER
    req.push_back(0x01); // CMD (CONNECT)
    req.push_back(0x00); // RSV

    struct in_addr addr;
    if (inet_pton(AF_INET, targetHost.c_str(), &addr) == 1) {
      // IPv4 地址
      req.push_back(0x01);
      uint32_t ip = addr.s_addr;
      req.insert(req.end(), (uint8_t *)&ip, (uint8_t *)&ip + 4);
    } else {
      // 域名
      req.push_back(0x03);
      req.push_back((uint8_t)targetHost.length());
      for (char c : targetHost)
        req.push_back(c);
    }

    // 端口（网络字节序）
    req.push_back((targetPort >> 8) & 0xFF);
    req.push_back(targetPort & 0xFF);

    if (!SendAll(sock, req.data(), (int)req.size(), 5000))
      return false;

    // 3. 响应
    uint8_t header[4];
    if (!ReadExact(sock, header, 4, 5000))
      return false;

    if (header[1] != 0x00) {
      Core::Logger::Error("SOCKS5: Connect failed with code " +
                          std::to_string(header[1]));
      return false;
    }

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

    Core::Logger::Info("SOCKS5: Tunnel established to " + targetHost);
    return true;
  }
};
} // namespace Network
