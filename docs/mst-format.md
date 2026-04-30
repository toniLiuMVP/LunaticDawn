# .MST / .DAT 結構化資料檔格式

> Artdink 1996《俠客遊 II》遊戲資料夾 `P/*.MST` 與 `*/*.DAT` 用 fixed-record 二進位格式存遊戲資料表。

## 通用模型

```
[Record 0][Record 1][Record 2]...[Record N-1]
```

- 每個 record 大小 **固定**（依檔案而異）
- record 數 = `file_size / record_size`
- 多數欄位是 little-endian u8 / u16 / u32

## 已驗證的檔案 schema

### ITEMDATA.MST （456 records × 48 bytes）

| Offset | 型別 | 欄位 |
|---|---|---|
| `0x00` | u16 | id |
| `0x04` | u16 | 價格 |
| `0x08` | u8 | 裝備位置（0=頭 1=身體 2=胳膊 3=腿腳 4=單手 5=雙手 6=手指 0xFF=非裝備品）|
| `0x09` | u8 | 體格限制 |
| `0x0A` | u8 | 命中率 |
| `0x0B` | u8 | 攻速 |
| `0x0C` | u8 | 距離 |
| `0x0D` | u8 | 特效 ID |
| `0x0E` | u8 | 攻擊類型（0=砍 1=刺 2=敲）|
| `0x0F` | u8 | 攻型輔助旗標 |
| `0x10` | u16 | 攻擊力 |
| `0x12` | u16 | 攻擊力 max |
| `0x14-0x19` | 6×u8 | 防砍 / 砍max / 防刺 / 刺max / 防敲 / 敲max |
| `0x1A-0x1B` | u16 | 攻擊類型驗證 |
| `0x1C-0x1D` | u8+u8 | 術型 / 術值（魔法附加）|
| `0x1E-0x24` | 7×u8 | 物 / 炎 / 冷 / 電 / 聖 / 暗 / 精上限 |
| `0x25` | u8 | 型式（0xFF=裝備品）|

### MONSTER.DAT （128 records × 104 bytes）

| Offset | 型別 | 欄位 |
|---|---|---|
| `0x00-0x13` | Big5 + 0x00 padding | 怪物名（inline）|
| `0x14` | u16 | HP（顯示值）|
| `0x16` | u16 | MP |
| `0x18` | u16 | unk（推測 STM/耐力）|
| `0x1A` | u16 | 等級 |
| `0x1C` | u16 | 魔法種類數 |
| `0x22` | u16 | sub-id |
| `0x24` | u16 | 經驗值 |
| `0x26` | u16 | 掉寶 1 ID（0xFFFF=無）|
| `0x28` | u16 | 金錢 |
| `0x2C` | u16 | HP max |
| `0x2E` | u16 | 掉寶 2 ID |
| `0x3E` | u16 | 攻擊力 |
| `0x40` | u16 | 防砍 |
| `0x42` | u16 | 防刺 |
| `0x44` | u16 | 防敲 |

### HISSATSU.MST （32 records × 36 bytes）

| Offset | 型別 | 欄位 |
|---|---|---|
| `0x00` | u8 | id |
| `0x01` | u8 | 武器類別 sub-id |
| `0x02` | u8 | 類型旗標（0x52='R' 主動 / 0x5F='_' 變體 / 0xFF 特殊）|
| 後續 | varies | 屬性參數 |

名稱不在 .MST 內，從 LUNA2.EXE 內嵌字串提取（offset 約 0x3FCC2-0x3FD07）。

### DUNGDATA.MST （40 records × 768 bytes）

完整欄位 schema 待逆向。已知檔案結構為「40 個迷宮 × 768 bytes」（不是 80 × 384）。
名稱從 DUNGNAME.ENC 偶數 index 讀取。

### MGCDATA.MST （80 records × 32 bytes）

每個魔法 = 主屬性 16 bytes + 附加屬性 16 bytes。
- `0x00` u16 id
- `0x02` u16 MP 消耗

## 推導 record_size 的方法

1. 觀察 file size 是否為「合理數量」整除（128 / 256 / 32 / 40 等是 RPG 常見資料筆數）
2. 確認 hex dump 中重複出現的 record marker（如 ID 連號 / `0xFFFFFFFF` 為 deleted slot）
3. cross-reference 跨檔案推資料量（例如 ITEMNAME.ENC 解出 456 名稱 → ITEMDATA.MST 應該也是 456 records）

## 實作參考

`tools/extract/parse_mst.py`（C 類純技術腳本）

## 衍生檔案的版權處理

依 `PUBLISHING.md` 規範：

- 格式 schema / offset 表 = **C 類**（純技術，可公開）
- 解析出的具體名稱列表 = **B 類**（依 toni 三選一處理）
- 解析出的數值欄位 = **C 類**（功能性 fact，可公開）
