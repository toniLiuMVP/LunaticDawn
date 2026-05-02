#!/usr/bin/env python3
"""parse_chritem.py — CHRITEM.SAV 解析器（第二十二波，2026-05-02）

結構（已逆向）：
- 160 角色 × 768 bytes/角色（對齊 LUNACHAR.SAV 的 160 角色）
- 每角色 768 = 16 物品 slots × 48 bytes/slot
- 每 slot 結構：
  - byte 0-3: u32 LE = item_id（對應 ITEMNAME.ENC 1-456）
  - byte 4-7: u32 LE = value2（推測：價格，跟 ITEMDATA 對齊）
  - byte 8-15: 8 bytes 屬性 modifiers（強化值 / sub-id）
  - byte 16-47: 32 bytes 額外資料（特殊效果 / 玩家狀態）
  - empty slot 標記：item_id == 0xFFFFFFFF 或 (item_id == 0 and value2 == 0)

驗證樣本（char 0-5）：
- 全 160 角色都有物品（玩家 + 同行 + NPC 預設裝備）
- avg 12.5 items/char (min 7, max 16)
- 物品 ID 範圍 1-421（覆蓋大部分 ITEMNAME.ENC range）
"""
import os, struct, json
from pathlib import Path

GAME = "/Volumes/Work/LD/俠客遊2"

def parse_chritem(save_path=None):
    """解析 CHRITEM.SAV，回傳 dict {char_id: [items]}"""
    if save_path is None:
        save_path = f"{GAME}/USER0/CHRITEM.SAV"
    with open(save_path, 'rb') as f:
        data = f.read()
    assert len(data) == 122880, f'Expected 122880 bytes, got {len(data)}'

    chars = {}
    for char_id in range(160):
        items = []
        char_data = data[char_id*768:(char_id+1)*768]
        for slot in range(16):
            entry = char_data[slot*48:(slot+1)*48]
            item_id = struct.unpack('<I', entry[0:4])[0]
            value2 = struct.unpack('<I', entry[4:8])[0]
            # Empty slot detection
            if item_id == 0xFFFFFFFF or (item_id == 0 and value2 == 0):
                continue
            items.append({
                'slot': slot,
                'item_id': item_id,
                'value2': value2,
                'modifiers_hex': entry[8:16].hex(),
                'extra_data_hex': entry[16:48].hex(),
            })
        chars[char_id] = items
    return chars

def main():
    # Load item names
    enc_path = '/Volumes/Work/LD/工具/extract/all_enc_decrypted.json'
    if Path(enc_path).exists():
        with open(enc_path) as f:
            enc = json.load(f)
        item_names = {r['id']: r['name'] for r in enc['ITEMNAME.ENC']['records']}
    else:
        item_names = {}

    chars = parse_chritem()

    # Stats
    total_items = sum(len(items) for items in chars.values())
    active_chars = sum(1 for items in chars.values() if items)
    print(f'CHRITEM.SAV parsed:')
    print(f'  160 chars × 16 slots × 48 bytes = 122880 bytes')
    print(f'  Active chars: {active_chars}/160')
    print(f'  Total items: {total_items}')
    print(f'  Avg items/char: {total_items/160:.1f}')

    # Show first 5 chars in detail
    print(f'\n=== First 5 chars items ===')
    for cid in range(5):
        items = chars[cid]
        print(f'\n  char {cid}: {len(items)} items')
        for item in items[:8]:
            name = item_names.get(item['item_id'], f'?id_{item["item_id"]}')
            print(f'    slot {item["slot"]:2d}: id={item["item_id"]:4d} ({name:<14s}) val2={item["value2"]:6d}')

if __name__ == '__main__':
    main()
