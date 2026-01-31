#pragma once

#if defined(__APPLE__)

// Apple 的 DYLD_INTERPOSE 宏用于函数 Hook
// 参考：https://opensource.apple.com/source/dyld/dyld-210.2.3/include/mach-o/dyld-interposing.h.auto.html
// 创建 __DATA,__interpose 段，dyld 会读取该段来重定向函数调用

#define DYLD_INTERPOSE(_replacement, _replacee)                                \
  __attribute__((used)) static struct {                                        \
    const void *replacement;                                                   \
    const void *replacee;                                                      \
  } _interpose_##_replacee __attribute__((section("__DATA,__interpose"))) = {  \
      (const void *)(unsigned long)&_replacement,                              \
      (const void *)(unsigned long)&_replacee};

#endif
