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