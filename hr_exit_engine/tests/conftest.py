import pytest
from unittest.mock import patch
from fastapi.testclient import TestClient
import sqlite3

from app.main import app
import app.database as db_module

@pytest.fixture(autouse=True)
def test_db(tmp_path):
    """Изолированная база данных SQLite для каждого теста."""
    db_file = tmp_path / "test_interviews.db"
    with patch.object(db_module, "DB_PATH", db_file):
        db_module.init_db()
        yield db_file

@pytest.fixture
def client():
    """Тестовый клиент FastAPI."""
    with TestClient(app) as test_client:
        yield test_client

@pytest.fixture
def sample_analysis_payload():
    """Эталонный ответ структуры анализа (минимум 3 рекомендации)."""
    return {
        "exit_reason": "карьерный потолок",
        "risk_zone": "Medium",
        "sentiment_trend": "От лояльности и благодарности к разочарованию из-за отсутствия роста",
        "pain_points": [
            {
                "issue": "Отсутствие карьерного роста внутри грейда",
                "quote": "за два года я уперся в карьерный потолок",
                "frequency": 1,
                "implicit_emotion": "разочарование"
            }
        ],
        "best_practices": [
            {
                "practice": "Качественный процесс адаптации и менторства",
                "anchor_quote": "онбординг был идеальным, тимлид всегда поддерживал"
            }
        ],
        "improvement_suggestions": [
            "Внедрить прозрачные критерии промоушена между грейдами",
            "Создать фонд удержания ключевых сотрудников при наличии внешнего оффера",
            "Проводить регулярные сессии планирования индивидуального развития (ИПР)"
        ]
    }