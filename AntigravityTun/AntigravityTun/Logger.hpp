#pragma once
#include <cstdio>
#include <ctime>
#include <iostream>
#include <string>
#include <unistd.h>

namespace Core {
enum class LogLevel { Debug, Info, Warn, Error };

class Logger {
public:
  static void Init(const std::string &path = "") {
    // 暂时不实现，避免静态文件问题
  }

  static void SetLevelFromString(const std::string &levelStr) {
    // 暂时忽略
  }

  static bool IsEnabled(LogLevel level) { return true; }

  static void Log(LogLevel level, const std::string &msg) {
    time_t now = time(nullptr);
    struct tm tstruct;
    char buf[80];
    localtime_r(&now, &tstruct);
    strftime(buf, sizeof(buf), "%Y-%m-%d %X", &tstruct);

    fprintf(stderr, "[%s] [%d] %s %s\n", buf, getpid(), LevelToString(level),
            msg.c_str());
  }

  static void Debug(const std::string &msg) { Log(LogLevel::Debug, msg); }
  static void Info(const std::string &msg) { Log(LogLevel::Info, msg); }
  static void Warn(const std::string &msg) { Log(LogLevel::Warn, msg); }
  static void Error(const std::string &msg) { Log(LogLevel::Error, msg); }

private:
  static const char *LevelToString(LogLevel level) {
    switch (level) {
    case LogLevel::Debug:
      return "[DEBUG]";
    case LogLevel::Info:
      return "[INFO] ";
    case LogLevel::Warn:
      return "[WARN] ";
    case LogLevel::Error:
      return "[ERROR]";
    default:
      return "[UNKNOWN]";
    }
  }
};
} // namespace Core
