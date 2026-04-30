# 品質基準（Quality Bar）

> 學自 PTT 專案的 KPI 模式。違反 🔴 紅線不得 ship 公開站。

## 公開站 KPI

| 指標 | 基準 | 量測方式 | 等級 |
|---|---|---|---|
| GitHub Pages 載入 → 主站可互動 | < 1.5 s | Lighthouse FCP | 🟠 |
| `database/` 任一頁載入 + game_data.json fetch | < 800 ms | Network panel | 🟠 |
| `save-editor.html` 載入完成 | < 500 ms | 純 HTML/JS 無依賴 | 🔴 |
| 純前端、無 npm / 無 build step | 100% | 檢查 `package.json` 不存在 | 🔴 |
| 無 innerHTML（XSS 防護） | 100% | grep 整個 LunaticDawn/ | 🔴 |
| 全站 retro CSS 一致性 | 100% | 共用 `assets/css/retro.css` | 🟠 |
| 字型本地化（不依賴 Google Fonts CDN） | 100% | 檢查 `fonts-retro.css` | 🟠 |

## 版權合規 KPI

| 指標 | 基準 | 等級 |
|---|---|---|
| `_local/` 不可在 git tracked 範圍 | 100% | 🔴 |
| `tools/build/pre_commit_check.sh` 通過 | 100% | 🔴 |
| 無禁止措辭（PUBLISHING.md 第五章） | 100% | 🔴 |
| `sprites/` 公開目錄為空 | 100% | 🔴 |
| `palettes/` 公開只有 luna2.png 主 palette | 100% | 🔴 |
| `game_data.json` 名稱欄位經 B 選項處理 | 100% | 🔴 |
| LUNA2.EXE 不在任何 git 路徑 | 100% | 🔴 |

## 備份 KPI

| 指標 | 基準 | 等級 |
|---|---|---|
| 寫檔操作前自動 tm 備份 | 100% | 🔴 |
| 時光機備份 ≤ 20 個 | 100% | 🟠 |
| 全專案備份 ≤ 10 個 | 100% | 🟠 |
| NAS 鏡像 + Google Drive 至少各 1 份 | 100% | 🟠 |
| `_local/` 不上 NAS（隱私）| 100% | 🔴 |

## 二進制逆向 KPI

| 指標 | 基準 | 等級 |
|---|---|---|
| 任一 .ENC 解密準確度 | 100% Big5 valid | 🟠 |
| ITEMDATA.MST 28 欄位驗證準確度 | ≥ 95% spot-check | 🟠 |
| MONSTER.DAT 12 欄位驗證準確度 | ≥ 90% spot-check | 🟡 |
| docs/ 技術文件可獨立復現 parser | 100% | 🟡 |

## 違反紅線時的動作

任何 🔴 紅線違反 → **立刻 git rm + push** 移除公開內容，再修補。
歷史先例：commit `4df08bf`（內嵌 PDF 縮圖）→ commit `7524552`（緊急 revert，35 分鐘內完成）。
