#!/usr/bin/env python3
"""cross_validate_monsters.py，對照印刷攻略資料與 MONSTER.DAT

把手動抽樣的怪物數值比對自動化:逐筆核對已知樣本,並掃過全部 128 筆
找出超出合理範圍的異常值。

Usage:
    python3 cross_validate_monsters.py

環境變數(可選,預設依本檔位置推算):
    LD_GAME_DIR   遊戲資料夾(內含 P/MONSTER.DAT)
    LD_TOOLS_DIR  解密輸出資料夾(內含 all_enc_decrypted.json)
    LD_LOCAL_DIR  報告輸出資料夾

Output: 控制台報告 + 一份 JSON 報告
"""
import os, struct, json, datetime
from pathlib import Path

# 依本檔位置推算專案結構,不寫死任何個人路徑。
_HERE = Path(__file__).resolve().parent      # <site>/tools/extract
_SITE = _HERE.parent.parent                  # <site>
_PROJECT = _SITE.parent                      # 專案根目錄

GAME = Path(os.environ.get("LD_GAME_DIR", _PROJECT / "俠客遊2"))
TOOLS = Path(os.environ.get("LD_TOOLS_DIR", _PROJECT / "工具" / "extract"))
LOCAL = Path(os.environ.get("LD_LOCAL_DIR", _SITE / "_local"))

# Field offsets (verified against the record parser)
def u16(rec, off):
    return struct.unpack('<H', rec[off:off+2])[0]

# unk_26 / unk_2e 以有號整數讀取時範圍約 -25 到 30，不是物品 ID；
# unk_2c 有 29 隻小於 HP，不是 HP 上限。三者都尚未解讀。
OFFSETS = {
    'hp': 0x14, 'mp': 0x16, 'stm': 0x18, 'lv': 0x1A,
    'magic_count': 0x1C, 'sub_id': 0x22, 'exp': 0x24,
    'unk_26': 0x26, 'money': 0x28, 'unk_2c': 0x2C, 'unk_2e': 0x2E,
    'atk': 0x3E, 'def_slash': 0x40, 'def_thrust': 0x42, 'def_blunt': 0x44,
}

# 印刷攻略的已知樣本：1996 年攻略書 PART 5 第三章「怪物資料大全」，
# 人類 3 筆取自印頁 P118，終局 6 筆取自印頁 P123，照書上的名稱與數值抄錄。
# 攻略書把「魔王阿迦魯瑪」與「提斯卡托大惡魔」兩列的數值對調（魔王並記為 Lv 60），
# 所以這兩筆會回報不一致，這是攻略書的問題，不是解析錯誤。
PDF_SAMPLES = [
    # (id, name, lv, hp, atk)
    (3, '戰士', 3, 140, 50),
    (8, '騎士', 4, 160, 75),
    (9, '武士', 5, 120, 82),
    (122, '貝利亞', 50, 800, 150),
    (123, '帕茲斯', 50, 792, 152),
    (124, '共工', 50, 790, 160),
    (125, '酒吞童子', 50, 795, 162),
    (126, '魔王阿迦魯瑪', 60, 999, 170),
    (127, '提斯卡托大惡魔', 50, 788, 155),
]

def main():
    with open(f"{GAME}/P/MONSTER.DAT", 'rb') as f:
        data = f.read()
    record_size = 104
    n_records = len(data) // record_size
    assert n_records == 128, f'Expected 128 monsters, got {n_records}'

    with open(TOOLS / 'all_enc_decrypted.json', encoding='utf-8') as f:
        enc = json.load(f)
    monster_names = {r['id']: r['name'] for r in enc['MONSNAME.ENC']['records']}

    # === Cross-validate PDF samples ===
    matches = []
    mismatches = []
    for pid, pname, plv, php, patk in PDF_SAMPLES:
        rec = data[pid*record_size:(pid+1)*record_size]
        bin_name = monster_names.get(pid, '?')
        bin_lv = u16(rec, OFFSETS['lv'])
        bin_hp = u16(rec, OFFSETS['hp'])
        bin_atk = u16(rec, OFFSETS['atk'])
        result = {
            'id': pid, 'pdf_name': pname, 'bin_name': bin_name,
            'pdf_lv': plv, 'bin_lv': bin_lv,
            'pdf_hp': php, 'bin_hp': bin_hp,
            'pdf_atk': patk, 'bin_atk': bin_atk,
            'lv_match': bin_lv == plv,
            'hp_match': bin_hp == php,
            'atk_match': bin_atk == patk,
            'all_match': bin_lv == plv and bin_hp == php and bin_atk == patk,
        }
        if result['all_match']:
            matches.append(result)
        else:
            mismatches.append(result)

    print(f'=== PDF ↔ MONSTER.DAT cross-validate ({len(PDF_SAMPLES)} samples) ===')
    for r in matches + mismatches:
        mark = '✓' if r['all_match'] else '✗'
        print(f"  {mark} id={r['id']:3d} {r['pdf_name']:<8s} | "
              f"Lv {r['pdf_lv']}/{r['bin_lv']} {'✓' if r['lv_match'] else '✗'} | "
              f"HP {r['pdf_hp']}/{r['bin_hp']} {'✓' if r['hp_match'] else '✗'} | "
              f"ATK {r['pdf_atk']}/{r['bin_atk']} {'✓' if r['atk_match'] else '✗'}")

    print(f'\n  Total: {len(matches)}/{len(PDF_SAMPLES)} all match')

    # === All-128 anomaly scan ===
    anomalies = []
    for i in range(128):
        rec = data[i*record_size:(i+1)*record_size]
        lv = u16(rec, OFFSETS['lv'])
        hp = u16(rec, OFFSETS['hp'])
        atk = u16(rec, OFFSETS['atk'])
        if lv == 0 or lv > 60 or hp == 0 or hp > 9999:
            anomalies.append({
                'id': i, 'name': monster_names.get(i, '?'),
                'lv': lv, 'hp': hp, 'atk': atk,
                'reason': 'lv=0' if lv == 0 else 'lv>60' if lv > 60 else 'hp=0' if hp == 0 else 'hp>9999'
            })

    print(f'\n=== Anomaly scan (all 128 monsters) ===')
    if not anomalies:
        print(f'  ✓ All 128 monsters within expected range (Lv 1-60, HP 1-9999)')
    else:
        for a in anomalies[:10]:
            print(f'  ⚠ id={a["id"]:3d} {a["name"]:<14s} Lv={a["lv"]} HP={a["hp"]} ATK={a["atk"]} ({a["reason"]})')

    # Save report
    report = {
        'date': datetime.date.today().isoformat(),
        'pdf_samples_total': len(PDF_SAMPLES),
        'matches': len(matches),
        'mismatches_count': len(mismatches),
        'mismatches': mismatches,
        'all_match_ids': [r['id'] for r in matches],
        'anomalies_total_128': len(anomalies),
        'anomalies': anomalies,
        'observation': (
            '人類 3 筆（id 3、8、9）與終局 boss 4 筆（id 122-125）的等級、HP、攻擊力都與遊戲檔一致。'
            '攻略書把魔王阿迦魯瑪與提斯卡托大惡魔兩列的數值對調，並把魔王記為 Lv 60，'
            '所以 id 126、127 會回報不一致；遊戲檔 id 126 魔王阿迦魯瑪是 Lv 50 / HP 788，'
            'id 127 提斯卡托是 Lv 50 / HP 999，以遊戲檔為準。'
        )
    }
    out = Path(LOCAL) / 'monster_cross_validate_report.json'
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, 'w', encoding='utf-8') as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(f'\n→ Report saved to {out}')

if __name__ == '__main__':
    main()
