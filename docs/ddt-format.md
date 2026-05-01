# .DDT 圖像檔格式

> Artdink 1996《俠客遊 II》使用的自有點陣圖格式，副檔名 `.DDT` 與 `.DD9` 等。
> 結構源自 PC-98 / X68000 平台慣用的 EGA 4-plane bitmap 設計。

## Header (32 bytes)

| Offset | 大小 | 內容 |
|---|---|---|
| `0x00` | 12 bytes | filename ASCII（含 8.3 命名與 padding 空白）|
| `0x0C` | 12 bytes | reserved（多為 0x00）|
| `0x18` | u16 LE | mode（pixel format ID，影響 palette 對應）|
| `0x1A` | u16 LE | width（pixel）|
| `0x1C` | u16 LE | height（pixel）|
| `0x1E` | u16 LE | reserved |

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

## 已知 mode 列表（部分驗證）

| Mode | Layout 假設 | 狀態 |
|---|---|---|
| 2 | EGA 4-plane separate | ✓ 驗證 |
| 4 | EGA 4-plane separate | ✓ 驗證（字型表）|
| 6 | EGA 4-plane separate | ✓ 驗證（戰鬥道具）|
| 16 | EGA 4-plane separate | ✓ 驗證（魔法 sprite sheet）|
| 12 / 13 / 14 / 15 / 18 | 不同 plane count 或壓縮？ | ⏳ 待逆向 |
| 24 / 25 / 35 / 36 / 39 | 含內嵌 palette / 大圖格式 | ⏳ 待逆向 |

## .DD9 副檔名

部分檔案副檔名為 `.DD9` 但 header filename 仍是 `.DDT`。推測為「壓縮版 .DDT」或不同 mode 系列，header 之後的編碼方式與標準 .DDT 不同。

## 實作參考

`tools/extract/decode_ddt.py` + `decode_ddt_multi.py`（C 類純技術腳本）

## 衍生檔案的版權處理

依 `PUBLISHING.md` 規範：

- 格式結構文件 / 解碼演算法 = **C 類**（純技術，可公開）
- 解碼後的具體 PNG 圖像 = **A 類**（依 `PUBLISHING.md` 禁止上傳）
