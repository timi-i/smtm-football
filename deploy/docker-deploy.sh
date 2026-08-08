#!/usr/bin/env bash
# 构建并启动 Docker 服务
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR/.."

echo "==> 创建持久化目录"
mkdir -p data logs
touch data/.gitkeep logs/.gitkeep

if [ ! -f intel-service/.env ]; then
  cp intel-service/.env.example intel-service/.env
  echo "已创建 intel-service/.env,请填入 LLM_API_KEY 等配置"
fi

echo "==> 构建镜像 (BUILD_VERSION=$BUILD_VERSION)"
docker compose build --progress=plain 2>&1 | tail -30

echo "==> 启动服务"
docker compose up -d

echo "==> 容器状态"
docker compose ps

echo "==> 最近日志"
docker compose logs --tail=20 football-predictor

echo ""
echo "完成。"
echo "  站点预览: http://<服务器IP>:4173"
echo "  查看日志: docker compose logs -f football-predictor"
echo "  重启:     docker compose restart football-predictor"
echo "  重建:     BUILD_VERSION=x.x.x docker compose up -d --build"
