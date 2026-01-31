#pragma once
#include "Logger.hpp"
#include <algorithm>
#include <cctype>
#include <fstream>
#include <pwd.h>
#include <string>
#include <unistd.h>
#include <vector>

#include "AntigravityTun/nlohmann/json.hpp"

namespace Core {
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

struct ProxyRules {
  std::vector<uint16_t> allowed_ports = {80, 443};
  std::string dns_mode = "direct";
  std::string ipv6_mode = "proxy";
  std::string udp_mode = "block";

  bool IsPortAllowed(uint16_t port) const {
    if (allowed_ports.empty())
      return true;
    return std::find(allowed_ports.begin(), allowed_ports.end(), port) !=
           allowed_ports.end();
  }
};

class Config {
private:
  static std::string GetHomeDir() {
    const char *home = getenv("HOME");
    if (home)
      return std::string(home);
    struct passwd *pw = getpwuid(getuid());
    if (pw)
      return std::string(pw->pw_dir);
    return "";
  }

public:
  ProxyConfig proxy;
  FakeIPConfig fakeIp;
  TimeoutConfig timeout;
  ProxyRules rules;
  bool trafficLogging = false;
  bool childInjection = true;
  std::vector<std::string> targetProcesses;

  bool ShouldInject(const std::string &processName) const {
    if (targetProcesses.empty())
      return true;
    std::string lowerName = processName;
    std::transform(lowerName.begin(), lowerName.end(), lowerName.begin(),
                   [](unsigned char c) { return std::tolower(c); });

    for (const auto &target : targetProcesses) {
      std::string lowerTarget = target;
      std::transform(lowerTarget.begin(), lowerTarget.end(),
                     lowerTarget.begin(),
                     [](unsigned char c) { return std::tolower(c); });
      if (lowerName.find(lowerTarget) != std::string::npos)
        return true;
    }
    return false;
  }

  static Config &Instance() {
    static Config instance;
    return instance;
  }

  bool Load(const std::string &path = "") {
    std::string configPath = path;

    // 默认配置文件路径查找
    if (configPath.empty()) {
      const char *envPath = getenv("ANTIGRAVITY_CONFIG");
      if (envPath) {
        configPath = envPath;
      } else {
        std::string home = GetHomeDir();
        if (!home.empty()) {
          configPath = home + "/.config/antigravity/proxy_config.json";
        }
      }
    }

    // 候选配置文件路径
    std::vector<std::string> candidates;
    if (!configPath.empty())
      candidates.push_back(configPath);
    candidates.push_back("proxy_config.json");
    candidates.push_back("/tmp/proxy_config.json");

    std::ifstream f;
    std::string loadedPath;
    for (const auto &p : candidates) {
      f.open(p);
      if (f.is_open()) {
        loadedPath = p;
        break;
      }
      f.clear();
    }

    if (!f.is_open()) {
      Logger::Warn("Failed to open config file. Tried paths like: " +
                   (!candidates.empty() ? candidates[0] : "none"));
      return false;
    }

    try {
      nlohmann::json j = nlohmann::json::parse(f);

      std::string logLevelStr = j.value("log_level", "info");
      Logger::SetLevelFromString(logLevelStr);
      Logger::Info("Loaded config from: " + loadedPath);

      if (j.contains("proxy")) {
        auto &p = j["proxy"];
        proxy.host = p.value("host", "127.0.0.1");
        proxy.port = p.value("port", 7890);
        proxy.type = p.value("type", "socks5");
      }

      // 标准化代理类型为小写
      std::transform(proxy.type.begin(), proxy.type.end(), proxy.type.begin(),
                     [](unsigned char c) { return std::tolower(c); });

      if (j.contains("fake_ip")) {
        auto &fip = j["fake_ip"];
        fakeIp.enabled = fip.value("enabled", true);
        fakeIp.cidr = fip.value("cidr", "198.18.0.0/15");
      }

      if (j.contains("timeout")) {
        auto &t = j["timeout"];
        timeout.connect_ms = t.value("connect", 5000);
        timeout.send_ms = t.value("send", 5000);
        timeout.recv_ms = t.value("recv", 5000);
      }

      if (j.contains("proxy_rules")) {
        auto &pr = j["proxy_rules"];
        if (pr.contains("allowed_ports") && pr["allowed_ports"].is_array()) {
          rules.allowed_ports.clear();
          for (const auto &p : pr["allowed_ports"]) {
            if (p.is_number_unsigned())
              rules.allowed_ports.push_back(p.get<uint16_t>());
          }
        }
        rules.dns_mode = pr.value("dns_mode", "direct");
        rules.ipv6_mode = pr.value("ipv6_mode", "proxy");
        rules.udp_mode = pr.value("udp_mode", "block");
      }

      trafficLogging = j.value("traffic_logging", false);
      childInjection = j.value("child_injection", true);

      if (j.contains("target_processes") && j["target_processes"].is_array()) {
        targetProcesses.clear();
        for (const auto &item : j["target_processes"]) {
          if (item.is_string())
            targetProcesses.push_back(item.get<std::string>());
        }
      }

      return true;
    } catch (const std::exception &e) {
      Logger::Error("Config parse error: " + std::string(e.what()));
      return false;
    }
  }
};
} // namespace Core
