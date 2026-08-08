#!/usr/bin/env bash
# 容器启动脚本
set -euo pipefail

export TZ=Asia/Shanghai
cd /app

echo "[start] $(date) 首次运行完整周期..."

# 运行情报服务
bash intel-service/run-cycle.sh || echo "[warn] 情报服务失败，继续主项目"

# 运行主项目 update
echo "[start] 运行主项目 update..."
npm --prefix daily-football-predictor run update || echo "[warn] 主项目 update 失败，等待下次 cron"

echo "[start] $(date) 启动 cron..."
# 修复 cron 权限
chmod 755 /var/run
crontab /app/deploy/cron.d/cron

# 后台跟踪日志
tail -f /var/log/cron.log /app/logs/cycle.log 2>/dev/null &
LOG_PID=$!
trap 'kill $LOG_PID 2>/dev/null; exit 0' INT TERM EXIT

# 前台运行 cron
exec cron -f -l 2
