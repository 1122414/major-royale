#!/usr/bin/env python3
"""MVP 功能测试脚本入口。"""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent


def main() -> int:
    """运行 pytest 测试套件。"""
    print("运行专业大逃杀 MVP 功能测试...")
    result = subprocess.run(
        [sys.executable, "-m", "pytest", "tests/", "-v"],
        cwd=ROOT,
    )
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
