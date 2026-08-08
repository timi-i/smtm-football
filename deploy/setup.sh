#!/usr/bin/env bash
# 部署配置脚本:配置定时任务(cron),让情报服务和主项目自动运行
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INTEL_DIR="$REPO_DIR/intel-service"
MAIN_DIR="$REPO_DIR/daily-football-predictor"
CYCLE_SCRIPT="$INTEL_DIR/run-cycle.sh"
CRON_INTERVAL_MIN="${CRON_INTERVAL_MIN:-30}"

echo "==> 校验路径"
[ -d "$INTEL_DIR" ] || { echo "缺少 $INTEL_DIR"; exit 1; }
[ -d "$MAIN_DIR" ] || { echo "缺少 $MAIN_DIR"; exit 1; }
[ -x "$CYCLE_SCRIPT" ] || chmod +x "$CYCLE_SCRIPT"

echo "==> 检查 .env"
if [ ! -f "$INTEL_DIR/.env" ]; then
  cp "$INTEL_DIR/.env.example" "$INTEL_DIR/.env"
  echo "已从模板创建 $INTEL_DIR/.env,请编辑填入 LLM_API_KEY"
fi

echo "==> 配置 cron (每 ${CRON_INTERVAL_MIN} 分钟)"
CRON_LINE="*/${CRON_INTERVAL_MIN} * * * * cd $REPO_DIR && $CYCLE_SCRIPT >> $REPO_DIR/logs/cycle.log 2>&1"

mkdir -p "$REPO_DIR/logs"

# 移除旧的同类 cron 条目,避免重复
(crontab -l 2>/dev/null || true) | grep -v "run-cycle.sh" > /tmp/crontab.tmp || true
echo "$CRON_LINE" >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm -f /tmp/crontab.tmp

echo "==> 当前 cron:"
crontab -l

echo "==> 立即测试一次完整周期"
(cd "$REPO_DIR" && "$CYCLE_SCRIPT" --skip-intel) || echo "[setup] 首次测试未完全成功,请查看日志;cron 已配置,下次周期会自动重试。"

echo "==> 完成。"
echo "  日志: $REPO_DIR/logs/cycle.log"
echo "  查看: tail -f $REPO_DIR/logs/cycle.log"
