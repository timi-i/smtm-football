#!/usr/bin/env python3
"""打印当前生效配置,用于排查部署问题。"""
from config import settings

print("LLM_API_KEY    :", "已配置" if settings.llm_configured else "未配置(LLM 清洗将降级为原文占位)")
print("LLM_BASE_URL   :", settings.LLM_BASE_URL)
print("LLM_MODEL      :", settings.LLM_MODEL)
print("PREDICTIONS_PATH:", settings.PREDICTIONS_PATH)
print("ADJUSTMENTS_PATH:", settings.ADJUSTMENTS_PATH)
print("NEWS_LANGUAGE  :", settings.NEWS_LANGUAGE)
print("NEWS_PER_MATCH :", settings.NEWS_PER_MATCH)
print("NEWS_MAX_MATCHES:", settings.NEWS_MAX_MATCHES)
print("ENABLE_NEWS    :", settings.ENABLE_NEWS)
print("ENABLE_LLM     :", settings.ENABLE_LLM)
print("WRITE_OUTPUT   :", settings.WRITE_OUTPUT)
print("VERBOSE        :", settings.VERBOSE)
