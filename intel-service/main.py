import argparse
import logging
import sys
from typing import Dict, List

from config import settings

from intel import __version__
from intel.loader import load_predictions, match_key, match_names
from intel.sources.news import fetch_news_for_match

def setup_logging(verbose: bool) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%H:%M:%S",
    )

def run() -> int:
    if settings.VERBOSE:
        setup_logging(True)
    else:
        setup_logging(False)
    log = logging.getLogger("intel.main")

    matches = load_predictions(settings.PREDICTIONS_PATH)
    if not matches:
        log.error("没有可处理的比赛。请确认 PREDICTIONS_PATH 指向主项目的 data/predictions.json")
        return 1

    matches = matches[: settings.NEWS_MAX_MATCHES]
    log.info("处理 %d 场比赛", len(matches))

    if not settings.llm_configured and settings.ENABLE_LLM:
        log.warning("未配置 LLM_API_KEY,LLM 清洗将被跳过(仅保留抓取结果,不生成信号)")

    all_entries: Dict[str, dict] = {}
    for match in matches:
        names = match_names(match)
        if not names:
            log.warning("比赛 %s 缺少队名,跳过", match.get("id"))
            continue
        news = []
        if settings.ENABLE_NEWS:
            news = fetch_news_for_match(match, names)
            log.info("%s vs %s: 抓取到 %d 条新闻", names["home"], names["away"], len(news))
        signals = []
        if settings.ENABLE_LLM and settings.llm_configured and news:
            from intel.cleaner import clean_news_with_llm
            signals = clean_news_with_llm(match, [item.to_dict() for item in news])
        else:
            # 未配置 LLM 时,输出原始新闻作为占位信号(不带进球修正)
            for item in news:
                signals.append({
                    "type": "news",
                    "label": item.title,
                    "source": item.link or item.source_name,
                    "confidence": 0.3,
                    "homeGoalsDelta": 0,
                    "awayGoalsDelta": 0,
                })
        if signals:
            all_entries[match_key(match)] = signals

    if settings.WRITE_OUTPUT:
        from intel.output import build_match_entry, write_adjustments
        entries = {key: build_match_entry(signals) for key, signals in all_entries.items()}
        path = write_adjustments(entries, settings.ADJUSTMENTS_PATH)
        log.info("完成。下次运行主项目 npm run update 即可读取这些情报。")
    else:
        # 打印 JSON
        import json as _json
        print(_json.dumps(all_entries, ensure_ascii=False, indent=2))
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(description="足球赛前情报服务")
    parser.add_argument("--verbose", action="store_true", help="详细日志")
    args = parser.parse_args()
    if args.verbose:
        settings.VERBOSE = True
    sys.exit(run())


if __name__ == "__main__":
    main()
