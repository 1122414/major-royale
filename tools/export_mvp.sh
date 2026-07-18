#!/usr/bin/env bash
# 导出并校验 macOS / Windows Steam 候选包（需 Godot 4.4.1 导出模板）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${ROOT}/tools/Godot.app/Contents/MacOS/Godot"
TEMPLATE_DIR="${HOME}/Library/Application Support/Godot/export_templates/4.4.1.stable"

if [[ ! -x "$GODOT" ]]; then
  echo "未找到可执行 Godot：$GODOT" >&2
  exit 1
fi
if [[ ! -f "${TEMPLATE_DIR}/macos.zip" || ! -f "${TEMPLATE_DIR}/windows_release_x86_64.exe" ]]; then
  echo "缺少 Godot 4.4.1 macOS 或 Windows 导出模板：$TEMPLATE_DIR" >&2
  exit 1
fi

mkdir -p "${ROOT}/build/mac" "${ROOT}/build/win"
"$GODOT" --editor --headless --path "$ROOT" --quit
"$GODOT" --headless --path "$ROOT" --export-release "macOS" "${ROOT}/build/mac/MajorRoyale.app"
"$GODOT" --headless --path "$ROOT" --export-release "Windows Desktop" "${ROOT}/build/win/MajorRoyale.exe"

if [[ ! -d "${ROOT}/build/mac/MajorRoyale.app" || ! -f "${ROOT}/build/win/MajorRoyale.exe" ]]; then
  echo "导出命令结束但候选包不完整" >&2
  exit 1
fi

mkdir -p "${ROOT}/build/mac/licenses" "${ROOT}/build/win/licenses"
cp "${ROOT}/THIRD_PARTY_NOTICES.md" "${ROOT}/PRIVACY.md" "${ROOT}/build/mac/"
cp "${ROOT}/THIRD_PARTY_NOTICES.md" "${ROOT}/PRIVACY.md" "${ROOT}/build/win/"
cp "${ROOT}/assets/fonts/OFL.txt" "${ROOT}/build/mac/licenses/LXGW_WenKai_OFL.txt"
cp "${ROOT}/assets/fonts/OFL.txt" "${ROOT}/build/win/licenses/LXGW_WenKai_OFL.txt"

(
  cd "$ROOT"
  shasum -a 256 "build/win/MajorRoyale.exe"
  if [[ -f "build/win/MajorRoyale.pck" ]]; then
    shasum -a 256 "build/win/MajorRoyale.pck"
  fi
  while IFS= read -r executable; do
    shasum -a 256 "$executable"
  done < <(find "build/mac/MajorRoyale.app/Contents/MacOS" -maxdepth 1 -type f -perm -111)
) > "${ROOT}/build/SHA256SUMS.txt"

echo "双平台候选包已导出："
du -sh "${ROOT}/build/mac/MajorRoyale.app" "${ROOT}/build/win"
echo "校验摘要：${ROOT}/build/SHA256SUMS.txt"
