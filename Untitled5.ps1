$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host "Обновление файлов проекта HR Exit Engine..." -ForegroundColor Cyan

# 1. Обновление app/database.py
$dbPath = "C:\hakaton\hr_exit_engine\app\database.py"
$dbContent = @'
import json
import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).resolve().parent.parent / "data" / "interviews.db"

def init_db():
    """Создание таблицы при старте приложения."""
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS exit_interviews (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                raw_text TEXT NOT NULL,
                exit_reason TEXT,
                risk_zone TEXT,
                sentiment_trend TEXT,
                parsed_json TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)

def save_interview(raw_text: str, result_dict: dict) -> int:
    """Сохранение сырого текста и разобранного JSON."""
    with sqlite3.connect(DB_PATH) as conn:
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO exit_interviews (raw_text, exit_reason, risk_zone, sentiment_trend, parsed_json)
            VALUES (?, ?, ?, ?, ?)
        """, (
            raw_text,
            result_dict.get("exit_reason"),
            result_dict.get("risk_zone"),
            result_dict.get("sentiment_trend"),
            json.dumps(result_dict, ensure_ascii=False)
        ))
        conn.commit()
        return cursor.lastrowid

def get_all_interviews(limit: int = 50):
    """Получение списка последних сохраненных интервью."""
    init_db()
    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        rows = cursor.execute("""
            SELECT id, raw_text, exit_reason, risk_zone, sentiment_trend, parsed_json, created_at
            FROM exit_interviews
            ORDER BY id DESC
            LIMIT ?
        """, (limit,)).fetchall()
        
        result = []
        for r in rows:
            result.append({
                "id": r["id"],
                "raw_text": r["raw_text"],
                "exit_reason": r["exit_reason"],
                "risk_zone": r["risk_zone"],
                "sentiment_trend": r["sentiment_trend"],
                "parsed_json": json.loads(r["parsed_json"]),
                "created_at": r["created_at"]
            })
        return result
'@
[System.IO.File]::WriteAllText($dbPath, $dbContent, $utf8NoBom)
Write-Host " [OK] database.py обновлен" -ForegroundColor Green

# 2. Обновление app/main.py
$mainPath = "C:\hakaton\hr_exit_engine\app\main.py"
$mainContent = @'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from app.schemas import AnalyzeRequest, ExitInterviewAnalysis
from app.nlp_processor import analyze_raw_text
from app.yandex_client import call_yandex_gpt
from app.database import init_db, save_interview, get_all_interviews

app = FastAPI(title="HR Exit Engine API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def on_startup():
    init_db()

@app.get("/health")
def health_check():
    return {"status": "ok"}

@app.get("/history")
def get_history():
    try:
        return get_all_interviews()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/analyze", response_model=ExitInterviewAnalysis)
def analyze_interview(request: AnalyzeRequest):
    try:
        nlp_stats = analyze_raw_text(request.text)
        result = call_yandex_gpt(request.text, nlp_stats)
        save_interview(raw_text=request.text, result_dict=result.model_dump())
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
'@
[System.IO.File]::WriteAllText($mainPath, $mainContent, $utf8NoBom)
Write-Host " [OK] main.py обновлен" -ForegroundColor Green

# 3. Обновление hr_exit_web/src/App.jsx
$appJsxPath = "C:\hakaton\hr_exit_web\src\App.jsx"
$appJsxContent = @'
import React, { useState, useEffect } from "react";
import { 
  AlertCircle, 
  CheckCircle2, 
  TrendingUp, 
  Sparkles, 
  Upload, 
  Loader2, 
  History, 
  PlusCircle, 
  FileText,
  Download
} from "lucide-react";

export default function App() {
  const defaultText = `HR: Как в целом оцениваешь время, проведенное в команде, и почему принял оффер?
Сотрудник: У меня остались только теплые впечатления. Компания дала отличный старт, онбординг был идеальным, тимлид всегда поддерживал и делился опытом. Но за два года я уперся в карьерный потолок внутри своего грейда. Мне предложили позицию лида направления у конкурентов с зарплатой на 40% выше рынка. Мы обсуждали пересмотр грейда и компенсации на перформанс-ревью, но бюджет зафиксирован до конца года, а у меня сейчас ипотека и другие финансовые планы. Если бы была возможность внутреннего перехода или индексации, я бы с удовольствием остался, потому что коллектив и атмосфера здесь замечательные.`;

  const [text, setText] = useState(defaultText);
  const [loading, setLoading] = useState(false);
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [history, setHistory] = useState([]);
  const [selectedId, setSelectedId] = useState(null);

  const fetchHistory = async () => {
    try {
      const res = await fetch("http://localhost:8000/history");
      if (res.ok) {
        const items = await res.json();
        setHistory(items);
      }
    } catch (err) {
      console.error("Ошибка загрузки истории:", err);
    }
  };

  useEffect(() => {
    fetchHistory();
  }, []);

  const handleFileUpload = (e) => {
    const file = e.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (event) => setText(event.target.result);
      reader.readAsText(file);
    }
  };

  const handleAnalyze = async () => {
    if (!text.trim()) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetch("http://localhost:8000/analyze", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text })
      });
      if (!res.ok) throw new Error(`Ошибка сервера: ${res.statusText}`);
      const json = await res.json();
      setData(json);
      setSelectedId(null);
      fetchHistory();
    } catch (err) {
      setError(err.message || "Не удалось соединиться с бэкендом");
    } finally {
      setLoading(false);
    }
  };

  const handleSelectHistoryItem = (item) => {
    setSelectedId(item.id);
    setText(item.raw_text);
    setData(item.parsed_json);
  };

  const handleNewAnalysis = () => {
    setSelectedId(null);
    setText("");
    setData(null);
    setError(null);
  };

  const handleDownloadJson = () => {
    if (!data) return;
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `exit_passport_${selectedId || "latest"}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const getRiskBadge = (zone) => {
    switch (zone) {
      case "High":
        return <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-rose-100 text-rose-700 border border-rose-200">High</span>;
      case "Medium":
        return <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-amber-100 text-amber-700 border border-amber-200">Medium</span>;
      default:
        return <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-700 border border-emerald-200">Low</span>;
    }
  };

  return (
    <div className="flex h-screen bg-slate-50 text-slate-900 overflow-hidden">
      <aside className="w-80 bg-white border-r border-slate-200 flex flex-col shrink-0">
        <div className="p-4 border-b border-slate-200 flex items-center justify-between">
          <div className="flex items-center space-x-2.5">
            <div className="w-8 h-8 bg-indigo-600 rounded-lg flex items-center justify-center text-white font-bold text-sm">
              HR
            </div>
            <span className="font-bold text-slate-800 text-sm">Exit Intelligence</span>
          </div>
          <button
            onClick={handleNewAnalysis}
            className="p-1.5 text-slate-500 hover:text-indigo-600 hover:bg-slate-100 rounded-lg transition"
            title="Новый анализ"
          >
            <PlusCircle className="w-5 h-5" />
          </button>
        </div>

        <div className="px-4 py-3 bg-slate-50/50 border-b border-slate-200 flex items-center text-xs font-semibold text-slate-500 uppercase tracking-wider">
          <History className="w-3.5 h-3.5 mr-1.5" />
          <span>История интервью ({history.length})</span>
        </div>

        <div className="flex-1 overflow-y-auto p-2 space-y-1">
          {history.length === 0 ? (
            <div className="text-center py-8 text-xs text-slate-400">
              История пока пуста
            </div>
          ) : (
            history.map((item) => (
              <button
                key={item.id}
                onClick={() => handleSelectHistoryItem(item)}
                className={`w-full text-left p-3 rounded-xl transition border text-xs flex flex-col space-y-1.5 ${
                  selectedId === item.id 
                    ? "bg-indigo-50 border-indigo-200 text-indigo-900 shadow-sm" 
                    : "border-transparent hover:bg-slate-100 text-slate-700"
                }`}
              >
                <div className="flex items-center justify-between w-full">
                  <span className="font-semibold truncate max-w-[150px]">
                    {item.exit_reason || "Причина не указана"}
                  </span>
                  {getRiskBadge(item.risk_zone)}
                </div>
                <p className="text-[11px] text-slate-500 line-clamp-2 leading-relaxed">
                  {item.raw_text}
                </p>
                <div className="text-[10px] text-slate-400 pt-0.5">
                  {item.created_at ? new Date(item.created_at).toLocaleString("ru-RU", { dateStyle: "short", timeStyle: "short" }) : `#${item.id}`}
                </div>
              </button>
            ))
          )}
        </div>
      </aside>

      <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
        <header className="bg-white border-b border-slate-200 px-8 py-3.5 flex items-center justify-between sticky top-0 z-10">
          <div>
            <h1 className="text-base font-bold text-slate-900">
              {selectedId ? `Просмотр отчета #${selectedId}` : "Новый анализ Exit Interview"}
            </h1>
            <p className="text-xs text-slate-500">Автоматический аудит причин ухода на базе YandexGPT</p>
          </div>
          {data && (
            <button
              onClick={handleDownloadJson}
              className="flex items-center space-x-1.5 text-xs font-medium text-slate-700 bg-slate-100 hover:bg-slate-200 px-3 py-1.5 rounded-lg transition"
            >
              <Download className="w-3.5 h-3.5" />
              <span>Экспорт JSON</span>
            </button>
          )}
        </header>

        <main className="p-8 max-w-6xl w-full mx-auto grid grid-cols-1 lg:grid-cols-12 gap-8">
          <section className="lg:col-span-5 flex flex-col space-y-4">
            <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm flex-1 flex flex-col">
              <div className="flex items-center justify-between mb-3">
                <h2 className="font-semibold text-slate-800 text-xs tracking-wide uppercase">Сырой диалог</h2>
                <label className="cursor-pointer text-xs text-indigo-600 hover:text-indigo-800 font-medium flex items-center space-x-1">
                  <Upload className="w-3.5 h-3.5" />
                  <span>Загрузить .txt</span>
                  <input type="file" accept=".txt" onChange={handleFileUpload} className="hidden" />
                </label>
              </div>
              <textarea
                className="w-full flex-1 min-h-[360px] p-3.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:outline-none resize-none leading-relaxed"
                value={text}
                onChange={(e) => setText(e.target.value)}
                placeholder="Вставьте диалог exit-интервью..."
              />
              {error && (
                <div className="mt-3 p-3 bg-rose-50 text-rose-600 text-xs rounded-lg border border-rose-200">
                  {error}
                </div>
              )}
              <button
                onClick={handleAnalyze}
                disabled={loading || !text.trim()}
                className="mt-4 w-full bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white font-medium py-2.5 rounded-xl flex items-center justify-center space-x-2 transition text-sm shadow-sm"
              >
                {loading ? (
                  <>
                    <Loader2 className="w-4 h-4 animate-spin" />
                    <span>Анализ YandexGPT...</span>
                  </>
                ) : (
                  <>
                    <Sparkles className="w-4 h-4" />
                    <span>Сгенерировать паспорт</span>
                  </>
                )}
              </button>
            </div>
          </section>

          <section className="lg:col-span-7">
            {data ? (
              <div className="space-y-6">
                <div className="grid grid-cols-3 gap-4">
                  <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
                    <div className="text-xs text-slate-500 mb-1">Зона риска</div>
                    {getRiskBadge(data.risk_zone)}
                  </div>
                  <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm col-span-2">
                    <div className="text-xs text-slate-500 mb-1">Истинная причина ухода</div>
                    <div className="font-semibold text-slate-800 text-sm truncate capitalize">{data.exit_reason}</div>
                  </div>
                </div>

                <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm flex items-start space-x-3">
                  <TrendingUp className="w-4 h-4 text-indigo-500 mt-0.5 shrink-0" />
                  <div>
                    <div className="text-xs font-semibold text-slate-700 mb-0.5">Динамика эмоционального тона</div>
                    <div className="text-xs text-slate-600 leading-relaxed">{data.sentiment_trend}</div>
                  </div>
                </div>

                <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
                  <h3 className="text-xs font-semibold uppercase tracking-wide text-rose-600 mb-3 flex items-center space-x-1.5">
                    <AlertCircle className="w-4 h-4" />
                    <span>Системные проблемы ({data.pain_points.length})</span>
                  </h3>
                  <div className="space-y-3">
                    {data.pain_points.map((p, idx) => (
                      <div key={idx} className="p-3.5 bg-rose-50/50 rounded-xl border border-rose-100 text-xs">
                        <div className="flex justify-between items-start mb-1">
                          <span className="font-semibold text-slate-800">{p.issue}</span>
                          <span className="bg-white text-rose-600 px-2 py-0.5 rounded border border-rose-200 font-mono">
                            частота: {p.frequency}
                          </span>
                        </div>
                        <blockquote className="text-slate-600 italic border-l-2 border-rose-300 pl-2 my-1.5">
                          «{p.quote}»
                        </blockquote>
                        <div className="text-slate-500">
                          <span className="font-medium">Эмоция:</span> {p.implicit_emotion}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>

                <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
                  <h3 className="text-xs font-semibold uppercase tracking-wide text-emerald-600 mb-3 flex items-center space-x-1.5">
                    <CheckCircle2 className="w-4 h-4" />
                    <span>Что работает хорошо</span>
                  </h3>
                  <div className="space-y-2.5">
                    {data.best_practices.map((bp, idx) => (
                      <div key={idx} className="p-3.5 bg-emerald-50/50 rounded-xl border border-emerald-100 text-xs">
                        <div className="font-semibold text-slate-800 mb-1">{bp.practice}</div>
                        <blockquote className="text-slate-600 italic border-l-2 border-emerald-300 pl-2">
                          «{bp.anchor_quote}»
                        </blockquote>
                      </div>
                    ))}
                  </div>
                </div>

                <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
                  <h3 className="text-xs font-semibold uppercase tracking-wide text-indigo-600 mb-3 flex items-center space-x-1.5">
                    <Sparkles className="w-4 h-4" />
                    <span>Рекомендации для топ-менеджмента</span>
                  </h3>
                  <ol className="space-y-2">
                    {data.improvement_suggestions.map((rec, idx) => (
                      <li key={idx} className="text-xs text-slate-700 flex items-start space-x-2.5">
                        <span className="shrink-0 w-5 h-5 rounded-full bg-indigo-50 text-indigo-600 font-bold flex items-center justify-center mt-0.5">
                          {idx + 1}
                        </span>
                        <span className="leading-relaxed">{rec}</span>
                      </li>
                    ))}
                  </ol>
                </div>
              </div>
            ) : (
              <div className="h-full min-h-[400px] border-2 border-dashed border-slate-200 rounded-2xl flex flex-col items-center justify-center p-8 text-center text-slate-400">
                <FileText className="w-10 h-10 mb-2 stroke-1 text-slate-300" />
                <p className="text-xs font-medium text-slate-500">Паспорт проблемы не выбран</p>
                <p className="text-[11px] text-slate-400 mt-1">Выберите запись из истории слева или запустите новый анализ</p>
              </div>
            )}
          </section>
        </main>
      </div>
    </div>
  );
}
'@
[System.IO.File]::WriteAllText($appJsxPath, $appJsxContent, $utf8NoBom)
Write-Host " [OK] App.jsx обновлен" -ForegroundColor Green

Write-Host "`nВсе обновления успешно применены!" -ForegroundColor Cyan