"""数据文件校验测试。"""

import json
import struct
from pathlib import Path

DATA_DIR = Path(__file__).parent.parent / "data"
CARD_ART_DIR = Path(__file__).parent.parent / "assets" / "sprites" / "cards"


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


def _all_records(folder: str, collection_key: str):
    for file in _json_files(folder):
        data = json.loads(file.read_text(encoding="utf-8"))
        for record in data.get(collection_key, []):
            yield file, record


def test_content_baseline():
    assert len(_json_files("worlds")) == 1
    assert len(_json_files("majors")) == 5
    assert len(_load_all_cards()) == 108
    assert len(_load_all_enemies()) == 10
    assert sum(1 for _ in _all_records("events", "events")) == 14


def test_world_packages_reference_existing_content():
    cards = _load_all_cards()
    character_ids = {
        json.loads(file.read_text(encoding="utf-8"))["id"]
        for file in _json_files("majors")
    }
    seen = set()
    for file in _json_files("worlds"):
        world = json.loads(file.read_text(encoding="utf-8"))
        world_id = world.get("id", "")
        assert world_id and world_id not in seen, f"无效或重复的世界 ID: {world_id}"
        seen.add(world_id)
        assert world.get("name"), f"{file} 缺少世界名称"
        assert world.get("selection_scene_path", "").startswith("res://")
        assert world.get("exploration_scene_path", "").startswith("res://")
        assert world.get("character_ids"), f"{world_id} 没有可用角色"
        assert set(world["character_ids"]) <= character_ids, f"{world_id} 引用了未知角色"
        assert set(world.get("shared_card_ids", [])) <= cards.keys(), f"{world_id} 引用了未知共享卡牌"
        assert isinstance(world.get("run_state_schema", {}), dict)


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

    for _file, card in _all_records("cards", "cards"):
        card_id = card["id"]
        assert card_id not in seen, f"重复的卡牌 ID: {card_id}"
        seen.add(card_id)


def test_no_duplicate_enemy_ids():
    seen = set()
    for _file, enemy in _all_records("enemies", "enemies"):
        enemy_id = enemy["id"]
        assert enemy_id not in seen, f"重复的敌人 ID: {enemy_id}"
        seen.add(enemy_id)


def test_every_card_has_standardized_art():
    cards = _load_all_cards()
    missing = sorted(card_id for card_id in cards if not (CARD_ART_DIR / f"{card_id}.png").exists())
    assert not missing, f"以下卡牌缺少独立插画: {missing}"
    for card_id in cards:
        image_path = CARD_ART_DIR / f"{card_id}.png"
        data = image_path.read_bytes()
        assert data[:8] == b"\x89PNG\r\n\x1a\n", f"{image_path} 不是有效 PNG"
        width, height = struct.unpack(">II", data[16:24])
        assert (width, height) == (256, 256), f"{image_path} 尺寸应为 256×256"
