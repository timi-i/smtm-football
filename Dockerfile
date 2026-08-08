FROM node:20-slim AS main-builder

WORKDIR /app

COPY daily-football-predictor/package.json ./daily-football-predictor/package.json
RUN npm --prefix daily-football-predictor install --no-audit --no-fund --production=false
COPY daily-football-predictor/ ./daily-football-predictor/
RUN mkdir -p daily-football-predictor/data

FROM python:3.12-slim AS intel-builder

WORKDIR /app
COPY intel-service/requirements.txt ./intel-service/requirements.txt

RUN apt-get update -qq && apt-get install -y --no-install-recommends gcc g++ make curl ca-certificates && rm -rf /var/lib/apt/lists/*
RUN python -m venv /opt/venv && /opt/venv/bin/pip install --no-cache-dir -r intel-service/requirements.txt python-dotenv

COPY intel-service/ ./intel-service/
RUN test -f /opt/venv/bin/python

FROM node:20-slim AS runtime

ARG VERSION=manual
LABEL org.opencontainers.image.source="https://github.com/timi-i/smtm-football"

WORKDIR /app
ENV TZ=Asia/Shanghai

RUN apt-get update -qq && apt-get install -y --no-install-recommends tzdata cron ca-certificates curl procps && rm -rf /var/lib/apt/lists/*

# 复制 Python venv（完整复制）
COPY --from=intel-builder /opt/venv /opt/venv
COPY --from=intel-builder /app/intel-service /app/intel-service

# 复制 Node 项目
COPY --from=main-builder /app/daily-football-predictor /app/daily-football-predictor
COPY deploy/ /app/deploy/

# 创建用户和目录
RUN groupadd -r app && useradd -r -g app app
RUN chmod 755 /app/deploy/start.sh
RUN mkdir -p /app/logs /var/log/cron /var/run && chown -R app:app /app /var/log/cron /var/run

USER app
EXPOSE 4173
CMD ["/app/deploy/start.sh"]
