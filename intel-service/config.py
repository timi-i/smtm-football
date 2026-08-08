import os
from pathlib import Path

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parent / ".env")
except ImportError:
    pass

BASE_DIR = Path(__file__).resolve().parent

def _bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}

class Settings:
    # LLM (OpenAI-compatible)
    LLM_API_KEY: str = os.getenv("LLM_API_KEY", "").strip()
    LLM_BASE_URL: str = os.getenv("LLM_BASE_URL", "https://api.openai.com/v1").strip()
    LLM_MODEL: str = os.getenv("LLM_MODEL", "gpt-4o-mini").strip()
    LLM_TIMEOUT: int = int(os.getenv("LLM_TIMEOUT", "60"))

    # 主项目数据目录(读取 predictions.json、写入 adjustments.json)
    PREDICTIONS_PATH: Path = Path(os.getenv("PREDICTIONS_PATH", str(BASE_DIR.parent / "daily-football-predictor" / "data" / "predictions.json")))
    ADJUSTMENTS_PATH: Path = Path(os.getenv("ADJUSTMENTS_PATH", str(BASE_DIR.parent / "daily-football-predictor" / "data" / "adjustments.json")))

    # 新闻抓取
    NEWS_LANGUAGE: str = os.getenv("NEWS_LANGUAGE", "zh-CN").strip()
    NEWS_PER_MATCH: int = int(os.getenv("NEWS_PER_MATCH", "8"))
    NEWS_MAX_MATCHES: int = int(os.getenv("NEWS_MAX_MATCHES", "20"))
    NEWS_TIMEOUT: int = int(os.getenv("NEWS_TIMEOUT", "15"))

    # 开关
    ENABLE_NEWS: bool = _bool("ENABLE_NEWS", True)
    ENABLE_LLM: bool = _bool("ENABLE_LLM", True)
    WRITE_OUTPUT: bool = _bool("WRITE_OUTPUT", True)
    VERBOSE: bool = _bool("VERBOSE", False)

    @property
    def llm_configured(self) -> bool:
        return bool(self.LLM_API_KEY)

settings = Settings()
