$WebDir = "C:\hakaton\hr_exit_web"
Write-Host "Создание React-приложения в $WebDir..." -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path "$WebDir\src" | Out-Null

function Write-Utf8($path,$content) {
    [System.IO.File]::WriteAllText($path,$content, [System.Text.Encoding]::UTF8)
}

# 1. package.json
$pkgJson = @'
{
  "name": "hr-exit-web",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "lucide-react": "^0.395.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.0",
    "vite": "^5.2.11"
  }
}
'@
Write-Utf8 "$WebDir\package.json" $pkgJson

# 2. vite.config.js
$viteConfig = @'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173
  }
});
'@
Write-Utf8 "$WebDir\vite.config.js" $viteConfig

# 3. index.html с подключением Tailwind CSS
$indexHtml = @'
<!DOCTYPE html>
<html lang="ru">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>HR Exit Intelligence</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
      body { font-family: 'Inter', sans-serif; }
    </style>
  </head>
  <body class="bg-slate-50 text-slate-900">
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
'@
Write-Utf8 "$WebDir\index.html" $indexHtml

# 4. src/main.jsx
$mainJsx = @'
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App.jsx";

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
'@
Write-Utf8 "$WebDir\src\main.jsx" $mainJsx

# 5. src/App.jsx (Интерфейс дашборда)
$appJsx = @'
import React, { useState } from "react";
import { AlertCircle, CheckCircle2, TrendingUp, Sparkles, Upload, Loader2 } from "lucide-react";

export default function App() {
  const defaultText = `HR: Как в целом оцениваешь время, проведенное в команде, и почему принял оффер?
Сотрудник: У меня остались только теплые впечатления. Компания дала отличный старт, онбординг был идеальным, тимлид всегда поддерживал и делился опытом. Но за два года я уперся в карьерный потолок внутри своего грейда. Мне предложили позицию лида направления у конкурентов с зарплатой на 40% выше рынка. Мы обсуждали пересмотр грейда и компенсации на перформанс-ревью, но бюджет зафиксирован до конца года, а у меня сейчас ипотека и другие финансовые планы. Если бы была возможность внутреннего перехода или индексации, я бы с удовольствием остался, потому что коллектив и атмосфера здесь замечательные.`;

  const [text, setText] = useState(defaultText);
  const [loading, setLoading] = useState(false);
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);

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
      if (!res.ok) {
        throw new Error(`Ошибка сервера: ${res.statusText}`);
      }
      const json = await res.json();
      setData(json);
    } catch (err) {
      setError(err.message || "Не удалось соединиться с бэкендом");
    } finally {
      setLoading(false);
    }
  };

  const getRiskBadge = (zone) => {
    switch (zone) {
      case "High":
        return <span className="px-3 py-1 rounded-full text-xs font-semibold bg-rose-100 text-rose-700 border border-rose-200">Высокий риск (High)</span>;
      case "Medium":
        return <span className="px-3 py-1 rounded-full text-xs font-semibold bg-amber-100 text-amber-700 border border-amber-200">Средний риск (Medium)</span>;
      default:
        return <span className="px-3 py-1 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-700 border border-emerald-200">Низкий риск (Low)</span>;
    }
  };

  return (
    <div className="min-h-screen flex flex-col">
      <header className="bg-white border-b border-slate-200 px-8 py-4 flex items-center justify-between sticky top-0 z-10">
        <div className="flex items-center space-x-3">
          <div className="w-9 h-9 bg-indigo-600 rounded-lg flex items-center justify-center text-white font-bold text-lg shadow-sm">
            HR
          </div>
          <div>
            <h1 className="text-lg font-bold text-slate-900 leading-tight">Exit Interview Insight Engine</h1>
            <p className="text-xs text-slate-500">Автоматический аудит и структуризация увольнений</p>
          </div>
        </div>
        <div className="text-xs text-slate-500 bg-slate-100 px-3 py-1.5 rounded-md font-mono">
          FastAPI • YandexGPT • React
        </div>
      </header>

      <main className="flex-1 p-8 max-w-7xl mx-auto w-full grid grid-cols-1 lg:grid-cols-12 gap-8">
        {/* Левая колонка: Ввод текста */}
        <section className="lg:col-span-5 flex flex-col space-y-4">
          <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm flex-1 flex flex-col">
            <div className="flex items-center justify-between mb-4">
              <h2 className="font-semibold text-slate-800 text-sm tracking-wide uppercase">Сырой транскрипт</h2>
              <label className="cursor-pointer text-xs text-indigo-600 hover:text-indigo-800 font-medium flex items-center space-x-1">
                <Upload className="w-3.5 h-3.5" />
                <span>Загрузить .txt</span>
                <input type="file" accept=".txt" onChange={handleFileUpload} className="hidden" />
              </label>
            </div>
            <textarea
              className="w-full flex-1 min-h-[350px] p-4 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:outline-none resize-none leading-relaxed"
              value={text}
              onChange={(e) => setText(e.target.value)}
              placeholder="Вставьте диалог exit-интервью..."
            />
            {error && (
              <div className="mt-4 p-3 bg-rose-50 text-rose-600 text-xs rounded-lg border border-rose-200">
                {error}
              </div>
            )}
            <button
              onClick={handleAnalyze}
              disabled={loading || !text.trim()}
              className="mt-4 w-full bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white font-medium py-3 rounded-xl flex items-center justify-center space-x-2 transition shadow-sm"
            >
              {loading ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  <span>Анализ текста в YandexGPT...</span>
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

        {/* Правая колонка: Результат */}
        <section className="lg:col-span-7">
          {data ? (
            <div className="space-y-6">
              {/* Статусные карточки */}
              <div className="grid grid-cols-3 gap-4">
                <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
                  <div className="text-xs text-slate-500 mb-1">Зона риска</div>
                  {getRiskBadge(data.risk_zone)}
                </div>
                <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm col-span-2">
                  <div className="text-xs text-slate-500 mb-1">Истинная причина ухода</div>
                  <div className="font-semibold text-slate-800 truncate capitalize">{data.exit_reason}</div>
                </div>
              </div>

              {/* Динамика сентимента */}
              <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm flex items-start space-x-3">
                <TrendingUp className="w-5 h-5 text-indigo-500 mt-0.5 shrink-0" />
                <div>
                  <div className="text-xs font-semibold text-slate-700 mb-0.5">Динамика эмоционального тона</div>
                  <div className="text-xs text-slate-600 leading-relaxed">{data.sentiment_trend}</div>
                </div>
              </div>

              {/* Боли */}
              <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
                <h3 className="text-sm font-semibold uppercase tracking-wide text-rose-600 mb-4 flex items-center space-x-2">
                  <AlertCircle className="w-4 h-4" />
                  <span>Системные проблемы ({data.pain_points.length})</span>
                </h3>
                <div className="space-y-4">
                  {data.pain_points.map((p, idx) => (
                    <div key={idx} className="p-4 bg-rose-50/50 rounded-xl border border-rose-100 text-sm">
                      <div className="flex justify-between items-start mb-1">
                        <span className="font-semibold text-slate-800">{p.issue}</span>
                        <span className="text-xs bg-white text-rose-600 px-2 py-0.5 rounded border border-rose-200 font-mono">
                          частота: {p.frequency}
                        </span>
                      </div>
                      <blockquote className="text-xs text-slate-600 italic mb-2 border-l-2 border-rose-300 pl-2 my-2">
                        «{p.quote}»
                      </blockquote>
                      <div className="text-xs text-slate-500">
                        <span className="font-medium">Эмоция:</span> {p.implicit_emotion}
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Что работает хорошо */}
              <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
                <h3 className="text-sm font-semibold uppercase tracking-wide text-emerald-600 mb-4 flex items-center space-x-2">
                  <CheckCircle2 className="w-4 h-4" />
                  <span>Что работает хорошо</span>
                </h3>
                <div className="space-y-3">
                  {data.best_practices.map((bp, idx) => (
                    <div key={idx} className="p-4 bg-emerald-50/50 rounded-xl border border-emerald-100 text-sm">
                      <div className="font-semibold text-slate-800 mb-1">{bp.practice}</div>
                      <blockquote className="text-xs text-slate-600 italic border-l-2 border-emerald-300 pl-2">
                        «{bp.anchor_quote}»
                      </blockquote>
                    </div>
                  ))}
                </div>
              </div>

              {/* Управленческие рекомендации */}
              <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
                <h3 className="text-sm font-semibold uppercase tracking-wide text-indigo-600 mb-4 flex items-center space-x-2">
                  <Sparkles className="w-4 h-4" />
                  <span>Рекомендации для топ-менеджмента</span>
                </h3>
                <ol className="space-y-2.5">
                  {data.improvement_suggestions.map((rec, idx) => (
                    <li key={idx} className="text-sm text-slate-700 flex items-start space-x-3">
                      <span className="shrink-0 w-6 h-6 rounded-full bg-indigo-50 text-indigo-600 font-bold text-xs flex items-center justify-center mt-0.5">
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
              <Sparkles className="w-10 h-10 mb-3 stroke-1 text-slate-300" />
              <p className="text-sm font-medium text-slate-500">Паспорт проблемы пока не сформирован</p>
              <p className="text-xs text-slate-400 mt-1">Вставьте текст интервью слева и нажмите «Сгенерировать паспорт»</p>
            </div>
          )}
        </section>
      </main>
    </div>
  );
}
'@
Write-Utf8 "$WebDir\src\App.jsx" $appJsx

Write-Host "Фронтенд успешно сгенерирован в $WebDir!" -ForegroundColor Green