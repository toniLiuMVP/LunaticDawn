發布規則 (PUBLISHING.md)
本網站採取「本機完整、公開精簡」的雙層架構。所有逆向工程的完整成果永遠保留在本機作為研究
檔案，但發布到 GitHub Pages 的版本必須符合以下篩選規則。
設計原則
逆向工程的技術文件可公開，逆向解出的「原版受著作權保護內容」不可公開。
分界線：技術知識（格式、演算法、結構）=  可公開；原版創意內容（圖像、劇情文字、完整名稱列
表）= 僅本機保留。
一、目錄結構
LunaticDawn/
├── _local/                    必須在 .gitignore，永不上傳
│   ├── sprites_full/          所有解出的 PNG（全套）
│   ├── texts_full/            完整 4400+ 文字 dump
│   ├── game_data_full.json    完整資料庫
│   ├── source_binaries/       原版遊戲檔案（自有正版備份）
│   └── extracted_raw/         逆向工程原始輸出
├── tools/                     公開：逆向工具與腳本
│   ├── extract/               解碼器（純技術，無遊戲資料）
│   └── build/
│       ├── build_public.py    從 _local 生成公開版
│       └── filter_rules.py    篩選規則
├── docs/                      公開：技術筆記
│   ├── enc-format.md
│   ├── ddt-format.md
│   └── mst-format.md
├── luna2/                     公開：發布內容
│   ├── database/              篩選後資料
│   ├── guides/                社群攻略
│   ├── launcher/              啟動器
│   └── ez/                    懶人包
├── .gitignore
└── PUBLISHING.md              本檔
1 / 5


二、.gitignore 必須包含
_local/
*.local.json
*_full.json
sprites_full/
texts_full/
extracted_raw/
source_binaries/
三、內容分類規則
A 類：絕對只在本機（_local/ only）
以下內容禁止出現在 git 追蹤的任何檔案中，也禁止出現在 build_public.py 的輸出中：
所有從遊戲檔案解出的 sprite / 圖像 PNG（KEN00-07, POS0-1, SPOTAMA, MESHPL, RIATCUR,
HOLEITEM, FENIX, DAIZA, GOZZ, 16TON, UZU, YADARAKE, KIRKIR, STR_A 字型表等所有 .DDT 衍
生圖）
遊戲內劇情文字：謠言、城堡對話、結局訊息
工作人員名單（credits 文字）
完整 4400 筆文字 dump
B 類：篩選後可上傳（須過 filter_rules.py）
items 資料庫：保留所有數值欄位（價格、命中、攻速、攻擊、防禦、體格等）；名稱欄位處理三
選一（toni 決定）：
改用代號（ITEM_001 ~ ITEM_456）
保留日文原名但每筆需附 toni 自寫評論（轉為「攻略內容」性質）
全數隱藏，只留數值
monsters 資料庫：同 items 規則處理
magics、hissatsu、dungeons：同 items 規則處理
palette gallery：只保留主 palette（LUNA2.PLT），其餘移到 _local
C 類：完整可上傳（不需篩選）
技術格式文件（ENC XOR key、DDT EGA 4-plane 結構、MST record 切片邏輯）。這些是技術知
識，不是受保護內容
• 
• 
• 
• 
• 
• 
• 
• 
• 
• 
• 
• 
2 / 5


解碼器原始碼（parse_mst.py、decode_enc.py、decode_ddt.py 等）。條件：腳本本身不能內
嵌遊戲資料，只能描述演算法
社群攻略文字（guides/ 目錄，2004-2008 BBS 來源）
啟動器腳本、Luna2_EZ 懶人包（不含遊戲本體）
存檔修改器（save-editor.html）
toni 自寫的 FAQ、教學、安裝說明
公式與機制研究（HP/MP/STM 計算公式等）
四、給 Claude Code 的執行指示
4.1 新增資料時的預設行為
當 toni 提供新解出的內容（圖像、文字、新欄位等），預設行為為「先放到 _local/」，再由 toni 確
認是否要公開。
具體：
解碼出新 sprite → 寫入 _local/sprites_full/
解出新文字資料 → 寫入 _local/texts_full/
解析出新欄位 → 寫入 _local/game_data_full.json
4.2 修改公開頁面前的檢查
修改 luna2/database/  下任何頁面前，必須：
確認資料來源是 tools/build/build_public.py  產生的篩選版
不可直接從 _local/game_data_full.json  讀取
不可在 HTML / JS 中硬編碼 A 類禁止內容
4.3 commit 前的自動檢查
在 git commit 前執行以下檢查：
• 
• 
• 
• 
• 
• 
• 
• 
• 
1. 
2. 
3. 
3 / 5


# 1. 確認沒有 _local/ 下的檔案被加進暫存區
git diff --cached --name-only | grep -E '^_local/' && exit 1
# 2. 確認公開的 game_data.json 不含 A 類關鍵字
grep -E '結局|エンディング|スタッフ|credits' luna2/database/*.json && exit 1
# 3. 確認 sprites/ 目錄為空或不存在
[ -d luna2/database/sprites ] && \
  [ -n "$(ls luna2/database/sprites)" ] && exit 1
4.4 build_public.py 的篩選邏輯
從 _local/game_data_full.json  產生 luna2/database/game_data.json ：
移除整個 texts.dialogues （城堡對話）
移除整個 texts.rumors （謠言）
移除整個 texts.endings （結局訊息）
移除整個 texts.credits （工作人員名單）
保留 texts.item_names 、texts.monster_names 、texts.dungeon_names ，但依 toni 對 B 類的選擇
處理（代號 / 評論版 / 隱藏）
保留所有數值欄位
不複製任何 sprite 檔案到公開目錄
4.5 不可違反的硬規則
任何情況下不可進行的動作：
將 _local/  內容 commit 到 git
將遊戲執行檔（LUNA2.EXE 等）放入 repo 任何位置
將解出的 sprite PNG 放到 luna2/  任何子目錄
將完整劇情文字、結局、credits 放到公開頁面
在公開的 markdown / HTML 中嵌入 A 類內容
揭露 Steam DRM 繞過方法、序號驗證繞過方法
提供 ROM 或破解版下載連結
五、版權聲明文字（公開頁面用）
所有公開頁面 footer 統一使用以下措辭：
• 
• 
• 
• 
• 
• 
• 
• 
• 
• 
• 
• 
• 
• 
4 / 5


本站基於數位文化保存目的整理，遊戲本體著作權屬於 Artdink。站上技術文件為獨立逆向研究
成果，遊戲內原版創意內容（圖像、劇情、完整名稱資料）僅作為研究者個人參考保留，不在本
站公開展示。請至 Steam 商店購買正版俠客遊系列支持原作。若您是攻略原作者並希望授權變更
或撤除，請至 GitHub Issues 聯繫。
禁止使用的措辭：
「事實在二進制裡」（暗示原版內容是事實，法律上不成立）
「逆向解析的完整資料庫」（公開頁面已不是「完整」）
「攻略文件版權屬於原作者，本站僅...」（隱含 opt-out 邏輯）
六、有疑慮時的預設
當 Claude Code 不確定某內容應屬 A / B / C 哪一類時，預設視為 A 類（只在本機保留），等待 toni
明確判斷。
不確定時不要主動公開。寧可漏放可公開的內容，不要誤放不可公開的內容。
• 
• 
• 
5 / 5
