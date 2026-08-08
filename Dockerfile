FROM node:20-slim AS main-builder

WORKDIR /app

COPY daily-football-predictor/package.json ./daily-football-predictor/package.json

# 项目无 package-lock.json，用 npm install 而非 npm ci
RUN npm --prefix daily-football-predictor install --no-audit --no-fund --production=false

COPY daily-football-predictor/ ./daily-football-predictor/

# data/ 在构建时不存在(由运行时填充),但保持结构
RUN mkdir -p daily-football-predictor/data

FROM python:3.12-slim AS intel-builder

WORKDIR /app

COPY intel-service/requirements.txt ./intel-service/requirements.txt

RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends gcc g++ make curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv && /opt/venv/bin/pip install --no-cache-dir -r intel-service/requirements.txt python-dotenv

COPY intel-service/ ./intel-service/

FROM node:20-slim AS runtime

ARG VERSION=manual

LABEL org.opencontainers.image.source="https://github.com/timi-i/smtm-football" \
      org.opencontainers.image.description="足球预测实验室:统计模型 + 情报服务" \
      org.opencontainers.image.version="${VERSION}"

WORKDIR /app

RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends cron ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r app && useradd -r -g app app

COPY --from=intel-builder --chown=app:app /opt/venv /opt/venv
COPY --from=intel-builder --chown=app:app /app/intel-service /app/intel-service

COPY --from=main-builder --chown=app:app /app/daily-football-predictor /app/daily-football-predictor
COPY deploy/cron.d /app/deploy/cron.d
COPY deploy/start.sh /app/deploy/start.sh

RUN chmod 755 /app/deploy/start.sh \
    && mkdir -p /app/logs /var/log/cron && chown app:app /app/logs

USER app

EXPOSE 4173

CMD ["/app/deploy/start.sh"]
