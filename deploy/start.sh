#!/usr/bin/env bash
set -euo pipefail
export TZ=Asia/Shanghai
cd /app

echo "[start] $(date) 首次运行..."

# 情报服务
bash intel-service/run-cycle.sh 2>&1 || echo "[warn] 情报失败"

# 主项目
cd daily-football-predictor
npm run update 2>&1 || echo "[warn] 主项目失败"

echo "[start] $(date) 启动 cron..."
# 创建 cron 日志目录
mkdir -p /tmp/cronlogs
crontab /app/deploy/cron.d/cron

# 后台跟踪
tail -f /tmp/cronlogs/*.log /app/logs/*.log 2>/dev/null &
trap 'kill 0' INT TERM EXIT

exec cron -f -L /tmp/cronlogs/cron.log 2>&1 || cron -f
