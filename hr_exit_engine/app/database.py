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