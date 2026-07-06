"""AI 决策服务测试。"""

from fastapi.testclient import TestClient

from src.server.api import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["version"] == "0.1.0"


def test_decide_with_allowed_actions():
    payload = {
        "enemy": "AI面试官",
        "player_major": "计算机",
        "player_hp": 32,
        "player_spirit": 45,
        "visible_player_status": ["Bug构筑"],
        "last_player_actions": ["Bug生成"],
        "allowed_actions": ["ask_algorithm", "ask_ethics", "resume_challenge"],
        "prompt_key": "ai_interviewer",
    }
    response = client.post("/decide", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["action_id"] in payload["allowed_actions"]
    assert data["intent_text"] != ""
    assert data["source"] in ("llm", "fallback")


def test_decide_fallback_when_no_api_key():
    payload = {
        "enemy": "AI面试官",
        "player_major": "计算机",
        "player_hp": 10,
        "player_spirit": 20,
        "allowed_actions": ["ask_algorithm", "resume_challenge"],
    }
    response = client.post("/decide", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["action_id"] in payload["allowed_actions"]
    assert data["source"] == "fallback"
