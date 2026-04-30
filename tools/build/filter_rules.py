"""
filter_rules.py — PUBLISHING.md 規範的篩選規則

依 toni 2026-04-30 確認的 B 選項：
  保留原名 + 附 toni 視角短評（Claude 代擬攻略筆記，rule-based 生成）

評論基於數值區間 / 等級 / 屬性自動生成「玩家視角的攻略筆記」，
這把純名稱列表轉為「攻略內容」性質（PUBLISHING.md p2 規範）。
"""


def comment_item(record):
    """物品評論：依價格 / 攻擊力 / 體格區間 / 部位"""
    price = record.get('price', 0)
    atk = record.get('atk', 0)
    body = record.get('body_limit', 0)
    pos = record.get('equip_pos', '')
    effect = record.get('effect', '無')
    is_eq = record.get('is_equipment', True)
    name = record.get('name', '')

    if name == '離開' or price == 65535:
        return '商店 UI 取消按鈕，非實際物品'

    notes = []
    if price >= 50000 and atk >= 80:
        notes.append('神器級裝備，遊戲後期才能取得')
    elif price >= 10000:
        notes.append('高階裝備，價格不菲')
    elif price >= 3000:
        notes.append('中階裝備')
    elif price < 1000 and is_eq:
        notes.append('入門裝備，新手起點')

    if pos == '雙手':
        notes.append('雙手武器（無法搭配盾牌）')
    elif pos == '手指':
        notes.append('戒指類，加成屬性為主')
    elif pos == '非裝備品':
        notes.append('道具消耗品')

    if body >= 60:
        notes.append('體格需求極高，輕量角色難駕馭')
    elif body >= 40:
        notes.append('體格中等需求')

    if effect not in ('無', '—', None, ''):
        notes.append(f'附加特效（{effect}）')

    return '；'.join(notes) if notes else '一般用品'


def comment_monster(record):
    """怪物評論：依等級 + HP + MP + 攻擊力"""
    lv = record.get('level', 0)
    hp = record.get('hp', 0)
    mp = record.get('mp', 0)
    atk = record.get('atk', 0)
    drop_1 = record.get('drop_1')
    drop_2 = record.get('drop_2')

    notes = []
    if lv >= 30:
        notes.append('Boss 級高階敵人')
    elif lv >= 15:
        notes.append('精英級敵人，後期出現')
    elif lv >= 8:
        notes.append('中階敵人')
    elif lv <= 3:
        notes.append('初期常見雜兵')
    else:
        notes.append('中前期敵人')

    if mp > 0:
        notes.append(f'會使用魔法（MP={mp}）')

    if atk >= 100:
        notes.append('攻擊力極高，正面對抗風險大')
    elif atk >= 50:
        notes.append('攻擊力中等')

    if hp >= 200:
        notes.append('HP 厚實')
    elif hp <= 50:
        notes.append('HP 偏低，秒殺型')

    if drop_1 is not None or drop_2 is not None:
        notes.append('有掉寶')

    return '；'.join(notes)


def comment_magic(record):
    """魔法評論：依 MP 消耗"""
    mp = record.get('mp_cost', 0)
    if mp == 0:
        return '無 MP 消耗（被動或常駐？待逆向）'
    elif mp >= 100:
        return f'高消耗法術（MP {mp}），戰術性使用'
    elif mp >= 50:
        return f'中等消耗法術（MP {mp}）'
    elif mp >= 20:
        return f'常用法術（MP {mp}）'
    else:
        return f'低消耗法術（MP {mp}），新手期可頻繁使用'


def comment_hissatsu(record):
    """必殺技評論：依 ID byte 規律推測類型"""
    hid = record.get('id', 0)
    if hid < 16:
        if hid % 2 == 0:
            return '主動形必殺技（推測：byte[2]="R" 標記，第 8 種武器類別之一的核心招）'
        else:
            return '變體形必殺技（推測：byte[2]="_" 標記，主動形的進階版）'
    else:
        return '特殊類必殺技（推測：byte[2]=0xFF 標記，可能為 boss 專用或未啟用）'


def comment_dungeon(record):
    """迷宮評論：依 ID 推測階段"""
    did = record.get('id', 0)
    if did < 10:
        return '早期可進入的迷宮（推測低等級遭遇）'
    elif did < 25:
        return '中期迷宮'
    elif did < 35:
        return '後期迷宮（推測高等級遭遇）'
    else:
        return '終盤迷宮或特殊迷宮'


COMMENT_FUNCS = {
    'items': comment_item,
    'monsters': comment_monster,
    'magics': comment_magic,
    'hissatsu': comment_hissatsu,
    'dungeons': comment_dungeon,
}


def filter_full_data(full_data):
    """從 _local/game_data_full.json 過濾成 public game_data.json
    依 PUBLISHING.md B 選項（toni 確認）：保留 name + 加 toni_note"""
    public = {}
    for category, records in full_data.items():
        if not isinstance(records, list):
            public[category] = records
            continue
        commenter = COMMENT_FUNCS.get(category)
        if commenter is None:
            public[category] = records
            continue
        public[category] = []
        for r in records:
            new_r = dict(r)
            new_r.pop('_raw', None)
            new_r.pop('_raw_first_64', None)
            try:
                new_r['toni_note'] = commenter(r)
            except Exception:
                new_r['toni_note'] = ''
            public[category].append(new_r)
    return public
