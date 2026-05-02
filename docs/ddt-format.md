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

## 衍生檔案的版權處理

依 `PUBLISHING.md` 規範：

- 格式結構文件 / 解碼演算法 = **C 類**（純技術，可公開）
- 解碼後的具體 PNG 圖像 = **A 類**（依 `PUBLISHING.md` 禁止上傳）
