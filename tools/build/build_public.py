"""
build_public.py — 從 _local/game_data_full.json 產生 luna2/database/game_data.json

PUBLISHING.md 第 4.4 條規範：
- 移除 texts.dialogues/rumors/endings/credits（A 類）
- 對 items/monsters/magics/hissatsu/dungeons 應用 B 類篩選（toni 未指定 → C 預設）
- 不複製 sprite 檔案到公開目錄
- 不嵌入完整劇情文字 / 結局 / credits

執行：
  cd LunaticDawn && python3 tools/build/build_public.py

輸出：
  luna2/database/game_data.json （已篩選）

來源：
  _local/game_data_full.json （本機完整版，PUBLISHING.md A 類）
"""

import json
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from filter_rules import filter_full_data

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "_local" / "game_data_full.json"
DST = ROOT / "luna2" / "database" / "game_data.json"

def main():
    if not SRC.exists():
        print(f"❌ 找不到 {SRC}")
        sys.exit(1)

    with SRC.open(encoding="utf-8") as f:
        full = json.load(f)

    public = filter_full_data(full)

    DST.parent.mkdir(parents=True, exist_ok=True)
    with DST.open("w", encoding="utf-8") as f:
        json.dump(public, f, ensure_ascii=False, indent=2)

    src_size = SRC.stat().st_size
    dst_size = DST.stat().st_size
    print(f"✓ 篩選完成")
    print(f"  輸入 (本機完整): {SRC} ({src_size:,} bytes)")
    print(f"  輸出 (公開篩選): {DST} ({dst_size:,} bytes)")
    print(f"  名稱欄位已替換為 '(本機保留)' (PUBLISHING.md B 類 C 選項)")

if __name__ == "__main__":
    main()
