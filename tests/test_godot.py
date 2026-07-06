"""运行 Godot 自动化测试场景。"""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
GODOT_PATH = ROOT / "tools" / "Godot.app" / "Contents" / "MacOS" / "Godot"
TEST_SCENE = ROOT / "tests" / "test_runner.tscn"


def test_godot_automation():
    """验证 Godot 项目能加载数据并完成战斗逻辑测试。"""
    if not GODOT_PATH.exists():
        raise FileNotFoundError(f"未找到 Godot 编辑器: {GODOT_PATH}")

    cmd = [str(GODOT_PATH), "--headless", "--path", str(ROOT), "--scene", str(TEST_SCENE)]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)

    print(result.stdout)
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        raise AssertionError(f"Godot 测试失败，返回码: {result.returncode}")

    assert "所有 Godot 数据加载测试通过" in result.stdout
    assert "所有战斗逻辑测试通过" in result.stdout
