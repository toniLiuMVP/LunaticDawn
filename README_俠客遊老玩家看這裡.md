# 🗡️ 俠客遊老玩家專屬指南

> 1996 年第三波代理中文版玩過的人，專屬入口。

## 🎯 你想做什麼？

| 目的 | 直接點 |
|---|---|
| **重新體驗遊戲**（最快） | [Luna2_EZ 懶人包下載](https://drive.google.com/file/d/1jZL_9KnSpwyMiTjI9HyTvSnFeLkBTP_e/view) — 解壓即玩、跨 Mac/Win/Linux |
| **翻看當年攻略** | [9 篇社群攻略 HTML](luna2/guides/) — 含 1999 BBS 原文（小蜜蜂、小傑、Ertai） |
| **改存檔（HP/MP/物品）** | [瀏覽器版存檔修改器](luna2/save-editor.html) — 純前端、不上傳 |
| **查物品 / 怪物數值** | [遊戲資料庫](luna2/database/) — 從遊戲檔案逆向出的數值表 |
| **自己裝 DOSBox-X 玩** | [跨平台啟動器](luna2/launcher/) — Mac `.command` / Win `.bat` / Linux `.sh` |

## ⚠️ macOS 26 啟動 .command 被擋？

不是你的錯。Apple 在 macOS 26.4 對 SMB 網路磁碟強制加 `quarantine` flag、外接 USB 也可能受限。

**最簡解法**：在 Terminal 用 `bash` 直接跑：

```bash
bash "/Volumes/Work/LD/俠客遊2/啟動俠客遊II.command"
```

或下載懶人包用內建的 DOSBox Staging。

## 📜 什麼是吟遊詩人的傳說？

2007 年 Google Sites 站「吟遊詩人的傳說 · 俠客遊小站」（`sites.google.com/site/lunticdawn`）收錄了 2003-2008 年巴哈姆特 / GameBase 社群整理的攻略。

2026 年 toni 把站搬到 GitHub Pages，用 1996 DOS 終端機綠的 retro 美學重新編排，並加入：

- 純前端存檔修改器（160 角色 × 192 bytes 完整 offset 表）
- 跨平台啟動器（Mac/Win/Linux 三平台）
- 從遊戲二進制檔案逆向解出的數值資料庫

舊站連結 → 新站：[from-old-site.html](from-old-site.html)

## 🙏 致謝

社群前輩多年無償整理：
- 黃政原・邵偉俊（1996 第三波官方攻略集作者）
- 黃政恭・邵偉倫（1996 中文版主編）
- 聶荊璇 / yjyyang / 李憲忠 / Yao Shih / Silver Angel / kkt_zzz（2003-2008 BBS 攻略整理）
- 1999 BBS 時代小蜜蜂 / 小傑 / Ertai

## ⚖️ 版權聲明

本站基於數位文化保存目的整理，遊戲本體著作權屬於 Artdink。站上技術文件為獨立逆向研究成果，遊戲內原版創意內容（圖像、劇情、完整名稱資料）僅作為研究者個人參考保留，不在本站公開展示。請至 Steam 商店購買正版俠客遊系列支持原作。
