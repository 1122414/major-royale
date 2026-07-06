"""数据文件校验测试。"""

import json
from pathlib import Path

DATA_DIR = Path(__file__).parent.parent / "data"


def _json_files(folder: str):
    path = DATA_DIR / folder
    if not path.exists():
        return []
    return list(path.glob("*.json"))


def test_majors_have_required_fields():
    for file in _json_files("majors"):
        data = json.loads(file.read_text(encoding="utf-8"))
        assert "id" in data, f"{file} 缺少 id"
        assert "name" in data, f"{file} 缺少 name"
        assert "stats" in data, f"{file} 缺少 stats"
        assert "starter_deck" in data, f"{file} 缺少 starter_deck"


def test_cards_loadable():
    for file in _json_files("cards"):
        data = json.loads(file.read_text(encoding="utf-8"))
        assert "cards" in data
        for card in data["cards"]:
            assert "id" in card
            assert "name" in card
            assert "cost" in card
