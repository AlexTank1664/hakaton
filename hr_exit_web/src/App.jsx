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
  Download,
  Eye,
  Edit3
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
  const [viewMode, setViewMode] = useState("highlight"); // "highlight" | "edit"

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
      reader.onload = (event) => {
        setText(event.target.result);
        setViewMode("edit");
      };
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
      setViewMode("highlight");
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
    setViewMode("highlight");
  };

  const handleNewAnalysis = () => {
    setSelectedId(null);
    setText("");
    setData(null);
    setError(null);
    setViewMode("edit");
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

  // Поиск и разметка цитат в оригинальном тексте
  const renderHighlightedText = (rawText, parsedData) => {
    if (!parsedData) return rawText;

    const spans = [];

    // Красные: цитаты проблем
    if (parsedData.pain_points) {
      parsedData.pain_points.forEach((p) => {
        if (p.quote && p.quote.trim().length > 3) {
          const idx = rawText.toLowerCase().indexOf(p.quote.toLowerCase().trim());
          if (idx !== -1) {
            spans.push({
              start: idx,
              end: idx + p.quote.trim().length,
              type: "danger",
              label: `Проблема: ${p.issue}`
            });
          }
        }
      });
    }

    // Зеленые: цитаты положительных практик
    if (parsedData.best_practices) {
      parsedData.best_practices.forEach((bp) => {
        if (bp.anchor_quote && bp.anchor_quote.trim().length > 3) {
          const idx = rawText.toLowerCase().indexOf(bp.anchor_quote.toLowerCase().trim());
          if (idx !== -1) {
            spans.push({
              start: idx,
              end: idx + bp.anchor_quote.trim().length,
              type: "success",
              label: `Плюс: ${bp.practice}`
            });
          }
        }
      });
    }

    // Оранжевые: нейтральные / ключевые факты (причина ухода)
    if (parsedData.exit_reason && parsedData.exit_reason.trim().length > 3) {
      const idx = rawText.toLowerCase().indexOf(parsedData.exit_reason.toLowerCase().trim());
      if (idx !== -1) {
        spans.push({
          start: idx,
          end: idx + parsedData.exit_reason.trim().length,
          type: "warning",
          label: `Причина ухода: ${parsedData.exit_reason}`
        });
      }
    }

    if (spans.length === 0) {
      return <span className="whitespace-pre-wrap">{rawText}</span>;
    }

    // Сортировка и удаление взаимных наложений
    spans.sort((a, b) => a.start - b.start);
    const filteredSpans = [];
    let lastEnd = 0;
    for (const span of spans) {
      if (span.start >= lastEnd) {
        filteredSpans.push(span);
        lastEnd = span.end;
      }
    }

    // Сборка фрагментов JSX
    const elements = [];
    let cursor = 0;

    filteredSpans.forEach((span, i) => {
      if (span.start > cursor) {
        elements.push(
          <span key={`text-${i}`} className="whitespace-pre-wrap">
            {rawText.slice(cursor, span.start)}
          </span>
        );
      }

      let badgeStyle = "bg-rose-100 text-rose-900 border-b-2 border-rose-400";
      if (span.type === "success") {
        badgeStyle = "bg-emerald-100 text-emerald-900 border-b-2 border-emerald-400";
      } else if (span.type === "warning") {
        badgeStyle = "bg-amber-100 text-amber-900 border-b-2 border-amber-400";
      }

      elements.push(
        <mark
          key={`mark-${i}`}
          title={span.label}
          className={`${badgeStyle} px-1 py-0.5 rounded cursor-help font-medium transition-colors`}
        >
          {rawText.slice(span.start, span.end)}
        </mark>
      );
      cursor = span.end;
    });

    if (cursor < rawText.length) {
      elements.push(
        <span key="text-last" className="whitespace-pre-wrap">
          {rawText.slice(cursor)}
        </span>
      );
    }

    return elements;
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
      {/* Левый Сайдбар */}
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

      {/* Основная рабочая область */}
      <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
        <header className="bg-white border-b border-slate-200 px-8 py-3.5 flex items-center justify-between sticky top-0 z-10">
          <div>
            <h1 className="text-base font-bold text-slate-900">
              {selectedId ? `Просмотр отчета #${selectedId}` : "Анализ Exit Interview"}
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
          {/* Левая колонка: Текст с интерактивной разметкой */}
          <section className="lg:col-span-5 flex flex-col space-y-4">
            <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm flex-1 flex flex-col">
              <div className="flex items-center justify-between mb-3">
                <h2 className="font-semibold text-slate-800 text-xs tracking-wide uppercase">
                  Транскрипт интервью
                </h2>
                <div className="flex items-center space-x-2">
                  {data && (
                    <div className="flex bg-slate-100 rounded-lg p-0.5 border border-slate-200">
                      <button
                        onClick={() => setViewMode("highlight")}
                        className={`px-2 py-1 text-[11px] font-medium rounded-md flex items-center space-x-1 ${
                          viewMode === "highlight" ? "bg-white text-indigo-600 shadow-xs" : "text-slate-500 hover:text-slate-700"
                        }`}
                        title="Цветная разметка"
                      >
                        <Eye className="w-3 h-3" />
                        <span>Разметка</span>
                      </button>
                      <button
                        onClick={() => setViewMode("edit")}
                        className={`px-2 py-1 text-[11px] font-medium rounded-md flex items-center space-x-1 ${
                          viewMode === "edit" ? "bg-white text-indigo-600 shadow-xs" : "text-slate-500 hover:text-slate-700"
                        }`}
                        title="Редактировать текст"
                      >
                        <Edit3 className="w-3 h-3" />
                        <span>Правка</span>
                      </button>
                    </div>
                  )}
                  <label className="cursor-pointer text-xs text-indigo-600 hover:text-indigo-800 font-medium flex items-center space-x-1">
                    <Upload className="w-3.5 h-3.5" />
                    <span>.txt</span>
                    <input type="file" accept=".txt" onChange={handleFileUpload} className="hidden" />
                  </label>
                </div>
              </div>

              {/* Легенда подсветки */}
              {data && viewMode === "highlight" && (
                <div className="flex items-center space-x-2 mb-3 text-[10px] bg-slate-50 p-2 rounded-lg border border-slate-200">
                  <span className="flex items-center space-x-1 text-rose-700 font-medium">
                    <span className="w-2.5 h-2.5 rounded-sm bg-rose-300 inline-block"></span>
                    <span>Проблема</span>
                  </span>
                  <span className="flex items-center space-x-1 text-emerald-700 font-medium">
                    <span className="w-2.5 h-2.5 rounded-sm bg-emerald-300 inline-block"></span>
                    <span>Плюс</span>
                  </span>
                  <span className="flex items-center space-x-1 text-amber-700 font-medium">
                    <span className="w-2.5 h-2.5 rounded-sm bg-amber-300 inline-block"></span>
                    <span>Нейтрально</span>
                  </span>
                </div>
              )}

              {/* Отображение разметки или поля редактирования */}
              {data && viewMode === "highlight" ? (
                <div className="w-full flex-1 min-h-[360px] p-3.5 text-xs bg-slate-50 border border-slate-200 rounded-xl overflow-y-auto leading-relaxed text-slate-800">
                  {renderHighlightedText(text, data)}
                </div>
              ) : (
                <textarea
                  className="w-full flex-1 min-h-[360px] p-3.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:outline-none resize-none leading-relaxed"
                  value={text}
                  onChange={(e) => setText(e.target.value)}
                  placeholder="Вставьте диалог exit-интервью..."
                />
              )}

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

          {/* Правая колонка: Результат */}
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