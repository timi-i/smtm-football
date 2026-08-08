# 足球预测实验室 · 全栈部署版

由两个子项目组成的单仓库:

```
smtm-football/
├── daily-football-predictor/   # 主项目:统计模型预测(市场赔率 + Elo + 蒙特卡洛 + 全日组合分配)
├── intel-service/              # 情报服务:抓新闻 + LLM 清洗成结构化信号
└── deploy/                     # Ubuntu/Debian 一键部署脚本
```

## 整体流程

```
Google News RSS ──> intel-service ──> data/adjustments.json ──> daily-football-predictor
                        │                  (情报信号)                │
                        └─ LLM 清洗 ──> teamNews/coachNews          └─> 读取信号 → 重新预测 → GitHub Pages
```

主项目每 30 分钟自动从体彩网拉赛程/赔率/赛果,更新 Elo 和校准参数,为未来两日未开赛比赛生成五项预测(胜平负/让球/比分/总进球/半全场),并在赛后自动验真。情报服务补充 LLM 清洗过的新闻信号,让模型能感知"核心前锋伤缺"这类非结构化信息。

## 快速开始(服务器 Ubuntu/Debian)

```bash
# 1. 拉取仓库
git clone <你的仓库地址> && cd smtm-football

# 2. 一键部署(Node20 + Python venv + cron)
sudo bash deploy/deploy.sh

# 3. 配置 LLM key(可选)
vim intel-service/.env        # 填入 LLM_API_KEY / LLM_BASE_URL / LLM_MODEL

# 4. 手动测试
bash intel-service/run-cycle.sh
tail -f logs/cycle.log
```

## 目录说明

### daily-football-predictor

- `scripts/update.mjs` 主更新循环(读取情报 → 预测 → 验真 → 提交)
- `scripts/lib/model.mjs` 核心模型(predictMatch / monteCarlo / calibrate)
- `scripts/lib/sporttery.mjs` 体彩网数据层
- `scripts/lib/dongqiudi.mjs` 懂球帝战术层
- `data/predictions.json` 站点数据,可部署到 GitHub Pages

### intel-service

- `main.py` 入口(读赛程 → 抓新闻 → LLM 清洗 → 写 adjustments.json)
- `intel/sources/news.py` Google News RSS 抓取
- `intel/cleaner.py` LLM 清洗池(OpenAI 兼容 API)
- `intel/output.py` 写入/合并 adjustments.json(自动信号不覆盖人工配置)
- `run-cycle.sh` 单次完整周期(情报 + 主项目)

### deploy

- `install.sh` 安装 Node 20+ / Python venv / cron
- `setup.sh` 配置每 30 分钟 cron 定时跑 run-cycle.sh
- `deploy.sh` 一键向导

## 配置

环境变量见 `intel-service/.env.example`,支持 OpenAI / DeepSeek / 通义 / Moonshot 等兼容接口。
情报服务生成的信号带来源、可信度、失效时间,进球修正幅度被主项目限制在 ±0.45,可审计可追溯。

## 声明

本项目仅用于模型研究与数据验证,不构成投注建议。任何预测都不能保证正确或盈利。
