import logging
import re
import time
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional
from urllib.parse import quote

from config import settings

try:
    import requests
except ImportError:  # pragma: no cover
    requests = None

log = logging.getLogger("intel.news")

GOOGLE_NEWS_RSS = "https://news.google.com/rss/search"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"

# 与主项目无关的关键词黑名单,避免垃圾新闻
BLOCKED_TITLE = re.compile(
    r"开奖|中奖|赔率|投注|预测|玩法|串关|竞彩|体彩|彩票|任选|胜负彩", re.I
)

_TITLE_RE = re.compile(r"<title>(.*?)</title>")
_LINK_RE = re.compile(r"<link>(.*?)</link>")
_DATE_RE = re.compile(r"<pubDate>(.*?)</pubDate>")
_DESC_RE = re.compile(r"<description>(.*?)</description>")


@dataclass
class NewsItem:
    title: str
    link: str
    published: str = ""
    snippet: str = ""
    source_name: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return {
            "title": self.title,
            "link": self.link,
            "published": self.published,
            "snippet": self.snippet,
            "source": self.source_name,
        }


def _strip_tags(text: str) -> str:
    return re.sub(r"<[^>]+>", "", text or "").strip()


def _decode_xml(text: str) -> str:
    import html as _html
    return _html.unescape(text)


def _parse_rss(xml_text: str) -> List[NewsItem]:
    items: List[NewsItem] = []
    entries = xml_text.split("<item>")
    for entry in entries[1:]:
        title_match = _TITLE_RE.search(entry)
        if not title_match:
            continue
        title = _decode_xml(_strip_tags(title_match.group(1)))
        if BLOCKED_TITLE.search(title):
            continue
        link_match = _LINK_RE.search(entry)
        date_match = _DATE_RE.search(entry)
        desc_match = _DESC_RE.search(entry)
        snippet = _decode_xml(_strip_tags(desc_match.group(1))) if desc_match else ""
        items.append(
            NewsItem(
                title=title,
                link=_decode_xml(link_match.group(1)).strip() if link_match else "",
                published=_decode_xml(date_match.group(1)).strip() if date_match else "",
                snippet=snippet,
            )
        )
    return items


def _fetch_rss(query: str, language: str = None, count: int = 8) -> List[NewsItem]:
    if requests is None:
        log.warning("缺少 requests 依赖,跳过新闻抓取")
        return []
    params = {
        "q": query,
        "hl": language or settings.NEWS_LANGUAGE,
        "gl": language or settings.NEWS_LANGUAGE,
        "ceid": f"{language or settings.NEWS_LANGUAGE}:{language or settings.NEWS_LANGUAGE}",
    }
    url = GOOGLE_NEWS_RSS + "?" + "&".join(f"{k}={quote(str(v))}" for k, v in params.items())
    last_error = None
    for attempt in range(3):
        try:
            resp = requests.get(
                url,
                headers={"user-agent": UA, "accept": "application/rss+xml, application/xml"},
                timeout=settings.NEWS_TIMEOUT,
            )
            resp.raise_for_status()
            items = _parse_rss(resp.text)
            log.info("查询 [%s] -> %d 条", query, len(items))
            return items[:count]
        except Exception as error:
            last_error = error
            log.warning("新闻抓取失败(第 %d 次)[%s]: %s", attempt + 1, query, error)
            if attempt < 2:
                time.sleep(1.5 * (attempt + 1))
    log.warning("新闻抓取重试后仍失败 [%s]: %s", query, last_error)
    return []


def _search_terms(names: Dict[str, str]) -> List[str]:
    """构造搜索词:球队名 + 伤停/阵容等关键词,主客各一组。"""
    home = names.get("home", "")
    away = names.get("away", "")
    return [
        f'"{home}" 伤停 OR 伤病 OR 缺阵',
        f'"{away}" 伤停 OR 伤病 OR 缺阵',
        f'"{home}" 阵容 OR 首发 OR 轮换',
        f'"{away}" 阵容 OR 首发 OR 轮换',
        f'"{home}" OR "{away}" coach news',
    ]


def fetch_news_for_match(match: Dict[str, Any], names: Dict[str, str]) -> List[NewsItem]:
    """抓取一场比赛相关的新闻,按主/客队分类。"""
    all_items: List[NewsItem] = []
    seen = set()
    for term in _search_terms(names):
        for item in _fetch_rss(term, count=4):
            dedup = f"{item.title}|{item.link}"
            if dedup in seen:
                continue
            seen.add(dedup)
            # 判断命中哪一方
            home = names.get("home", "")
            away = names.get("away", "")
            if home and home in item.title:
                item.source_name = "home"
            elif away and away in item.title:
                item.source_name = "away"
            else:
                item.source_name = "general"
            all_items.append(item)
    return all_items[: settings.NEWS_PER_MATCH]
