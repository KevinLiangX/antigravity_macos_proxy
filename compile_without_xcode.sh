#!/bin/bash
set -e

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "[*] Compiling AntigravityTun Dylib using ${GREEN}clang++${NC} (Command Line Tools)..."

# 检查 clang 是否存在
if ! command -v clang++ &> /dev/null; then
    echo -e "${RED}[Error] clang++ not found. Please run 'xcode-select --install'${NC}"
    exit 1
fi

# 编译命令
# -std=c++17: 使用 C++17 标准
# -dynamiclib: 生成动态库
# -O3: 最高级优化
# -I ...: 头文件搜索路径
clang++ -std=c++17 -dynamiclib -O3 \
    -I AntigravityTun/AntigravityTun \
    AntigravityTun/AntigravityTun/AntigravityTun.cpp \
    -o libAntigravityTun.dylib

if [ -f "libAntigravityTun.dylib" ]; then
    echo -e "${GREEN}[Success] libAntigravityTun.dylib generated.${NC}"
else
    echo -e "${RED}[Fail] Build failed.${NC}"
    exit 1
fi
