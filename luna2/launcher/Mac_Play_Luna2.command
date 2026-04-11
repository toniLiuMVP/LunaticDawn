#!/bin/bash
# ============================================================
#  俠客遊 II (Lunatic Dawn II) · macOS 啟動腳本
#  吟遊詩人的傳說 · 俠客遊小站
#  https://tonilumvp.github.io/LunaticDawn/
#
#  使用方式：
#    1. 把此檔案 + dosbox-x.conf 放在和 LUNA2.EXE 同一個資料夾
#    2. 第一次執行可能要在「系統設定 > 隱私權與安全性」允許
#    3. 之後雙擊這個檔案就會自動啟動遊戲
#
#  需要 DOSBox-X：
#    brew install --cask dosbox-x-app
#    或從 https://dosbox-x.com/ 下載 .dmg 安裝
# ============================================================

# 切換到腳本自身所在的目錄（不管使用者從哪裡呼叫都對）
cd "$(dirname "$0")" || exit 1
GAME_DIR="$(pwd)"

# DOSBox-X 的預設安裝位置
DOSBOX="/Applications/dosbox-x.app/Contents/MacOS/dosbox-x"

echo "============================================================"
echo "  吟遊詩人的傳說 · 俠客遊 II 啟動器"
echo "  https://tonilumvp.github.io/LunaticDawn/"
echo "============================================================"
echo

# 檢查 DOSBox-X
if [ ! -x "$DOSBOX" ]; then
    echo "✗ 找不到 DOSBox-X"
    echo "  預期位置：$DOSBOX"
    echo
    echo "  請先安裝 DOSBox-X："
    echo "    brew install --cask dosbox-x-app"
    echo "  或到 https://dosbox-x.com/ 下載 .dmg 手動安裝"
    echo
    read -rp "按 Enter 關閉此視窗..."
    exit 1
fi

# 檢查遊戲本體
if [ ! -f "$GAME_DIR/LUNA2.EXE" ]; then
    echo "✗ 找不到 LUNA2.EXE"
    echo "  目前路徑：$GAME_DIR"
    echo
    echo "  請把此啟動器（以及 dosbox-x.conf）放在和 LUNA2.EXE"
    echo "  同一個資料夾再執行。"
    echo
    read -rp "按 Enter 關閉此視窗..."
    exit 1
fi

# 檢查設定檔
if [ ! -f "$GAME_DIR/dosbox-x.conf" ]; then
    echo "✗ 找不到 dosbox-x.conf"
    echo "  目前路徑：$GAME_DIR"
    echo
    echo "  請從吟遊詩人的傳說 · 俠客遊小站下載 dosbox-x.conf："
    echo "    https://tonilumvp.github.io/LunaticDawn/luna2/launcher/"
    echo
    read -rp "按 Enter 關閉此視窗..."
    exit 1
fi

# 檢查路徑是否包含非 ASCII 字元（中文等）
if echo "$GAME_DIR" | grep -qP '[^\x00-\x7F]'; then
    echo "⚠ 警告：遊戲路徑包含中文或特殊字元"
    echo "  目前路徑：$GAME_DIR"
    echo
    echo "  DOSBox 可能無法正確掛載含中文的路徑。"
    echo "  建議搬到純英文路徑，例如："
    echo "    /Users/你的帳號/Games/Luna2/"
    echo "    /home/你的帳號/Games/Luna2/"
    echo
    read -rp "仍要繼續嗎？[y/N] " REPLY
    if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ]; then
        exit 0
    fi
    echo
fi

echo "✓ DOSBox-X：$DOSBOX"
echo "✓ 遊戲路徑：$GAME_DIR"
echo "✓ 設定檔：$GAME_DIR/dosbox-x.conf"
echo
echo "▶ 啟動遊戲 ..."
echo

# 執行 DOSBox-X
#   -conf      指定硬體設定檔
#   -c         附加到 [autoexec] 後面的指令（完全不用改 conf 檔）
#
# 注意：我們先 cd 到 GAME_DIR，所以 DOSBox-X 啟動時的 cwd 也是這個目錄，
#       因此 `mount c .` 就是掛載遊戲資料夾。
exec "$DOSBOX" \
    -conf "$GAME_DIR/dosbox-x.conf" \
    -c "mount c ." \
    -c "c:" \
    -c "LUNA2.EXE"
