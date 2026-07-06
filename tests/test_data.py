"""数据文件校验测试。"""

import json
from pathlib import Path

DATA_DIR = Path(__file__).parent.parent / "data"


def _json_files(folder: str):
    path = DATA_DIR / folder
    if not path.exists():
        return []
    return list(path.glob("*.json"))


def _load_all_cards() -> dict:
    cards = {}
    for file in _json_files("cards"):
        data = json.loads(file.read_text(encoding="utf-8"))
        for card in data.get("cards", []):
            cards[card["id"]] = card
    return cards


def _load_all_enemies() -> dict:
    enemies = {}
    for file in _json_files("enemies"):
        data = json.loads(file.read_text(encoding="utf-8"))
        for enemy in data.get("enemies", []):
            enemies[enemy["id"]] = enemy
    return enemies


def test_majors_have_required_fields():
    for file in _json_files("majors"):
        data = json.loads(file.read_text(encoding="utf-8"))
        assert "id" in data, f"{file} 缺少 id"
        assert "name" in data, f"{file} 缺少 name"
        assert "stats" in data, f"{file} 缺少 stats"
        assert "starter_deck" in data, f"{file} 缺少 starter_deck"
        assert len(data["starter_deck"]) > 0


def test_cards_loadable():
    for file in _json_files("cards"):
        data = json.loads(file.read_text(encoding="utf-8"))
        assert "cards" in data
        for card in data["cards"]:
            assert "id" in card
            assert "name" in card
            assert "cost" in card
            assert "type" in card
            assert card["type"] in {"attack", "defense", "skill", "control", "heal", "finisher"}


def test_enemies_loadable():
    for file in _json_files("enemies"):
        data = json.loads(file.read_text(encoding="utf-8"))
        for enemy in data.get("enemies", []):
            assert "id" in enemy
            assert "name" in enemy
            assert "hp" in enemy
            assert enemy["type"] in {"normal", "elite", "boss", "ai_native"}


def test_events_loadable():
    for file in _json_files("events"):
        data = json.loads(file.read_text(encoding="utf-8"))
        for event in data.get("events", []):
            assert "id" in event
            assert "name" in event
            assert "description" in event


def test_major_starter_deck_cards_exist():
    cards = _load_all_cards()
    for file in _json_files("majors"):
        data = json.loads(file.read_text(encoding="utf-8"))
        for card_id in data["starter_deck"]:
            assert card_id in cards, f"专业 {data['id']} 的初始卡组包含未知卡牌 {card_id}"


def test_no_duplicate_card_ids():
    seen = set()
    cards = _load_all_cards()
    for card_id in cards:
        assert card_id not in seen, f"重复的卡牌 ID: {card_id}"
        seen.add(card_id)


def test_no_duplicate_enemy_ids():
    seen = set()
    enemies = _load_all_enemies()
    for enemy_id in enemies:
        assert enemy_id not in seen, f"重复的敌人 ID: {enemy_id}"
        seen.add(enemy_id)
