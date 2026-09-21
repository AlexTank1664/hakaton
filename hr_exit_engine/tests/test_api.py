from unittest.mock import patch
from app.schemas import ExitInterviewAnalysis

def test_health_check(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}

def test_get_history_empty(client):
    response = client.get("/history")
    assert response.status_code == 200
    assert response.json() == []

def test_analyze_invalid_payload(client):
    # Пустой JSON
    response = client.post("/analyze", json={})
    assert response.status_code == 422

@patch("app.main.call_yandex_gpt")
def test_analyze_success(mock_gpt, client, sample_analysis_payload):
    mock_gpt.return_value = ExitInterviewAnalysis(**sample_analysis_payload)
    
    raw_text = "Тестовое интервью для проверки API"
    response = client.post("/analyze", json={"text": raw_text})
    
    assert response.status_code == 200
    data = response.json()
    assert data["exit_reason"] == "карьерный потолок"
    assert data["risk_zone"] == "Medium"
    assert len(data["pain_points"]) == 1
    
    # Проверяем, что результат сразу появился в /history
    history_resp = client.get("/history")
    assert history_resp.status_code == 200
    history_data = history_resp.json()
    assert len(history_data) == 1
    assert history_data[0]["raw_text"] == raw_text
    assert history_data[0]["exit_reason"] == "карьерный потолок"

@patch("app.main.call_yandex_gpt")
def test_analyze_internal_error(mock_gpt, client):
    mock_gpt.side_effect = RuntimeError("Yandex Cloud Network Timeout")
    
    response = client.post("/analyze", json={"text": "Любой текст"})
    assert response.status_code == 500
    assert "Yandex Cloud Network Timeout" in response.json()["detail"]