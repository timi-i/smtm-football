FROM python:3.12-slim AS intel-builder

WORKDIR /app

COPY intel-service/requirements.txt ./intel-service/requirements.txt

RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends gcc g++ make curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv && /opt/venv/bin/pip install --no-cache-dir -r intel-service/requirements.txt python-dotenv

COPY intel-service/ ./intel-service/

# 验证 venv 已创建
RUN test -x /opt/venv/bin/python && echo "Python venv 已创建"

FROM node:20-slim AS main-builder

WORKDIR /app

COPY daily-football-predictor/package.json ./daily-football-predictor/package.json

RUN npm --prefix daily-football-predictor install --no-audit --no-fund --production=false

COPY daily-football-predictor/ ./daily-football-predictor/
RUN mkdir -p daily-football-predictor/data

FROM node:20-slim AS runtime

ARG VERSION=manual

LABEL org.opencontainers.image.source="https://github.com/timi-i/smtm-football" \
      org.opencontainers.image.description="足球预测实验室:统计模型 + 情报服务" \
      org.opencontainers.image.version="${VERSION}"

WORKDIR /app

# 时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && apt-get update -qq \
    && apt-get install -y --no-install-recommends tzdata cron ca-certificates curl procps \
    && rm -rf /var/lib/apt/lists/*

# 创建非 root 用户
RUN groupadd -r app && useradd -r -g app app

# 复制 Python venv（从 intel-builder 阶段）
COPY --from=intel-builder /opt/venv /opt/venv

# 复制应用代码
COPY --from=intel-builder --chown=app:app /app/intel-service /app/intel-service
COPY --from=main-builder --chown=app:app /app/daily-football-predictor /app/daily-football-predictor
COPY deploy/ /app/deploy/

RUN chmod 755 /app/deploy/start.sh \
    && mkdir -p /app/logs /var/log/cron /var/run \
    && chown -R app:app /app /var/log/cron /var/run

USER app

EXPOSE 4173

CMD ["/app/deploy/start.sh"]
