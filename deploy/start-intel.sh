#!/usr/bin/env bash
# 情报服务启动脚本（香港服务器专用）
set -euo pipefail

export TZ=Asia/Shanghai
cd /app

echo "[start] $(date) 首次运行情报服务..."

# 运行情报服务
bash intel-service/run.sh 2>&1 || echo "[warn] 情报服务失败"

echo "[start] $(date) 启动 cron..."
# 创建日志目录
mkdir -p /app/logs

# 写入 cron 任务
echo "*/30 * * * * cd /app && bash intel-service/run.sh >> /app/logs/cycle.log 2>&1" | crontab -

# 后台跟踪日志
tail -f /app/logs/cycle.log 2>/dev/null &
trap 'kill 0' INT TERM EXIT

# 前台运行 cron
exec cron -f
