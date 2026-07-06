#!/usr/bin/env python3
"""MVP 功能测试脚本入口。

运行 Python 后端测试与 Godot 自动化测试场景。
"""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent


def _run_pytest() -> int:
    print("=" * 60)
    print("运行 Python 后端与数据测试...")
    print("=" * 60)
    result = subprocess.run(
        [sys.executable, "-m", "pytest", "tests/", "-v"],
        cwd=ROOT,
    )
    return result.returncode


def _run_godot_test() -> int:
    print("\n" + "=" * 60)
    print("运行 Godot 自动化测试场景...")
    print("=" * 60)
    godot = ROOT / "tools" / "Godot.app" / "Contents" / "MacOS" / "Godot"
    if not godot.exists():
        print(f"未找到 Godot 编辑器: {godot}", file=sys.stderr)
        return 1

    result = subprocess.run(
        [str(godot), "--headless", "--path", str(ROOT), "--scene", "tests/test_runner.tscn"],
        cwd=ROOT,
    )
    return result.returncode


def main() -> int:
    pytest_code = _run_pytest()
    godot_code = _run_godot_test()

    print("\n" + "=" * 60)
    if pytest_code == 0 and godot_code == 0:
        print("所有测试通过 ✓")
        return 0
    else:
        print(f"测试失败：pytest={pytest_code}, godot={godot_code}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
