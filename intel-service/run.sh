#!/usr/bin/env bash
# 运行情报服务并写入主项目的 data/adjustments.json
# 用法:
#   ./run.sh                 # 正常模式(需已配置 .env)
#   LLM_API_KEY=xxx ./run.sh # 临时传入 API key
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    echo "[intel] 未找到 .env,复制 .env.example 作为模板"
    cp .env.example .env
    echo "[intel] 请编辑 .env 填入 LLM_API_KEY 并设置 PREDICTIONS_PATH/ADJUSTMENTS_PATH"
  fi
fi

# 默认指向主项目数据目录
if [ ! -f .env ] || ! grep -q "PREDICTIONS_PATH" .env; then
  PREDICTIONS_PATH="${PREDICTIONS_PATH:-$(dirname "$DIR")/daily-football-predictor/data/predictions.json}"
  ADJUSTMENTS_PATH="${ADJUSTMENTS_PATH:-$(dirname "$DIR")/daily-football-predictor/data/adjustments.json}"
fi

exec "$DIR/.venv/bin/python" main.py "$@"
