# .ENC 加密文字檔格式

> Artdink 1996《俠客遊 II》遊戲資料夾 `O/*.ENC` 共 40 個檔，存放遊戲執行時顯示的文字資料（物品名、怪物名、迷宮名、各類訊息等）。
> 本文件為**獨立逆向研究結論**，不含遊戲原版文字內容。

## 加密演算法

**4-byte XOR cyclic**（最簡單的對稱加密）。

```
plain[i] = cipher[i] ^ KEY[i % 4]
```

key 為 4 個固定 byte 值（runtime 硬編碼常數，可從 LUNA2.EXE 提取，或用 known plaintext attack 還原）。

### 還原 key 的方法

任何已知會出現在某 .ENC 檔的 4 字組（例如 padding `@   ` = `0x40 0x20 0x20 0x20`，或行尾 CR+LF = `0x0D 0x0A`）：

```python
key[i] = ciphertext[offset + i] ^ known_plaintext[i]
```

驗證 key：用相同 key 對另一段 cipher 解密，看是否得到合理 Big5 字串。

## Record 結構

每個 .ENC 檔由多個 record 組成：

- 每個 record 以 **CR+LF (`0x0D 0x0A`)** 結尾（在 plain 中）
- record 長度依檔案而異（不固定）
- record 內容是 Big5 編碼字串 + padding

### 切 record 的兩種策略

**A. 固定長度切片**（適合 ITEMNAME, MONSNAME 等等長 record）

```python
# 找出第一個 CRLF 位置 + 2 = record_size
record_size = plain.index(b'\r\n') + 2
records = [plain[i:i+record_size] for i in range(0, len(plain), record_size)]
```

**B. CRLF 分隔**（適合變長 record，如 DUNGNAME）

```python
records = plain.split(b'\r\n')
```

### Record 內部結構

```
[Big5 字串][0x40 (@)][若干 0x20 空白 padding][0x0D 0x0A CRLF]
```

- 字串長度可變（2-12 個 Big5 char 通常）
- `0x40` 作為「字串結束標記」
- 字串長度不夠則用空白 padding 到 record 長度

### 特殊：交錯 record

部分 .ENC 檔（如 DUNGNAME.ENC）的「奇數 record」是 padding/placeholder（沒有實際內容），只有偶數 record 含真實名稱。

切片時 record 數應 ÷ 2 才是實際資料筆數。

## 實作參考

`tools/extract/decrypt_enc.py`（C 類純技術腳本）

- 載入 .ENC raw bytes
- 4-byte XOR 解密
- 自動偵測 record_size
- 輸出 JSON

## 衍生檔案的版權處理

依 `PUBLISHING.md` 規範：

- 解密演算法 / record 結構 = **C 類**（純技術，可公開）
- 解密後的具體文字內容（劇情/結局/工作人員/謠言）= **A 類**（本機保留）
- 解密後的名稱列表（物品/怪物/魔法/迷宮）= **B 類**（依 toni 三選一處理）
