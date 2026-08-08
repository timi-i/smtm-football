#!/usr/bin/env bash
# 本地运行脚本（无需 Docker）
set -euo pipefail

# 脚本所在目录是 deploy/，项目根目录是上层
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "==> 检查 Node.js"
if ! command -v node &>/dev/null; then
  echo "请安装 Node.js 20+: curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs"
  exit 1
fi
echo "Node: $(node --version)"

echo "==> 检查 Python"
if ! command -v python3 &>/dev/null; then
  echo "请安装 Python 3.10+"
  exit 1
fi
echo "Python: $(python3 --version)"

echo "==> 安装情报服务依赖"
cd "$PROJECT_DIR/intel-service"
if [ ! -d .venv ]; then
  python3 -m venv .venv
  .venv/bin/pip install -q -r requirements.txt python-dotenv
fi

echo "==> 配置 .env"
if [ ! -f .env ]; then
  cp .env.example .env
  echo "已创建 .env，请编辑填入 LLM_API_KEY"
fi

echo "==> 运行情报服务"
PREDICTIONS_PATH="$PROJECT_DIR/daily-football-predictor/data/predictions.json" \
ADJUSTMENTS_PATH="$PROJECT_DIR/daily-football-predictor/data/adjustments.json" \
LLM_API_KEY="${LLM_API_KEY:-}" \
.venv/bin/python main.py

echo "==> 运行主项目"
cd "$PROJECT_DIR/daily-football-predictor"
npm run update

echo "==> 完成"
