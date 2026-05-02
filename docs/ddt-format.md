# .DDT 圖像檔格式

> Artdink 1996《俠客遊 II》使用的自有點陣圖格式，副檔名 `.DDT` 與 `.DD9` 等。
> 結構源自 PC-98 / X68000 平台慣用的 EGA 4-plane bitmap 設計。

## Header (32 bytes)

| Offset | 大小 | 內容 |
|---|---|---|
| `0x00` | 16 bytes | filename ASCII（含 8.3 命名 + 空白 padding 至 12 chars + `.DDT` + null 至 16 bytes）|
| `0x10` | 8 bytes | reserved（全 0x00）|
| `0x18` | u16 LE | mode（sub-type metadata，**不影響 layout**）|
| `0x1A` | u16 LE | width（pixel）|
| `0x1C` | u16 LE | height（pixel）|
| `0x1E` | u16 LE | reserved（樣本中皆 0）|

**第十七波修正**：第八波文件曾寫「mode 影響 palette 對應」，但實證所有 mode 都共用 LUNA2.PLT 256 色 palette + 同一 4bpp planar layout。mode 只是「sub-type / 用途分類」，不影響 decoder 行為。

## Pixel Layout

**EGA 4-plane separate**（已驗證 mode 2 / 4 / 6 / 16）：

```
data = plane_0_全部 + plane_1_全部 + plane_2_全部 + plane_3_全部
```

每個 plane size = `(width / 8) × height` bytes（每 byte 8 個 1-bit pixel）。

每個 pixel 顏色 index：

```
color_index = plane_0_bit | (plane_1_bit << 1) | (plane_2_bit << 2) | (plane_3_bit << 3)
```

得到 0-15 的 4-bit indexed value，對應 16 色 palette。

## 驗證

| 樣本 | Mode | 尺寸 | data size | 計算 |
|---|---|---|---|---|
| KEN00.DDT | 2 | 32×32 | 512 bytes | 32/8 × 32 × 4 = 512 ✓ |
| FENIX.DDT | 16 | 128×256 | 16384 bytes | 128/8 × 256 × 4 = 16384 ✓ |

## 已知 mode 列表（2026-05-02 第十七波擴充驗證）

**結論：所有 mode 都是同一 layout（4bpp planar separate），mode 數值是 sub-type metadata 不影響 decoding。**

| Mode | Layout | 狀態 | 樣本 / 用途 |
|---|---|---|---|
| 2 | EGA 4-plane separate | ✓ 驗證 | KEN01.DDT 32×32 物件圖示 |
| 4 | EGA 4-plane separate | ✓ 驗證 | STR_A.DDT 128×64 字型/小 panel |
| 14 | EGA 4-plane separate | ✓ 驗證 | NAME0.DDT 88×216 命名表 |
| 16 | EGA 4-plane separate | ✓ 驗證 | KIRKIR/YADARAKE 32×256 動畫序列、FENIX 128×256 sprite sheet |
| 18 | EGA 4-plane separate | ✓ 驗證 | METEO.DDT 32×288 隕石動畫 |
| 25 | EGA 4-plane separate | ✓ 驗證 | CHR0.DDT 208×400 角色 sprite 大表 |
| 36 | EGA 4-plane separate | ✓ 驗證 | LOGO.DDT 52×576 標誌大圖 |

**驗證方法**：對每個 mode 樣本檔，計算 `pixel_bytes / (w × h / 2)` 應該 = 1.00（4bpp planar 必滿足）。第十七波 8 個樣本全部 ratio 1.00，無例外。

**Mode purpose 推測**（不影響 decoding，只是分類用）：
- mode 2 = 小物件 sprite（≤ 32×32）
- mode 4 = 字型 / UI panel
- mode 14/15 = 命名 / Logo 中型圖
- mode 16/18 = 動畫序列（高度 = frames × frame_height）
- mode 25 = 大型 sprite 表（角色 / 多單位）
- mode 36 = 特殊大圖

**第八波遺留誤判已修正**：
- 第八波寫「mode 6 確認」— 但實際 DDT 檔列表沒有 mode 6（只有 mode 2/4/14/15/16/18/25/36/類似）
- 第八波 next_steps 寫「mode 12-39 layout 逆向」— 第十七波證實**沒有不同 layout**，所有 mode 都是 plane separate

## .DD9 副檔名

部分檔案副檔名為 `.DD9` 但 header filename 仍是 `.DDT`。推測為「壓縮版 .DDT」或不同 mode 系列，header 之後的編碼方式與標準 .DDT 不同。

## 實作參考

`tools/extract/decode_ddt.py` + `decode_ddt_multi.py`（C 類純技術腳本）

## .DDT Sister Formats（2026-05-02 第十七~二十波 survey + 部分逆向）

LD 第十七波 DDT real header 釐清後，第十八/二十波對 sister formats 做結構性 survey：

### .DD9 — 壓縮版 .DDT

- **檔數**：27 個（74 KB total，size 範圍 225-6648 bytes）
- **header**：byte 0-15 是 `X.DDT` filename（非 X.DD9）
- **magic bytes**：byte 12 = `0x9c` 一致 ✓ / byte 14 = `0x91` 一致 ✓ — 兩個 magic
- **byte 13 / 15**：parameter A/B（壓縮率 hint / chunks count）
- **壓縮性質**：BOAT.DD9 byte distribution 14/256 unique bytes（高壓縮）/ ICON0.DD9 245/256（低壓縮）
- **狀態**：⏳ 完整 LZ decompressor 待 LUNA2.EXE 反組譯確認算法（推測 LZSS 變體）

### .BCHRKP*.DDT — Runtime template（**全 0 已駁回**）

- **檔數**：28 個（505 KB total，每檔 18464 bytes uniform）
- **2026-05-02 第二十波發現**：所有 28 檔都是 **100% 全 0 bytes**！
- **真相**：跟 `DUNGDATA.MST` 同 pattern — runtime template，遊戲安裝時的初始狀態（runtime 由 USERN/ 填入）
- **狀態**：❌ 駁回「BCHRKP dim 視覺驗證」PENDING — 沒像素資料可解碼

### .PAC — 多檔打包格式

- **檔數**：60 個（6.8 MB total，size 範圍 4 KB - 1.4 MB）
- **header**：byte 0-X 是 **u32 LE size table**（無 filename header）
- **第二十波突破**：`FTEDAT.PAC` / `OTEDAT.PAC` 結構完美對齊：
  - 78 entries × 576 bytes 各自獨立資料
  - byte 0-311 size table（u32 LE × 78，全為 576）
  - byte 312-45239 = 78 × 576 = 44928 bytes data
- **entry 內部 sub-header**：u32 LE × 4（FTEDAT entry: 0/192/608/1024 / OTEDAT entry: 0/416/768/1216）— 推測 sub-data offsets
- **filename 推測**：FTE32 = Font Two-byte Extended 32×32 / OTE32 = Other / EVE = Event 動畫 / FTEDAT/OTEDAT = Font/Other Data
- **狀態**：🟢 size table + entry size 確認；entry 內 sub-format decoder 待逆向

### .E32 — Enemy 32×32 sprites

- **檔數**：45 個（803 KB total，size 範圍 600-28880 bytes）
- **header**：無一致 pattern（C00 / T80 / T81 等短碼 filename）
- **第二十波突破**：`C00.E32` 結構釐清：
  - 5632 bytes = **11 sprites × 32×32 4bpp planar**（每 sprite 512 bytes，整除）
  - 無 header，pixel data 從 byte 0 開始
- **filename 推測**：C?? = Common 怪物 / T?? = Town / Trap / Type sprite
- **大檔差異**：T80.E32 28880 bytes 不是 sprite size 整除 → 含 frame metadata 或不同 dim 序列
- **狀態**：🟢 C00 全 11 sprites 解碼成功；T?? 不同檔可能有不同 dim 結構

## 衍生檔案的版權處理

依 `PUBLISHING.md` 規範：

- 格式結構文件 / 解碼演算法 = **C 類**（純技術，可公開）
- 解碼後的具體 PNG 圖像 = **A 類**（依 `PUBLISHING.md` 禁止上傳）
