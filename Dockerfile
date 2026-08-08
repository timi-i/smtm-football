FROM python:3.12-slim

WORKDIR /app

# 时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && apt-get update -qq && apt-get install -y --no-install-recommends cron curl \
    && rm -rf /var/lib/apt/lists/*

# 情报服务
COPY intel-service/requirements.txt ./intel-service/requirements.txt
RUN python -m venv /opt/venv && /opt/venv/bin/pip install -r intel-service/requirements.txt python-dotenv

COPY intel-service/ ./intel-service/
COPY deploy/cron.d /app/deploy/cron.d
COPY deploy/start-intel.sh /app/deploy/start.sh

RUN chmod 755 /app/deploy/start.sh && mkdir -p /app/logs

EXPOSE 4173
CMD ["/app/deploy/start.sh"]
