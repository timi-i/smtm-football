import json
import logging
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List

log = logging.getLogger("intel.output")

DEFAULT_TTL_HOURS = 12


def _read_existing(path: Path) -> Dict[str, Any]:
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"version": 2, "matches": {}}


def _expires_at(hours: int = DEFAULT_TTL_HOURS) -> str:
    now = datetime.now(timezone(timedelta(hours=8)))
    return (now + timedelta(hours=hours)).isoformat()


def build_match_entry(signals: List[Dict[str, Any]]) -> Dict[str, Any]:
    """把 LLM 清洗后的信号按主项目 schema 分成 teamNews/coachNews。"""
    team_news = []
    coach_news = []
    for signal in signals:
        if signal.get("type") == "coach_change":
            coach_news.append(signal)
        else:
            team_news.append(signal)
    entry: Dict[str, Any] = {"expiresAt": _expires_at()}
    if team_news:
        entry["teamNews"] = team_news
    if coach_news:
        entry["coachNews"] = coach_news
    return entry


def write_adjustments(matches: Dict[str, Dict[str, Any]], path: Path) -> Path:
    """合并写入主项目 data/adjustments.json。保留已有人工配置。"""
    existing = _read_existing(path)
    merged = dict(existing.get("matches") or {})
    # 自动信号不覆盖人工录入:人工条目不带 __auto__ 标记
    for key, entry in matches.items():
        if not entry:
            continue
        previous = merged.get(key) or {}
        entry["__auto__"] = True
        entry["source"] = "intel-service"
        if "__auto__" in previous:
            merged[key] = entry  # 同为自动,覆盖
        else:
            # 合并,保留人工字段
            merged[key] = {
                **entry,
                **{k: v for k, v in previous.items() if k not in ("__auto__", "source", "expiresAt")},
            }
    result = {
        "version": 2,
        "description": "由 intel-service 自动生成的赛前情报,与人工录入合并。",
        "updatedAt": datetime.now(timezone(timedelta(hours=8))).isoformat(),
        "matches": merged,
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(result, fh, ensure_ascii=False, indent=2)
    log.info("已写入 %s (共 %d 场比赛情报)", path, len(matches))
    return path
