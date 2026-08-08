FROM python:3.12-slim

WORKDIR /app

# 时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && apt-get update -qq && apt-get install -y --no-install-recommends cron curl \
    && rm -rf /var/lib/apt/lists/*

# 情报服务依赖
COPY intel-service/requirements.txt ./intel-service/requirements.txt
RUN python -m venv /opt/venv && /opt/venv/bin/pip install -r intel-service/requirements.txt python-dotenv

COPY intel-service/ ./intel-service/

# 主项目（Node 20）
FROM node:20-slim

WORKDIR /app
ENV TZ=Asia/Shanghai

# 复制 Python 环境
COPY --from=0 /opt/venv /opt/venv

# 复制应用
COPY daily-football-predictor/ ./daily-football-predictor/
COPY intel-service/ ./intel-service/
COPY deploy/ ./deploy/

RUN mkdir -p data logs && npm install --prefix daily-football-predictor --no-audit --no-fund

EXPOSE 4173
CMD ["bash", "/app/deploy/start.sh"]
