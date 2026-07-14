#!/usr/bin/env bash
# 导出 macOS / Windows 包（需已安装 Godot 4.4 导出模板）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${ROOT}/tools/Godot.app/Contents/MacOS/Godot"
mkdir -p "${ROOT}/build/mac" "${ROOT}/build/win"
"$GODOT" --headless --path "$ROOT" --export-release "macOS" "${ROOT}/build/mac/MajorRoyale.app"
"$GODOT" --headless --path "$ROOT" --export-release "Windows Desktop" "${ROOT}/build/win/MajorRoyale.exe"
echo "Export finished. Check build/"
