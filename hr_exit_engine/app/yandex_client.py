import os
import json
import re
import requests
from dotenv import load_dotenv
from app.schemas import ExitInterviewAnalysis

load_dotenv()

YANDEX_API_KEY = os.getenv("YANDEX_API_KEY")
YANDEX_FOLDER_ID = os.getenv("YANDEX_FOLDER_ID")
API_URL = os.getenv("API_URL", "https://llm.api.cloud.yandex.net/foundationModels/v1/completion")

SYSTEM_PROMPT = """Ты — ведущий эксперт по HR-аналитике и организационной трансформации. 
Твоя задача: объективно проанализировать транскрипт Exit Interview и выдать СТРОГИЙ JSON без лишнего текста и markdown-оберток.

Правила:
1. Разделяй то, что сотрудник говорит формально, и его эмоциональные маркеры.
2. Цитаты должны быть строго дословными выдержками из текста.
3. frequency в pain_points должен соответствовать реальной частоте упоминания боли в контексте.
4. improvement_suggestions должны быть конкретными действиями для менеджмента (не менее 3 пунктов), а не банальностями.

Схема JSON-ответа:
{
  "exit_reason": "строка",
  "pain_points": [{"issue": "...", "frequency": 1, "quote": "...", "implicit_emotion": "..."}],
  "best_practices": [{"practice": "...", "anchor_quote": "..."}],
  "risk_zone": "High" | "Medium" | "Low",
  "sentiment_trend": "строка с описанием изменения тона",
  "improvement_suggestions": ["пункт 1", "пункт 2", "пункт 3"]
}"""

def call_yandex_gpt(transcript: str, frequency_hints: dict) -> ExitInterviewAnalysis:
    if not YANDEX_API_KEY or not YANDEX_FOLDER_ID:
        raise ValueError("YANDEX_API_KEY или YANDEX_FOLDER_ID не заданы в .env")

    prompt_text = f"""Контекст частотного анализа лемм в тексте: {json.dumps(frequency_hints, ensure_ascii=False)}

Транскрипт интервью:
\"\"\"{transcript}\"\"\"

Сгенерируй JSON строго по схеме:"""

    payload = {
        "modelUri": f"gpt://{YANDEX_FOLDER_ID}/yandexgpt/latest",
        "completionOptions": {
            "stream": False,
            "temperature": 0.1,
            "maxTokens": 2000
        },
        "messages": [
            {"role": "system", "text": SYSTEM_PROMPT},
            {"role": "user", "text": prompt_text}
        ]
    }

    headers = {
        "Authorization": f"Api-Key {YANDEX_API_KEY}",
        "x-folder-id": YANDEX_FOLDER_ID,
        "Content-Type": "application/json"
    }

    response = requests.post(API_URL, headers=headers, json=payload, timeout=60)
    response.raise_for_status()
    raw_result = response.json()["result"]["alternatives"][0]["message"]["text"]

    cleaned_json = raw_result.strip()
    if cleaned_json.startswith("```"):
        cleaned_json = re.sub(r"^```[a-zA-Z]*\n?", "", cleaned_json)
        cleaned_json = re.sub(r"```$", "", cleaned_json).strip()

    parsed_dict = json.loads(cleaned_json)
    return ExitInterviewAnalysis(**parsed_dict)