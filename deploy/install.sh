#!/usr/bin/env bash
# 一次性环境安装脚本 (Ubuntu/Debian)
# 安装 Node.js 20+, Python3 venv + pip,并初始化 intel-service 虚拟环境
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "请用 root 或 sudo 运行: sudo bash install.sh"
  exit 1
fi

echo "==> 更新 apt 索引"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y -q

echo "==> 安装基础依赖"
apt-get install -y -q ca-certificates curl gnupg python3 python3-venv python3-pip git cron

echo "==> 安装 Node.js 20+"
if command -v node >/dev/null 2>&1 && node --version | grep -qE '^v(2[0-9]|[1-9][0-9]|[2-9][0-9])'; then
  echo "已安装 Node: $(node --version)"
else
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - || true
  apt-get install -y -q nodejs || {
    echo "Nodesource 安装失败,尝试用 Node 官方二进制..."
    ARCH=$(uname -m)
    case "$ARCH" in
      x86_64) NODE_ARCH="linux-x64" ;;
      aarch64) NODE_ARCH="linux-arm64" ;;
      *) echo "不支持的架构 $ARCH"; exit 1 ;;
    esac
    curl -fsSL "https://nodejs.org/dist/v20.18.0/node-v20.18.0-${NODE_ARCH}.tar.xz" -o /tmp/node.tar.xz
    mkdir -p /usr/local/lib/nodejs
    tar -xJf /tmp/node.tar.xz -C /usr/local/lib/nodejs
    ln -sf "/usr/local/lib/nodejs/node-v20.18.0-${NODE_ARCH}/bin/node" /usr/local/bin/node
    ln -sf "/usr/local/lib/nodejs/node-v20.18.0-${NODE_ARCH}/bin/npm" /usr/local/bin/npm
    rm -f /tmp/node.tar.xz
  }
fi

echo "==> 验证 Node"
node --version && npm --version

echo "==> 初始化 intel-service 虚拟环境"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTEL_DIR="$(dirname "$SCRIPT_DIR")/intel-service"
if [ -d "$INTEL_DIR" ]; then
  cd "$INTEL_DIR"
  if [ ! -d .venv ]; then
    python3 -m venv .venv
  fi
  .venv/bin/pip install --upgrade pip -q
  .venv/bin/pip install -q -r requirements.txt python-dotenv
  echo "intel-service 依赖已安装"
else
  echo "未找到 intel-service 目录(期望 $INTEL_DIR),跳过依赖安装"
fi

echo "==> 完成。下一步:"
echo "  1) 编辑 intel-service/.env 填入 LLM_API_KEY 等配置"
echo "  2) 运行 bash setup.sh 配置定时任务"
