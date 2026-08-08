#!/usr/bin/env bash
# 容器启动脚本:先跑一次完整周期(cron 在后台持续),然后守护 cron
set -euo pipefail

cd /app

echo "[start] $(date) 首次运行完整周期..."
bash intel-service/run-cycle.sh
RET=$?
if [ "$RET" -ne 0 ]; then
  echo "[start] 情报服务异常退出码 $RET,继续启动 cron"
fi

echo "[start] $(date) 启动 cron(每 ${CRON_INTERVAL_MIN:-30} 分钟)"
crontab deploy/cron.d/cron

tail -f /var/log/cron/cron.log 2>/dev/null &
CRON_LOG_PID=$!
trap 'kill $CRON_LOG_PID 2>/dev/null; exit 0' INT TERM EXIT

exec cron -f
