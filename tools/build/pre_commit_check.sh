#!/bin/bash
# pre_commit_check.sh — PUBLISHING.md 4.3 條規範 commit 前自動檢查
# 用法：在 LunaticDawn/ 內執行 ./tools/build/pre_commit_check.sh
# 違規時 exit 1（可整合 git pre-commit hook）

set -e
cd "$(dirname "$0")/../.."

err() { printf "\033[31m❌ %s\033[0m\n" "$1"; exit 1; }
ok()  { printf "\033[32m✓ %s\033[0m\n" "$1"; }

# 檢查 1: _local/ 不可被加進暫存區
if git diff --cached --name-only | grep -E '^_local/' > /dev/null 2>&1; then
  err "_local/ 內有檔案被 staged，違反 PUBLISHING.md 4.5 條"
fi
ok "_local/ 無 staged 檔"

# 檢查 2: 公開 game_data.json 不含 A 類關鍵字
if [ -f luna2/database/game_data.json ]; then
  if grep -E '結局訊息|エンディング|スタッフ' luna2/database/game_data.json > /dev/null 2>&1; then
    err "luna2/database/game_data.json 含 A 類關鍵字"
  fi
fi
ok "公開 game_data.json 無 A 類關鍵字"

# 檢查 3: sprites/ 目錄不存在或為空
if [ -d luna2/database/sprites ] && [ -n "$(ls -A luna2/database/sprites 2>/dev/null)" ]; then
  err "luna2/database/sprites/ 不應有內容（A 類絕對禁止）"
fi
ok "sprites/ 已清空"

# 檢查 4: 禁止措辭
forbidden=("事實在二進制裡" "逆向解析的完整資料庫")
for phrase in "${forbidden[@]}"; do
  if grep -rn "$phrase" --include="*.html" --include="*.js" --include="*.json" --include="*.md" \
     --exclude-dir=_local --exclude-dir=.git --exclude=PUBLISHING.md . > /dev/null 2>&1; then
    err "含禁止措辭「$phrase」"
  fi
done
ok "無禁止措辭"

# 檢查 5: palettes/ 應只有 luna2.png
if [ -d luna2/database/palettes ]; then
  count=$(ls luna2/database/palettes 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" -gt 1 ]; then
    err "palettes/ 應只有 luna2.png 主 palette（其他 $count - 1 張該移到 _local/）"
  fi
fi
ok "palettes/ 只有主 palette"

echo ""
ok "PUBLISHING.md 4.3 條檢查全部通過 ✓"
