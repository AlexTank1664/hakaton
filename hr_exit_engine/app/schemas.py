from enum import Enum
from typing import List
from pydantic import BaseModel, Field

class RiskZone(str, Enum):
    LOW = "Low"
    MEDIUM = "Medium"
    HIGH = "High"

class PainPoint(BaseModel):
    issue: str = Field(description="Суть системной проблемы")
    frequency: int = Field(description="Количество упоминаний в тексте")
    quote: str = Field(description="Точная цитата из текста")
    implicit_emotion: str = Field(description="Скрытая эмоция: раздражение, апатия, тревога и т.д.")

class BestPractice(BaseModel):
    practice: str = Field(description="Что работает хорошо")
    anchor_quote: str = Field(description="Цитата-якорь")

class ExitInterviewAnalysis(BaseModel):
    exit_reason: str = Field(description="Истинная причина ухода (деньги, карьера, микроклимат, нереализованность)")
    pain_points: List[PainPoint]
    best_practices: List[BestPractice]
    risk_zone: RiskZone
    sentiment_trend: str = Field(description="Динамика тональности от начала к концу диалога")
    improvement_suggestions: List[str] = Field(min_length=3, description="Не менее 3 реалистичных гипотез по решению проблемы")

class AnalyzeRequest(BaseModel):
    text: str = Field(..., min_length=10, description="Транскрипт интервью")