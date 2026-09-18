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