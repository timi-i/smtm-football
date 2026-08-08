import json
import logging
from typing import Any, Dict, List, Optional

log = logging.getLogger("intel.loader")


def load_predictions(path) -> List[Dict[str, Any]]:
    """读取主项目的 predictions.json,返回待预测的未开赛比赛列表。"""
    try:
        with open(path, "r", encoding="utf-8") as fh:
            payload = json.load(fh)
    except FileNotFoundError:
        log.warning("未找到 predictions.json: %s", path)
        return []
    except json.JSONDecodeError as error:
        log.error("predictions.json 解析失败: %s", error)
        return []

    matches = payload.get("matches") or []
    upcoming = []
    for match in matches:
        if match.get("status") != "pending":
            continue
        upcoming.append(match)
    log.info("读取到 %d 场待预测比赛", len(upcoming))
    return upcoming


def match_key(match: Dict[str, Any]) -> str:
    """对接主项目 adjustments.json 的键:优先体彩 matchId,否则“主队|客队”。"""
    match_id = match.get("id")
    if match_id:
        return str(match_id)
    return f"{match.get('home')}|{match.get('away')}"


def match_names(match: Dict[str, Any]) -> Optional[Dict[str, str]]:
    """返回用于搜索的主/客队名称(含全称回退)。"""
    home = match.get("home") or match.get("homeFull")
    away = match.get("away") or match.get("awayFull")
    if not home or not away:
        return None
    return {"home": str(home), "away": str(away), "league": str(match.get("league") or match.get("leagueFull") or "")}
