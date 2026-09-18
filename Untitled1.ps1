$TargetDir = "C:\hakaton\hr_exit_engine"

Write-Host "Развертывание проекта в $TargetDir..." -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path "$TargetDir\app" | Out-Null
New-Item -ItemType Directory -Force -Path "$TargetDir\data" | Out-Null

function Write-Utf8File($path, $content) {
    [System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)
}

# 1. requirements.txt
$reqs = @'
fastapi==0.111.0
uvicorn==0.30.1
pydantic==2.7.4
pydantic-settings==2.3.4
streamlit==1.36.0
requests==2.32.3
python-dotenv==1.0.1
pymorphy3==2.0.2
pymorphy3-dicts-ru==2.4.417127.4579844
'@
Write-Utf8File "$TargetDir\requirements.txt" $reqs

# 2. .env.example
$envEx = @'
YANDEX_API_KEY=your_api_key_here
YANDEX_FOLDER_ID=your_folder_id_here
API_URL=https://llm.api.cloud.yandex.net/foundationModels/v1/completion
BACKEND_HOST=backend
BACKEND_PORT=8000
'@
Write-Utf8File "$TargetDir\.env.example" $envEx
Copy-Item -Path "$TargetDir\.env.example" -Destination "$TargetDir\.env" -Force

# 3. app/__init__.py
Write-Utf8File "$TargetDir\app\__init__.py" "# hr_exit_engine"

# 4. app/schemas.py
$schemas = @'
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
'@
Write-Utf8File "$TargetDir\app\schemas.py" $schemas

# 5. app/nlp_processor.py
$nlp = @'
import re
from collections import Counter
import pymorphy3

morph = pymorphy3.MorphAnalyzer()

PAIN_DICTIONARY = {
    "бюрократия_согласование": ["согласование", "тз", "бюрократия", "процесс", "бесконечный", "переделывать"],
    "токсичность_руководство": ["руководитель", "начальник", "токсичный", "микроменеджмент", "крик", "давление"],
    "переработки_нагрузка": ["овертайм", "ночь", "выходной", "дедлайн", "усталость", "нагрузка"],
    "финансы": ["зарплата", "деньги", "премия", "оплата", "бонус", "рынок"]
}

def analyze_raw_text(text: str) -> dict:
    words = re.findall(r"[а-яА-Яa-zA-Z]+", text.lower())
    lemmas = [morph.parse(w)[0].normal_form for w in words]
    counts = Counter(lemmas)

    detected_clusters = {}
    for cluster, keywords in PAIN_DICTIONARY.items():
        score = sum(counts[kw] for kw in keywords if kw in counts)
        if score > 0:
            detected_clusters[cluster] = score

    return {
        "word_count": len(words),
        "cluster_frequencies": detected_clusters
    }
'@
Write-Utf8File "$TargetDir\app\nlp_processor.py" $nlp

# 6. app/yandex_client.py
$yandex = @'
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
'@
Write-Utf8File "$TargetDir\app\yandex_client.py" $yandex

# 7. app/main.py
$mainApp = @'
from fastapi import FastAPI, HTTPException
from app.schemas import AnalyzeRequest, ExitInterviewAnalysis
from app.nlp_processor import analyze_raw_text
from app.yandex_client import call_yandex_gpt

app = FastAPI(title="HR Exit Engine API", version="1.0.0")

@app.get("/health")
def health_check():
    return {"status": "ok"}

@app.post("/analyze", response_model=ExitInterviewAnalysis)
def analyze_interview(request: AnalyzeRequest):
    try:
        nlp_stats = analyze_raw_text(request.text)
        result = call_yandex_gpt(request.text, nlp_stats)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
'@
Write-Utf8File "$TargetDir\app\main.py" $mainApp

# 8. ui.py
$uiCode = @'
import os
import streamlit as st
import requests

st.set_page_config(page_title="HR Exit Engine", layout="wide")

BACKEND_HOST = os.getenv("BACKEND_HOST", "localhost")
BACKEND_PORT = os.getenv("BACKEND_PORT", "8000")
API_ENDPOINT = f"http://{BACKEND_HOST}:{BACKEND_PORT}/analyze"

st.title("🚀 HR Exit Insight Engine (YandexGPT)")
st.caption("Аналитический пайплайн автоматической обработки Exit-интервью")

sample_text = """— Уходишь?
— Да, перехожу к конкурентам. Знаешь, сама работа классная, но убивает вот это: мы полгода обсуждаем ТЗ, а потом переделываем за неделю. Процесс согласования — это ад. Зато очень нравится, как устроен онбординг, ментор помогал реально, не то что в других местах..."""

col_left, col_right = st.columns([1, 1])

with col_left:
    st.subheader("Входной транскрипт")
    uploaded_file = st.file_uploader("Загрузить файл интервью (.txt)", type=["txt"])
    
    if uploaded_file is not None:
        raw_content = uploaded_file.read().decode("utf-8")
    else:
        raw_content = sample_text

    input_text = st.text_area("Текст для обработки:", value=raw_content, height=300)
    process_btn = st.button("Сгенерировать паспорт проблемы", type="primary")

if process_btn and input_text:
    with st.spinner("Обработка через FastAPI + YandexGPT..."):
        try:
            resp = requests.post(API_ENDPOINT, json={"text": input_text}, timeout=60)
            if resp.status_code == 200:
                result = resp.json()
                with col_right:
                    st.subheader("Паспорт проблемы")
                    m1, m2, m3 = st.columns(3)
                    risk_color = "🔴" if result["risk_zone"] == "High" else ("🟡" if result["risk_zone"] == "Medium" else "🟢")
                    m1.metric("Уровень риска", f"{risk_color} {result['risk_zone']}")
                    m2.metric("Причина ухода", result["exit_reason"])
                    m3.metric("Сентимент", result["sentiment_trend"])

                    st.markdown("#### ⚠️ Выявленные боли")
                    for p in result["pain_points"]:
                        st.warning(f"**{p['issue']}** (упоминаний: {p['frequency']})\n\n> «{p['quote']}»\n\n*Эмоциональный маркер:* `{p['implicit_emotion']}`")

                    st.markdown("#### ✅ Что работает хорошо")
                    for bp in result["best_practices"]:
                        st.success(f"**{bp['practice']}**\n\n> «{bp['anchor_quote']}»")

                    st.markdown("#### 💡 Рекомендации")
                    for idx, rec in enumerate(result["improvement_suggestions"], 1):
                        st.markdown(f"**{idx}.** {rec}")

                    with st.expander("Сырой JSON"):
                        st.json(result)
            else:
                st.error(f"Ошибка бэкенда ({resp.status_code}): {resp.text}")
        except Exception as ex:
            st.error(f"Не удалось связаться с бэкендом: {ex}")
'@
Write-Utf8File "$TargetDir\ui.py" $uiCode

# 9. Dockerfile
$dockerfile = @'
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000 8501
'@
Write-Utf8File "$TargetDir\Dockerfile" $dockerfile

# 10. docker-compose.yml
$compose = @'
version: "3.8"

services:
  backend:
    build: .
    container_name: hr_exit_backend
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000
    env_file:
      - .env
    ports:
      - "8000:8000"
    volumes:
      - ./app:/app/app
      - ./data:/app/data
    restart: unless-stopped

  frontend:
    build: .
    container_name: hr_exit_frontend
    command: streamlit run ui.py --server.port 8501 --server.address 0.0.0.0
    env_file:
      - .env
    environment:
      - BACKEND_HOST=backend
      - BACKEND_PORT=8000
    ports:
      - "8501:8501"
    depends_on:
      - backend
    volumes:
      - ./ui.py:/app/ui.py
    restart: unless-stopped
'@
Write-Utf8File "$TargetDir\docker-compose.yml" $compose

# 11. README.md
$readme = @'
# HR Exit Insight Engine (MVP)

Прототип микросервисной системы анализа exit-интервью с использованием YandexGPT, FastAPI и Streamlit.

## Быстрый запуск

1. Заполните учетные данные в `.env`:
   YANDEX_API_KEY=ваш_ключ
   YANDEX_FOLDER_ID=ваш_folder_id

2. Соберите и запустите контейнеры:
   docker compose up --build

3. Доступ:
   - Web UI: http://localhost:8501
   - API Docs: http://localhost:8000/docs
'@
Write-Utf8File "$TargetDir\README.md" $readme

Write-Host "Все файлы успешно сгенерированы в $TargetDir!" -ForegroundColor Green