#!/bin/bash
# ============================================================
#  俠客遊 II (Lunatic Dawn II) · Linux 啟動腳本
#  吟遊詩人的傳說 · 俠客遊小站
#  https://toniliumvp.github.io/LunaticDawn/
#
#  使用方式：
#    1. 把此檔案 + dosbox-x.conf 放在和 LUNA2.EXE 同一個資料夾
#    2. 給檔案執行權限： chmod +x Linux_Play_Luna2.sh
#    3. 從檔案管理器雙擊（選擇「在終端機中執行」）或在終端機跑：
#         ./Linux_Play_Luna2.sh
#
#  需要 DOSBox-X：
#    Debian 13+ / Ubuntu 24.04+ :  sudo apt install dosbox-x
#    Arch / Manjaro (AUR)       :  yay -S dosbox-x
#    Fedora 與其他發行版        :  flatpak install flathub com.dosbox_x.DOSBox-X
#
#  注意：這支腳本沒有在 Linux 實機測試過，Flatpak 版的啟動方式也還沒實測。
# ============================================================

# 切換到腳本自身所在的目錄
# 不管使用者從 GUI 雙擊還是從別的地方呼叫，cwd 都會被導正
cd "$(dirname "$(readlink -f "$0")")" || exit 1
GAME_DIR="$(pwd)"

echo "============================================================"
echo "  吟遊詩人的傳說 · 俠客遊 II 啟動器"
echo "  https://toniliumvp.github.io/LunaticDawn/"
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

# 都找不到時，改找 Flathub 的 DOSBox-X（Flatpak 版）
FLATPAK_ID="com.dosbox_x.DOSBox-X"
USE_FLATPAK=0
if [ -z "$DOSBOX" ] && command -v flatpak >/dev/null 2>&1 && flatpak info "$FLATPAK_ID" >/dev/null 2>&1; then
    USE_FLATPAK=1
    DOSBOX="flatpak run $FLATPAK_ID"
fi

if [ -z "$DOSBOX" ]; then
    echo "✗ 找不到 DOSBox-X"
    echo
    echo "  請先安裝 DOSBox-X："
    echo "    Debian 13+ / Ubuntu 24.04+ :  sudo apt install dosbox-x"
    echo "    Arch / Manjaro (AUR)       :  yay -S dosbox-x"
    echo "    Fedora 與其他發行版        :  flatpak install flathub com.dosbox_x.DOSBox-X"
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
    echo "    https://toniliumvp.github.io/LunaticDawn/luna2/launcher/"
    echo
    read -p "按 Enter 結束 ..." dummy
    exit 1
fi

# ----- 4) 檢查路徑是否包含非 ASCII 字元（中文等）-----
# 使用 LC_ALL=C 讓 grep 以 byte 模式比對
if printf '%s' "$GAME_DIR" | LC_ALL=C grep -q '[^ -~]'; then
    echo "⚠ 警告：遊戲路徑包含中文或特殊字元"
    echo "  目前路徑：$GAME_DIR"
    echo
    echo "  DOSBox 可能無法正確掛載含中文的路徑。"
    echo "  建議搬到純英文路徑，例如："
    echo "    /home/你的帳號/Games/Luna2/"
    echo
    read -rp "仍要繼續嗎？[y/N] " REPLY
    if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ]; then
        exit 0
    fi
    echo
fi

# ----- 5) 啟動 -----
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
#
# Flatpak 版在沙箱裡執行：用 --filesystem 讓家目錄以外的遊戲資料夾也能讀到，
# 並直接用完整路徑 mount，不依賴沙箱內的目前目錄（尚未在 Linux 實機測試）。
if [ "$USE_FLATPAK" = 1 ]; then
    exec flatpak run --filesystem="$GAME_DIR" "$FLATPAK_ID" \
        -conf "$GAME_DIR/dosbox-x.conf" \
        -c "mount c \"$GAME_DIR\"" \
        -c "c:" \
        -c "LUNA2.EXE"
fi

exec "$DOSBOX" \
    -conf "$GAME_DIR/dosbox-x.conf" \
    -c "mount c ." \
    -c "c:" \
    -c "LUNA2.EXE"
