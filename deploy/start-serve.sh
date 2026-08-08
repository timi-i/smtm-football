#!/usr/bin/env bash
# 后台启动预测服务
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/serve.log"

mkdir -p "$LOG_DIR"

# 检查是否已在运行
if lsof -t -i:4173 &>/dev/null; then
  echo "[serve] 服务已在运行 (PID: $(lsof -t -i:4173))"
  exit 0
fi

# 后台启动
cd "$PROJECT_DIR/daily-football-predictor"
nohup npm run serve > "$LOG_FILE" 2>&1 &
PID=$!

# 等待启动
sleep 2
if kill -0 $PID 2>/dev/null; then
  echo "[serve] 已启动 (PID: $PID)"
  echo "[serve] 日志: $LOG_FILE"
  echo "[serve] 访问: http://$(hostname -I | awk '{print $1}'):4173"
else
  echo "[serve] 启动失败，查看日志: $LOG_FILE"
  tail -20 "$LOG_FILE"
  exit 1
fi
