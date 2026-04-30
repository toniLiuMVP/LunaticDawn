# 架構文件

> 學自 PTT 專案。本文件描述 LunaticDawn 的雙層架構、模組劃分、依賴方向。

## 設計原則

1. **本機完整、公開精簡**：所有逆向成果在 `_local/`，公開站只展示技術知識 + 篩選後資料
2. **policy as code**：`PUBLISHING.md` 規則 → `filter_rules.py` 程式化 → `build_public.py` 執行
3. **純靜態前端**：無 npm / 無 React / 無 Vite / 無框架，HTML+CSS+JS（DOM-only，禁 innerHTML）
4. **可重複建置**：所有 public/ 內容可從 `_local/` + tools/build/ 重新生成
5. **零信任**：raw hex / 完整名稱列表 / 圖像衍生物預設視為敏感，需明確規則放行

## 系統視圖

```
┌─────────────────────────────────────────────────────────────┐
│                  公開層（GitHub Pages）                       │
├─────────────────────┬───────────────────────────────────────┤
│ luna2/database/      │ luna2/save-editor.html (純前端)        │
│ - HTML × 5 (DOM-only) │ luna2/guides/ (社群攻略 HTML)         │
│ - list-page.js       │ luna2/launcher/ (DOSBox-X 跨平台)      │
│ - game_data.json     │ luna2/ez/ (Luna2_EZ 懶人包下載)        │
│   (B 選項篩選版)      │                                        │
└─────────┬────────────┴───────────────────────────────────────┘
          │ build_public.py + filter_rules.py
          │
┌─────────▼────────────────────────────────────────────────────┐
│              本機完整層（_local/，永不 git tracked）           │
│ - sprites_full/ (22 張 sprite PNG)                           │
│ - palettes_full/ (3 張非主 palette)                          │
│ - texts_full/ (enc_decrypted.json, texts.html)               │
│ - game_data_full.json (含 _raw, A 類劇情)                    │
│ - toni_notes_overrides.json (toni 客製評論)                   │
└─────────┬────────────────────────────────────────────────────┘
          │ tools/extract/*.py
          │
┌─────────▼────────────────────────────────────────────────────┐
│               遊戲二進制檔（俠客遊2/，read-only）              │
│ - LUNA2.EXE (內嵌 925 個 Big5 字串、8 個必殺技名)              │
│ - P/*.MST, *.DAT (fixed-record 數值表)                       │
│ - O/*.ENC (4-byte XOR 加密文字)                              │
│ - A,B,D,G,J,N/*.DDT, *.PAC, *.E32 (EGA 4-plane bitmap)       │
│ - A,B,D,G,J/*.PLT (256×4 bytes GRB444 palette)               │
└──────────────────────────────────────────────────────────────┘
```

## 工具鏈分層

```
tools/extract/  純技術解碼器（C 類）
├── decrypt_enc.py        # 4-byte XOR 解密
├── decrypt_all_enc.py    # 批次處理 40 個 ENC
├── parse_mst.py          # MST/DAT struct 解析
├── decode_plt.py         # GRB444 palette → RGB
├── decode_ddt.py         # EGA 4-plane bitmap
└── decode_ddt_multi.py   # 多 layout 假設並行測試

tools/build/    篩選與檢查（純技術）
├── filter_rules.py       # B 選項規則 + override 機制
├── build_public.py       # _local → public 篩選
└── pre_commit_check.sh   # PUBLISHING.md 4.3 條自動檢查
```

## 依賴方向（嚴格單向）

```
docs/*.md ────► tools/extract/ ────► _local/*_full.json
                                          │
                                          ▼
                                    tools/build/
                                          │
                                          ▼
                            luna2/database/*.html + game_data.json
                                          │
                                          ▼
                                  GitHub Pages 公開
```

**反向依賴禁止**：
- 不可在 `tools/extract/` 中內嵌遊戲資料（只能描述演算法）
- 不可在 `luna2/database/*.html` 中 hardcode A 類內容
- 不可在 git tracked 檔內 import `_local/`

## 備份系統

```
LD/                                ← 工作目錄（/Volumes/Work/LD/，本地 SSD）
├── Backup/
│   ├── backup-tools.sh tm          時光機 20 個（NAS）
│   ├── backup-tools.sh full        全專案 10 個（NAS）
│   ├── go.sh                       GO 6+1+1 步發布流程
│   ├── build-ez.sh                 懶人包打包
│   └── sync-to-smb.sh              Work → SMB Mac Mini M4 單向（toni B 方案）
└── 不刪除不上傳不截圖僅供資料參考（此資料夾不用備份）/
                                    本機 PDF 引用區，rsync 排除
```

## 進化路徑

| 階段 | 狀態 |
|---|---|
| 階段 1：建站、攻略 HTML、啟動器 | ✓ 完成 |
| 階段 2：存檔修改器 v0.2 + 懶人包 | ✓ 完成 |
| 階段 3：二進制逆向（ENC/MST/PLT/DDT） | ✓ 部分（mode 2/4/6/16）|
| 階段 4：版權合規重構（PUBLISHING.md） | ✓ 完成 |
| 階段 5：DDT mode 12-39 + DD9/PAC/E32 圖像 | ⏳ 待 |
| 階段 6：HISSATSU 32 records 完整 mapping | ⏳ 待 |
| 階段 7：database 全站搜尋 | ✓ 完成（timeline 公開版已撤回） |
| 階段 8：學自 PTT 的 ADR 流程 | ⏳ 規劃 |
