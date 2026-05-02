#!/usr/bin/env python3
"""parse_shopitem.py — SHOPITEM.SAV 解析器（第二十四波，2026-05-02）

結構（已逆向）：
- 16 shops × 768 bytes/shop（總 12288 bytes）
- 每 shop:
  - byte 0-3: u32 LE header（值 = shop_id × 0x10000 + sub_id，例 0x00020000）
  - byte 4-X: u16 LE item IDs 序列（每物品 2 bytes）
  - 直到 0xFFFF marker
  - 之後 padding 到 768 bytes

實測（USER0/SHOPITEM.SAV）：
- 16 個 slot 中 11 個有 items（shop 0/1/2/4/7/8/10/11/12/13/15），5 個 empty
- 每 shop 10-16 件物品
- shop IDs 對應 6 國城鎮：
  - shop 0-2: 神聖吉札帝國（歐德普克 / 路特卡得）
  - shop 4: 樸哈爾帝國
  - shop 7-8: 日傑（紫陽 / 鹿谷）
  - shop 10-11: 馬尼卡帕王國
  - shop 12-13: 芙庫基歐
  - shop 15: 終局武器
"""
import os, struct, json
from pathlib import Path

GAME = "/Volumes/Work/LD/俠客遊2"

def parse_shopitem(save_path=None):
    if save_path is None:
        save_path = f"{GAME}/USER0/SHOPITEM.SAV"
    with open(save_path, 'rb') as f:
        data = f.read()
    assert len(data) == 12288, f'Expected 12288 bytes, got {len(data)}'

    shops = []
    for shop_id in range(16):
        shop = data[shop_id*768:(shop_id+1)*768]
        header = struct.unpack('<I', shop[0:4])[0]
        items = []
        for off in range(4, 768, 2):
            v = struct.unpack('<H', shop[off:off+2])[0]
            if v == 0xFFFF: break
            if v == 0: continue
            items.append(v)
        shops.append({'shop_id': shop_id, 'header': header, 'items': items})
    return shops


def main():
    enc_path = '/Volumes/Work/LD/工具/extract/all_enc_decrypted.json'
    if Path(enc_path).exists():
        with open(enc_path) as f:
            enc = json.load(f)
        item_names = {r['id']: r['name'] for r in enc['ITEMNAME.ENC']['records']}
    else:
        item_names = {}

    shops = parse_shopitem()
    total_items = sum(len(s['items']) for s in shops)
    active = sum(1 for s in shops if s['items'])
    print(f'SHOPITEM.SAV: 16 shops × 768 bytes = 12288 bytes')
    print(f'  Active shops: {active}/16')
    print(f'  Total items: {total_items}')
    for s in shops:
        if not s['items']:
            print(f'\n  shop {s["shop_id"]:2d}: (empty)')
            continue
        print(f'\n  shop {s["shop_id"]:2d}: header=0x{s["header"]:08x}, {len(s["items"])} items')
        for i, iid in enumerate(s['items'][:8]):
            name = item_names.get(iid, f'?{iid}')
            print(f'    [{i:2d}] id={iid:4d} {name}')
        if len(s['items']) > 8:
            print(f'    ... +{len(s["items"])-8} more')


if __name__ == '__main__':
    main()
