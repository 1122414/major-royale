"""运行 Godot 自动化测试场景。"""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
GODOT_PATH = ROOT / "tools" / "Godot.app" / "Contents" / "MacOS" / "Godot"
TEST_SCENE = ROOT / "tests" / "test_runner.tscn"
FULL_RUN_SCENE = ROOT / "tests" / "full_run_runner.tscn"
PERFORMANCE_SCENE = ROOT / "tests" / "performance_runner.tscn"
BALANCE_SCENE = ROOT / "tests" / "balance_runner.tscn"
GRACEFUL_QUIT_SCENE = ROOT / "tests" / "graceful_quit_runner.tscn"


def _run_godot_scene(scene: Path) -> subprocess.CompletedProcess[str]:
    if not GODOT_PATH.exists():
        raise FileNotFoundError(f"未找到 Godot 编辑器: {GODOT_PATH}")

    cmd = [str(GODOT_PATH), "--headless", "--path", str(ROOT), "--scene", str(scene)]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)

    print(result.stdout)
    combined_output = f"{result.stdout}\n{result.stderr}"
    fatal_markers = ("SCRIPT ERROR:", "Assertion failed:", "Parse Error:", "Compile Error:")
    if result.returncode != 0 or any(marker in combined_output for marker in fatal_markers):
        print(result.stderr, file=sys.stderr)
        raise AssertionError(f"Godot 测试失败或日志含断言/编译错误，返回码: {result.returncode}")
    return result


def test_godot_automation():
    """验证 Godot 项目能加载数据并完成战斗逻辑测试。"""
    result = _run_godot_scene(TEST_SCENE)

    assert "所有 Godot 数据加载测试通过" in result.stdout
    assert "所有战斗逻辑测试通过" in result.stdout


def test_full_run_automation():
    """验证真实场景链可从新游戏连续推进到唯一上岸者。"""
    result = _run_godot_scene(FULL_RUN_SCENE)

    assert "新游戏到唯一上岸者整局回归通过" in result.stdout


def test_performance_regression():
    """验证重复战斗切场景后节点与静态内存不会持续爬升。"""
    result = _run_godot_scene(PERFORMANCE_SCENE)

    assert "次战斗场景循环通过" in result.stdout


def test_balance_matrix_regression():
    """以真实战斗、事件和奖励规则完成多专业、多种子、全难度长局模拟。"""
    result = _run_godot_scene(BALANCE_SCENE)

    assert "BALANCE: 共模拟 480 局" in result.stdout


def test_graceful_quit_releases_audio():
    """验证菜单按钮或桌面关闭请求不会留下音频播放与 WAV 资源。"""
    result = _run_godot_scene(GRACEFUL_QUIT_SCENE)
    combined_output = f"{result.stdout}\n{result.stderr}"

    assert "QUIT: 开始执行统一退出清理" in result.stdout
    assert "instances leaked at exit" not in combined_output
    assert "resources still in use at exit" not in combined_output
