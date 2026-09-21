from app.database import save_interview, get_all_interviews

def test_save_and_retrieve_interview(sample_analysis_payload):
    raw_text = "HR: Почему уходите? Сотрудник: Уперся в потолок."
    
    # Проверка сохранения
    record_id = save_interview(raw_text, sample_analysis_payload)
    assert isinstance(record_id, int)
    assert record_id > 0
    
    # Проверка выборки
    history = get_all_interviews()
    assert len(history) == 1
    assert history[0]["id"] == record_id
    assert history[0]["raw_text"] == raw_text
    assert history[0]["exit_reason"] == sample_analysis_payload["exit_reason"]
    assert history[0]["risk_zone"] == "Medium"
    assert history[0]["parsed_json"]["exit_reason"] == "карьерный потолок"
    assert len(history[0]["parsed_json"]["pain_points"]) == 1

def test_history_ordering(sample_analysis_payload):
    save_interview("Кейс 1", sample_analysis_payload)
    save_interview("Кейс 2", sample_analysis_payload)
    
    history = get_all_interviews()
    assert len(history) == 2
    # Сортировка по убыванию ID
    assert history[0]["raw_text"] == "Кейс 2"
    assert history[1]["raw_text"] == "Кейс 1"