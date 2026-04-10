# 俠客遊 · Lunatic Dawn 系列資料站

> 「吟遊詩人的傳說」— 台灣 DOS 時代 Artdink 經典 RPG 系列的玩家資料庫與工具站
>
> 由 toni（@toniLiuMVP）維護 — 接續 2004 年 GameBase 遊戲基地與巴哈姆特俠客遊討論板的時代遺產

---

## 📖 本站涵蓋

| 作品 | 年代 | 本站狀態 |
|------|------|----------|
| 俠客遊 II (Lunatic Dawn II) | 1996 | ✅ 攻略 + 物品 + 存檔修改器 |
| 俠客遊 III (Lunatic Dawn III) | 1998 | 🚧 規劃中 |
| 俠客遊 IV (Lunatic Dawn IV) | 1999 | 🚧 規劃中 |
| 未來之書 (Future Book) | - | 🚧 規劃中 |
| 前途道標 (Road Signs) | - | 🚧 規劃中 |

## 🛠 工具

- **[俠客遊 II 存檔修改器](./luna2/save-editor.html)** — 瀏覽器版，純 HTML+JS，跨 macOS / Windows / Linux，不用安裝
- **[俠客遊 II 完整攻略](./luna2/guides/)** — 整合 2004-2008 年社群前輩心血
- **遊戲啟動器** — Mac `.command` + Windows `.bat` 一鍵啟動，自動處理 DOSBox-X 音效設定

## 🙏 致謝（2004-2008 GameBase / 巴哈姆特討論板前輩）

| 貢獻 | 作者 |
|------|------|
| 俠客遊 II 攻略原作者 | 青衫 |
| 存檔格式逆向工程 | 聶荊璇（殘楓網） |
| 原版 Windows 修改器 | Morrowind |
| 修改筆記（1996） | 伊達政宗、Silver Angel |
| 精確 byte offset 文件 | 李憲忠 |
| 人物起始能力表 | ocrice (yukihiro) |
| 攻略整理/補充 | 劍俠天才、那伽龍、yjyyang、aldalave11127、jo（謎樣的大叔）、raclim（林秀奕）、PhilJane（矮子小豪）、toni |

## 🎮 執行原版遊戲

本 repo 不包含遊戲本體（版權因素）。如果你已有俠客遊 II 原版檔案，可使用本站的啟動器：

- **Mac**：雙擊 `啟動俠客遊II.command`
- **Windows**：雙擊 `啟動俠客遊II.bat`

兩個啟動器都會自動呼叫 [DOSBox-X](https://dosbox-x.com/)，並已解決 1996 年的經典 640KB 記憶體地獄問題（使用 `LH` 指令把 MIDPAK + SB16 DIGPAK TSR 載入 UMB）。

## 📜 授權

本站程式碼為 MIT。社群整理的攻略、物品資料、存檔解析文件版權屬於原作者，本站僅為**數位文化遺產保存**目的整理展示。如原作者希望撤除，請開 Issue 告知。

---

*「俠客遠行不忘舊路，吟遊詩人傳說永存。」*
