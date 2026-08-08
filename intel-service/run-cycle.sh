#!/usr/bin/env bash
# 单次完整周期:
#   1) 情报服务生成/更新 data/adjustments.json
#   2) 主项目读取情报,更新 Elo/校准并重新预测
# 用法: ./run-cycle.sh [--skip-intel]
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_DIR="$(dirname "$DIR")/daily-football-predictor"

echo "[cycle] $(date '+%F %T') 开始情报服务..."
if [ "${1:-}" = "--skip-intel" ]; then
  echo "[cycle] 跳过情报服务(--skip-intel)"
else
  "$DIR/run.sh" || echo "[cycle] 情报服务返回非零,继续执行主项目(情报失败不阻断预测)"
fi

echo "[cycle] $(date '+%F %T') 运行主项目 update..."
if [ ! -d "$MAIN_DIR" ]; then
  echo "[cycle] 错误:主项目目录不存在: $MAIN_DIR"
  exit 1
fi
cd "$MAIN_DIR"
if ! command -v node >/dev/null 2>&1; then
  echo "[cycle] 错误:未找到 node,请先运行 deploy/install.sh 安装 Node 20+"
  exit 1
fi
if [ -d node_modules ]; then
  npm run update || echo "[cycle] 主项目 update 失败,请查看上方日志"
else
  echo "[cycle] 主项目无第三方依赖(node_modules 不需要),直接运行:"
  npm run update || echo "[cycle] 主项目 update 失败,请查看上方日志"
fi

echo "[cycle] $(date '+%F %T') 完成。"
