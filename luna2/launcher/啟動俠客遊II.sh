#!/bin/bash
# ============================================================
#  俠客遊 II (Lunatic Dawn II) · Linux 啟動腳本
#  吟遊詩人的傳說 · 俠客遊小站
#  https://tonilumvp.github.io/LunaticDawn/
#
#  使用方式：
#    1. 把此檔案 + dosbox-x.conf 放在和 LUNA2.EXE 同一個資料夾
#    2. 給檔案執行權限： chmod +x 啟動俠客遊II.sh
#    3. 從檔案管理器雙擊（選擇「在終端機中執行」）或在終端機跑：
#         ./啟動俠客遊II.sh
#
#  需要 DOSBox-X：
#    Debian / Ubuntu :  sudo apt install dosbox-x
#    Fedora          :  sudo dnf install dosbox-x
#    Arch / Manjaro  :  yay -S dosbox-x        (AUR)
#    AppImage        :  https://dosbox-x.com/  (下載 .AppImage 後 chmod +x)
# ============================================================

# 切換到腳本自身所在的目錄
# 不管使用者從 GUI 雙擊還是從別的地方呼叫，cwd 都會被導正
cd "$(dirname "$(readlink -f "$0")")" || exit 1
GAME_DIR="$(pwd)"

echo "============================================================"
echo "  吟遊詩人的傳說 · 俠客遊 II 啟動器"
echo "  https://tonilumvp.github.io/LunaticDawn/"
echo "============================================================"
echo

# ----- 1) 找 DOSBox-X -----
# 先看 PATH，再看常見絕對路徑
DOSBOX="$(command -v dosbox-x 2>/dev/null)"

if [ -z "$DOSBOX" ]; then
    for try in \
        /usr/bin/dosbox-x \
        /usr/local/bin/dosbox-x \
        "$HOME/.local/bin/dosbox-x" \
        /opt/dosbox-x/dosbox-x \
        "$GAME_DIR/dosbox-x" \
        "$GAME_DIR/dosbox-x.AppImage"
    do
        if [ -x "$try" ]; then
            DOSBOX="$try"
            break
        fi
    done
fi

if [ -z "$DOSBOX" ]; then
    echo "✗ 找不到 DOSBox-X"
    echo
    echo "  請先安裝 DOSBox-X："
    echo "    Debian / Ubuntu :  sudo apt install dosbox-x"
    echo "    Fedora          :  sudo dnf install dosbox-x"
    echo "    Arch / Manjaro  :  yay -S dosbox-x"
    echo "    AppImage        :  https://dosbox-x.com/"
    echo
    read -p "按 Enter 結束 ..." dummy
    exit 1
fi

# ----- 2) 檢查遊戲本體 -----
if [ ! -f "$GAME_DIR/LUNA2.EXE" ]; then
    echo "✗ 找不到 LUNA2.EXE"
    echo "  目前路徑：$GAME_DIR"
    echo
    echo "  請把此啟動器（以及 dosbox-x.conf）放在和 LUNA2.EXE"
    echo "  同一個資料夾再執行。"
    echo
    read -p "按 Enter 結束 ..." dummy
    exit 1
fi

# ----- 3) 檢查設定檔 -----
if [ ! -f "$GAME_DIR/dosbox-x.conf" ]; then
    echo "✗ 找不到 dosbox-x.conf"
    echo "  目前路徑：$GAME_DIR"
    echo
    echo "  請從吟遊詩人的傳說 · 俠客遊小站下載 dosbox-x.conf："
    echo "    https://tonilumvp.github.io/LunaticDawn/luna2/launcher/"
    echo
    read -p "按 Enter 結束 ..." dummy
    exit 1
fi

# ----- 4) 啟動 -----
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
