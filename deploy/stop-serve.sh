#!/usr/bin/env bash
# 停止预测服务
set -euo pipefail

PID=$(lsof -t -i:4173 2>/dev/null || true)
if [ -z "$PID" ]; then
  echo "[serve] 服务未运行"
  exit 0
fi

kill "$PID"
sleep 1
if kill -0 "$PID" 2>/dev/null; then
  kill -9 "$PID"
  echo "[serve] 已强制停止 (PID: $PID)"
else
  echo "[serve] 已停止 (PID: $PID)"
fi
