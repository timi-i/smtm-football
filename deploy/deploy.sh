#!/usr/bin/env bash
# 完整安装向导:install.sh -> 配置 .env -> setup.sh
# 用法: sudo bash deploy.sh [CRON_INTERVAL_MIN]
set -euo pipefail

CRON_INTERVAL_MIN="${1:-30}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========== 足球预测 + 情报服务 一键部署 =========="
echo ""

echo "==> 第 1 步:安装环境 (Node 20+, Python, cron)"
bash "$SCRIPT_DIR/install.sh"

echo ""
echo "==> 第 2 步:提示"
INTEL_DIR="$(dirname "$SCRIPT_DIR")/intel-service"
if [ ! -f "$INTEL_DIR/.env" ]; then
  cp "$INTEL_DIR/.env.example" "$INTEL_DIR/.env"
fi
echo "请编辑 $INTEL_DIR/.env 填入 LLM_API_KEY(OpenAI/DeepSeek/通义均可)"
echo "可跳过:未配置 key 时情报服务降级为仅保存原文,不影响主项目预测。"

echo ""
echo "==> 第 3 步:配置定时任务 (每 ${CRON_INTERVAL_MIN} 分钟)"
CRON_INTERVAL_MIN="$CRON_INTERVAL_MIN" bash "$SCRIPT_DIR/setup.sh"

echo ""
echo "========== 部署完成 =========="
echo "站点预览(主项目): cd $(dirname "$SCRIPT_DIR")/daily-football-predictor && npm run serve"
