from unittest.mock import patch, MagicMock
import pytest
from app.yandex_client import call_yandex_gpt
from app.schemas import ExitInterviewAnalysis

@patch("requests.post")
def test_call_yandex_gpt_success(mock_post, sample_analysis_payload):
    import json
    
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        "result": {
            "alternatives": [
                {
                    "message": {
                        "text": json.dumps(sample_analysis_payload, ensure_ascii=False)
                    }
                }
            ]
        }
    }
    mock_post.return_value = mock_response
    
    raw_text = "Ухожу, так как нет роста."
    nlp_stats = {"total_words": 5, "top_lemmas": ["рост", "уходить"]}
    
    result = call_yandex_gpt(raw_text, nlp_stats)
    
    assert isinstance(result, ExitInterviewAnalysis)
    assert result.exit_reason == "карьерный потолок"
    assert result.risk_zone == "Medium"
    assert len(result.pain_points) == 1
    assert result.pain_points[0].implicit_emotion == "разочарование"

@patch("requests.post")
def test_call_yandex_gpt_api_error(mock_post):
    mock_response = MagicMock()
    mock_response.status_code = 403
    mock_response.text = "Forbidden: Invalid API Key"
    mock_post.return_value = mock_response
    
    with pytest.raises(Exception):
        call_yandex_gpt("Тест", {})