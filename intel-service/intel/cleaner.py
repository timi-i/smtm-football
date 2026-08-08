import json
import logging
from typing import Any, Dict, List

from config import settings

try:
    from openai import OpenAI
except ImportError:  # pragma: no cover
    OpenAI = None

log = logging.getLogger("intel.cleaner")

SYSTEM_PROMPT = """你是足球赛前情报分析师。输入一场比赛的双方球队、联赛以及抓取到的新闻标题。
请判断每条新闻是否会影响比赛胜平负(通过影响进球数),只保留有真实影响的信息。

输出严格 JSON 数组,每个元素结构:
{
  "type": "injury" | "lineup" | "coach_change" | "suspension" | "form" | "news",
  "label": "一句话中文摘要(含球员/教练姓名)",
  "source": "新闻标题",
  "confidence": 0到1之间的数字,
  "homeGoalsDelta": 对主队进球期望的修正(-0.4到0.4),
  "awayGoalsDelta": 对客队进球期望的修正(-0.4到0.4)
}

规则:
- homeGoalsDelta/awayGoalsDelta 必须是对应的球队。新闻说“主队核心前锋伤缺”,则 homeGoalsDelta 为负。
- 缺阵影响小的(轮换、替补)给低 confidence(0.3-0.5),核心球员缺阵给高 confidence(0.7-0.95)。
- 无关或信息量不足的新闻不要输出(输出空数组)。
- 只输出 JSON 数组,不要任何其他文字。
"""


def _build_user_prompt(match: Dict[str, Any], news: List[Dict[str, Any]]) -> str:
    lines = [
        f"比赛: {match.get('home')} vs {match.get('away')}",
        f"联赛: {match.get('league') or match.get('leagueFull') or '未知'}",
        f"开赛: {match.get('kickoff') or match.get('kickoffDate') or '未知'}",
        "",
        "抓取到的新闻:",
    ]
    for index, item in enumerate(news, 1):
        lines.append(f"{index}. [{item.get('published', '')}] {item.get('title', '')}")
        if item.get("snippet"):
            lines.append(f"   摘要: {item['snippet'][:120]}")
    return "\n".join(lines)


def clean_news_with_llm(match: Dict[str, Any], news: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """调用 OpenAI 兼容 API,把新闻清洗成结构化信号。失败时返回空列表。"""
    if not news:
        return []
    if OpenAI is None:
        log.warning("缺少 openai 依赖,LLM 清洗不可用")
        return []
    client = OpenAI(api_key=settings.LLM_API_KEY, base_url=settings.LLM_BASE_URL, timeout=settings.LLM_TIMEOUT)
    try:
        resp = client.chat.completions.create(
            model=settings.LLM_MODEL,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": _build_user_prompt(match, news)},
            ],
            temperature=0.2,
            response_format={"type": "json_object"},
        )
        content = resp.choices[0].message.content or "{}"
        # 兼容部分兼容接口不返回 json_object,尝试从返回中提取数组
        payload = json.loads(content)
        if isinstance(payload, dict):
            payload = payload.get("signals") or payload.get("items") or payload.get("news") or []
        if not isinstance(payload, list):
            raise ValueError(f"LLM 返回格式异常: {content[:120]}")
        # 校验字段
        cleaned = []
        for item in payload:
            if not isinstance(item, dict):
                continue
            try:
                cleaned.append(_sanitize_signal(item))
            except ValueError:
                continue
        log.info("LLM 清洗 [%s vs %s] -> %d 条信号", match.get("home"), match.get("away"), len(cleaned))
        return cleaned
    except Exception as error:
        log.warning("LLM 清洗失败: %s", error)
        return []


def _clamp(value, low, high):
    try:
        number = float(value)
    except (TypeError, ValueError):
        return 0.0
    return max(low, min(high, number))


def _sanitize_signal(item: Dict[str, Any]) -> Dict[str, Any]:
    label = str(item.get("label") or "").strip()
    if not label:
        raise ValueError("empty label")
    confidence = _clamp(item.get("confidence", 0.5), 0, 1)
    signal = {
        "type": str(item.get("type") or "news"),
        "label": label,
        "source": str(item.get("source") or "外部情报服务"),
        "confidence": round(confidence, 2),
        "homeGoalsDelta": round(_clamp(item.get("homeGoalsDelta", 0), -0.4, 0.4), 3),
        "awayGoalsDelta": round(_clamp(item.get("awayGoalsDelta", 0), -0.4, 0.4), 3),
    }
    return signal
