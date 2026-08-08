# 足球赛前情报服务 (intel-service)

独立于主项目 `daily-football-predictor` 的 Python 情报清洗池。
抓取球队相关新闻/伤停情报,用 LLM(OpenAI 兼容接口)清洗成结构化信号,
写入主项目 `data/adjustments.json`,主项目 `npm run update` 时会自动读取并参与预测。

## 为什么需要它

主项目核心是统计模型(市场赔率 + Elo + 蒙特卡洛),但新闻/伤停这类**非结构化文本**它看不懂。
本服务把它们变成模型能用的 `{label, confidence, homeGoalsDelta, awayGoalsDelta}` 信号。

设计原则(与主项目一致):
- **LLM 只做信息清洗,不参与概率计算**。最终进球修正幅度由主项目限制在 ±0.45 内。
- **不覆盖人工录入**。自动信号带 `__auto__` 标记,人工配置优先。
- **可审计**。每条信号保留来源链接、可信度和失效时间(`expiresAt`)。

## 目录结构

```
intel-service/
├── config.py              # 环境配置(支持 .env)
├── main.py                # 入口:读取比赛 → 抓新闻 → LLM 清洗 → 写输出
├── run.sh                 # 便捷运行脚本
├── requirements.txt
├── .env.example           # 配置模板
└── intel/
    ├── loader.py          # 读取主项目 predictions.json 的待预测比赛
    ├── cleaner.py         # LLM 清洗池(OpenAI 兼容 API)
    ├── output.py          # 写入/合并 adjustments.json
    └── sources/
        └── news.py        # Google News RSS 新闻抓取
```

## 快速开始

```bash
cd intel-service
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env
# 编辑 .env:填入 LLM_API_KEY、LLM_BASE_URL、LLM_MODEL
# 默认 PREDICTIONS_PATH/ADJUSTMENTS_PATH 指向 ../daily-football-predictor/data/
./run.sh
```

## 配置项(.env)

| 变量 | 说明 | 默认值 |
|---|---|---|
| `LLM_API_KEY` | OpenAI 兼容接口 key(OpenAI/DeepSeek/通义/Moonshot 均可) | 空(则不启用 LLM,仅保存原始新闻) |
| `LLM_BASE_URL` | 接口地址 | `https://api.openai.com/v1` |
| `LLM_MODEL` | 模型名 | `gpt-4o-mini` |
| `PREDICTIONS_PATH` | 主项目 predictions.json 路径 | `../daily-football-predictor/data/predictions.json` |
| `ADJUSTMENTS_PATH` | 输出 adjustments.json 路径 | `../daily-football-predictor/data/adjustments.json` |
| `NEWS_LANGUAGE` | 新闻语言 | `zh-CN` |
| `NEWS_PER_MATCH` | 每场最多保留新闻条数 | `8` |
| `NEWS_MAX_MATCHES` | 每轮最多处理比赛场数 | `20` |
| `WRITE_OUTPUT` | 写入文件还是仅打印 | `true` |

## 输出格式

写入主项目 `data/adjustments.json`(schema v2,兼容主项目 `context-feed.mjs`):

```json
{
  "version": 2,
  "matches": {
    "2040701": {
      "expiresAt": "2026-08-08T22:00:00+08:00",
      "source": "intel-service",
      "__auto__": true,
      "teamNews": [
        {
          "type": "injury",
          "label": "主队核心前锋缺阵",
          "source": "新闻标题/URL",
          "confidence": 0.9,
          "homeGoalsDelta": -0.2,
          "awayGoalsDelta": 0
        }
      ]
    }
  }
}
```

## 与主项目集成

```bash
# 1. 生成情报
cd intel-service && ./run.sh
# 2. 主项目读取并重新预测
cd ../daily-football-predictor && npm run update
```

之后照常由 GitHub Actions 每 30 分钟自动跑主项目;情报服务可放在同一台常开机器上,
用 cron 每 30 分钟跑一次: `*/30 * * * * /path/to/intel-service/run.sh`

## 注意

- 情报质量取决于 LLM 和新闻源,信号会自动带上 `confidence`,主项目按可信度缩放。
- 本服务不构成投注建议,仅用于数据研究。
