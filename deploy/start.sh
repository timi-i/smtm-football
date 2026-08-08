#!/usr/bin/env bash
# 容器启动脚本:先跑一次完整周期(cron 在后台持续),然后守护 cron
set -euo pipefail

export TZ=Asia/Shanghai
cd /app

echo "[start] $(date) 首次运行完整周期..."

# 运行情报服务（失败不阻断主项目）
if bash intel-service/run-cycle.sh; then
  echo "[cycle] 情报服务成功"
else
  echo "[cycle] 情报服务失败,继续执行主项目"
fi

echo "[start] $(date) 启动 cron..."
crontab deploy/cron.d/cron || echo "[warn] crontab 失败,尝试手动运行"

# 后台日志跟踪
tail -f /var/log/cron/cron.log /app/logs/cycle.log 2>/dev/null &
LOG_PID=$!
trap 'kill $LOG_PID 2>/dev/null; exit 0' INT TERM EXIT

# 前台运行 cron
exec cron -f -l 2
