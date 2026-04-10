#!/usr/bin/env python3
"""
批次產生舊 Google Sites（吟遊詩人的傳說 · 俠客遊小站）的新站 HTML 頁面。

讀 `工具/舊站_抓取_20260410/parsed/*.md` → 轉成語意 HTML → 塞進 retro 模板 →
寫到 LunaticDawn/{passage,luna3,luna4,steam,general,files}/*.html

舊站是 2010-2023 年 Google Sites 的內容，2026/04/10 由 toni 手動下載後解析為 markdown。
本腳本把那些 markdown 轉成純靜態 HTML，讓 GitHub Pages 可以直接 host。

使用方法：
  cd LunaticDawn && python3 _build_oldsite.py
"""

import html
import re
from pathlib import Path

ROOT = Path(__file__).parent.resolve()
MD_DIR = ROOT.parent / "工具" / "舊站_抓取_20260410" / "parsed"
FILES_DIR = ROOT / "files"

# ============================================================
# 頁面定義（10 個內容頁）
# ============================================================

# 小蜜蜂 / 小傑 / Ertai 的引用規則文字
ATTR_1999 = (
    '本頁內容為 <strong>小蜜蜂 / 小傑</strong> 1999 年原創心得。'
    '若要在別處引用，請來信 '
    '<a href="mailto:luntic.dawn@gmail.com">luntic.dawn@gmail.com</a> '
    '並在引用處註明出處。'
)
ATTR_ERTAI = (
    '本頁內容為 <strong>Ertai</strong> 2000 年 1 月 19 日原創心得（原聯絡信箱 '
    '<code>chiukm@ctimail3.com</code>，目前已失效）。'
    '引用請註明出處。'
)

PAGES = [
    # === passage/ === 前途道標 + 第三之書（5 頁：1 nav + 4 content）
    {
        "source": "前途道標攻略.md",
        "out": "passage/index.html",
        "kind": "subsite-index",
        "title": "前途道標攻略",
        "subtitle": "LUNATIC DAWN PASSAGE · LDE3",
        "tagline": "1999 年小蜜蜂 / 小傑的前途道標完整攻略 + 2001 年第三之書資料",
        "desc": "前途道標（Lunatic Dawn Passage，LDE3）是 1999 年推出的俠客遊資料片，"
                "2001 年又出了資料片「第三之書」。本站收錄小蜜蜂 / 小傑 / Ertai 等 1999-2000 年"
                "BBS 時代的原創攻略心得，以及 Morrowind / kkt_zzz 等社群開發者 2007 年前後釋出的修正檔與工具。",
        "cards": [
            ("intro.html", "入門篇：遊戲小常識",
             "屬性篇、職業篇、商店篇。四國屬性與魔法對應、戰士 / 魔法師 / 盜賊 / 僧侶的差異分析、旅社 / 武器店 / 寺院等六類商店介紹。",
             "作者：小蜜蜂 / 小傑 · 1999"),
            ("intermediate.html", "進階篇：冒險的開始",
             "委託篇（賺錢法則）——旅社接受的各類委託逐一分析：護送、討伐、搜索、購買、比武、救援、找人、決鬥、密使、代理、賭博、盜賊團……。",
             "作者：小蜜蜂 / 小傑 · 1999"),
            ("advanced.html", "終極篇：事件與結局",
             "特殊事件與結局、密技及奸招——天下第一武鬥大會、羅修丰、竹取、偷竊大法、角色拷貝、遊戲修改、1999/10 的原始 BBS 貼文。",
             "作者：小蜜蜂 / 小傑 · 1999"),
            ("treasure-hunter.html", "寶物獵人 Ertai 之心得",
             "草薙劍 / 八咫鏡 / 八尺瓊勾玉等 15+ 件特殊武器防具介紹、獵捕者 / 山賊 event 解析、前途道標遊戲謎團記錄。",
             "作者：Ertai · 2000/01/19"),
        ],
    },
    {
        "source": "入門篇.md",
        "out": "passage/intro.html",
        "kind": "content",
        "title": "入門篇：遊戲小常識",
        "subtitle": "前途道標攻略 · 小蜜蜂 / 小傑 · 1999",
        "attribution": ATTR_1999,
        "subsite": "前途道標",
        "subsite_index": "./",
    },
    {
        "source": "進階篇.md",
        "out": "passage/intermediate.html",
        "kind": "content",
        "title": "進階篇：冒險的開始",
        "subtitle": "前途道標攻略 · 小蜜蜂 / 小傑 · 1999",
        "attribution": ATTR_1999,
        "subsite": "前途道標",
        "subsite_index": "./",
    },
    {
        "source": "終極篇.md",
        "out": "passage/advanced.html",
        "kind": "content",
        "title": "終極篇：事件與結局",
        "subtitle": "前途道標攻略 · 小蜜蜂 / 小傑 · 1999",
        "attribution": ATTR_1999,
        "subsite": "前途道標",
        "subsite_index": "./",
    },
    {
        "source": "寶物獵人ertai之心得.md",
        "out": "passage/treasure-hunter.html",
        "kind": "content",
        "title": "寶物獵人 Ertai 之心得",
        "subtitle": "前途道標特殊裝備與事件 · Ertai · 2000",
        "attribution": ATTR_ERTAI,
        "subsite": "前途道標",
        "subsite_index": "./",
    },

    # === luna3/ === 未來之書（2 頁：1 nav + 1 content）
    {
        "source": None,
        "out": "luna3/index.html",
        "kind": "subsite-index",
        "title": "未來之書",
        "subtitle": "LUNATIC DAWN III · 1998",
        "tagline": "Lunatic Dawn III · The Book of Futures",
        "desc": "未來之書（Lunatic Dawn III，LD3）是 1998 年推出的俠客遊正統續作，"
                "四國改成羅馬魯國 / 中津國 / 日出國 / 依兒陶爾國。"
                "本站目前收錄 toni 整理的未來之書 + 前途道標 + 俠客遊 III 密技，"
                "以及 2000 年 12 月 19 日的 LD3 官方最新更新檔。",
        "cards": [
            ("cheats.html", "未來之書、前途道標及俠客遊 III 密技",
             "不死者喚出（Alt+F4）、隱藏人物名字（M.YOSHIDA!、Hydrogen!!、M.WADA、Caspia@@@、K.OOHARA!）、"
             "俠客遊 III 蜜米爾之書賺錢法（紫羅蘭草 + 忘憂果合成）。",
             "作者：toni"),
        ],
    },
    {
        "source": "未來之書、前途道標及俠客遊iii密技.md",
        "out": "luna3/cheats.html",
        "kind": "content",
        "title": "未來之書、前途道標及俠客遊 III 密技",
        "subtitle": "LUNATIC DAWN III · toni",
        "attribution": None,
        "subsite": "未來之書",
        "subsite_index": "./",
    },

    # === luna4/ === 俠客遊 IV（3 頁：1 nav + 2 content）
    {
        "source": None,
        "out": "luna4/index.html",
        "kind": "subsite-index",
        "title": "俠客遊 IV",
        "subtitle": "LUNATIC DAWN IV · 2003",
        "tagline": "Lunatic Dawn IV · 次元之門與連線系統",
        "desc": "俠客遊 IV（Lunatic Dawn IV，LD4）是 2003 年推出的系列最新作，"
                "加入了次元之門與 IP 連線功能。本站收錄 toni 的連線設定方法、"
                "鞠躬練功法，以及 Morrowind 作的 LunaticConsortia 輔助工具三個歷史版本。",
        "cards": [
            ("multiplayer.html", "俠客遊 IV 連線方法",
             "第三波伺服器關閉後的 IP 直連方法：次元之門設定 → 界面選 IP → LAN 自動檢索 → 光球右鍵 → 輸入對方 IP。",
             "作者：toni"),
            ("exp-farming.html", "俠客遊 IV 鞠躬練功法",
             "兩個 NPC 老闆（酒館男 / 酒館女）+ 兩個劇本 + 兩個任務的交叉設定法。完成任務同時訓練隊友。",
             "作者：toni"),
        ],
    },
    {
        "source": "俠客遊iv連線方法.md",
        "out": "luna4/multiplayer.html",
        "kind": "content",
        "title": "俠客遊 IV 連線方法",
        "subtitle": "LUNATIC DAWN IV · toni",
        "attribution": None,
        "subsite": "俠客遊 IV",
        "subsite_index": "./",
    },
    {
        "source": "俠客遊iv鞠躬練功法.md",
        "out": "luna4/exp-farming.html",
        "kind": "content",
        "title": "俠客遊 IV 鞠躬練功法",
        "subtitle": "LUNATIC DAWN IV · toni",
        "attribution": None,
        "subsite": "俠客遊 IV",
        "subsite_index": "./",
    },

    # === steam/ === Steam 版（2 頁：1 nav + 1 content）
    {
        "source": None,
        "out": "steam/index.html",
        "kind": "subsite-index",
        "title": "Steam 版俠客遊",
        "subtitle": "STEAM · ARTDINK · 2019+",
        "tagline": "2019 年 Artdink 在 Steam 重新發售的俠客遊系列",
        "desc": "2019 年 Artdink 在 Steam 重新發售了前途道標（Lunatic Dawn Passage）。"
                "這個版本是日文原版 + 英文介面，沒有繁體中文。"
                "本站提供 toni 整理的中文化步驟（含 DAEMON Tools Lite 虛擬光碟方法）。",
        "cards": [
            ("passage-chinese.html", "Steam 版前途道標中文化方法",
             "五個步驟：Steam 購買 → 下載中文化檔案 → 虛擬光碟設定 → 磁碟代號順序 → 套用修正檔。"
             "含 4 組購買流程截圖。",
             "作者：toni · 2019/12/11 更新"),
        ],
    },
    {
        "source": "Steam版前途道標中文化方法.md",
        "out": "steam/passage-chinese.html",
        "kind": "content",
        "title": "Steam 版前途道標中文化方法",
        "subtitle": "STEAM · LUNATIC DAWN PASSAGE · toni",
        "attribution": None,
        "subsite": "Steam 版",
        "subsite_index": "./",
    },

    # === general/ === 通用（3 頁：1 nav + 2 content）
    {
        "source": None,
        "out": "general/index.html",
        "kind": "subsite-index",
        "title": "通用資訊",
        "subtitle": "GENERAL · 跨作品資訊",
        "tagline": "字型、亂碼、社群討論等跨版本通用內容",
        "desc": "這裡收錄不屬於單一作品的跨版本資訊——字型與亂碼問題（橫跨俠客遊 II / III / IV / 前途道標）、"
                "社群討論區連結等。",
        "cards": [
            ("encoding-faq.html", "亂碼及字型問題",
             "Win 95/98/ME/XP/10 系統下的繁體中文字型設定、regedit SHIFTJIS(80) 登錄檔修正、"
             "WINHEX 編輯 LD95.EXE 的 C644242B80 → C644242B88 hex 修正。",
             "作者：toni、李逍遙、dera（蘇燃）、singlau（孤星劍）、hcmhcm"),
            ("community.html", "社群討論區",
             "巴哈姆特俠客遊系列討論板 / PTT 老遊戲板 / 遊戲基地俠客遊討論板外部連結。",
             "toni 整理"),
        ],
    },
    {
        "source": "亂碼及字型問題.md",
        "out": "general/encoding-faq.html",
        "kind": "content",
        "title": "亂碼及字型問題",
        "subtitle": "GENERAL · 跨作品字型 FAQ",
        "attribution": None,
        "subsite": "通用資訊",
        "subsite_index": "./",
    },
    {
        "source": "討論區.md",
        "out": "general/community.html",
        "kind": "content",
        "title": "社群討論區",
        "subtitle": "COMMUNITY · 外部論壇連結",
        "attribution": None,
        "subsite": "通用資訊",
        "subsite_index": "./",
    },

    # === files/ === 檔案庫（1 頁，自己生成）
    {
        "source": "檔案庫.md",
        "out": "files/index.html",
        "kind": "files-index",
        "title": "檔案庫",
        "subtitle": "FILE LIBRARY · 歷史附件 + Google Drive 連結",
        "attribution": None,
        "subsite": None,
        "subsite_index": None,
    },
]


# ============================================================
# Markdown → HTML 轉換（只處理我們需要的子集）
# ============================================================

def md_inline(text: str) -> str:
    """處理行內 markdown：**bold**、[text](url)、html escape。"""
    # 先 escape HTML 特殊字元
    text = html.escape(text)
    # **bold** → <strong>（最長匹配優先）
    text = re.sub(r"\*\*([^*]+?)\*\*", r"<strong>\1</strong>", text)
    # [text](url) → <a>
    def linkify(m):
        link_text = m.group(1)
        url = m.group(2)
        # escape 後的 & 要處理
        url_attr = url.replace('"', "&quot;")
        external = not url.startswith(("#", "./", "../", "/", "mailto:"))
        extra = ' target="_blank" rel="noopener"' if external and url.startswith("http") else ""
        return f'<a href="{url_attr}"{extra}>{link_text}</a>'
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", linkify, text)
    return text


def pre_normalize_old_bbs(md: str) -> str:
    """把 1999 年 BBS 格式的偽 heading 轉成真 markdown heading。

    舊站小蜜蜂 / 小傑的攻略是從 BBS 貼文搬過來的，當時沒有 markdown，所以用純
    文字 + 冒號來分 section。難點是：parser 把原本的換行都吃掉了，所以 `單元一：
    旅社任務` 和接下來的內文黏在同一行變成 5000+ 字的超大段落。

    處理的幾種 pattern：
      - `第一課：屬性篇`           → ## 第一課：屬性篇（Format A：標題在冒號後）
      - `第二課裝備篇：吸收...`    → ## 第二課 裝備篇 + 新段落吸收...（Format B：標題在冒號前）
      - `單元一：旅社任務旅社可接` → ### 單元一：旅社任務 + 新段落旅社可接...（硬切）
      - `其一：旅社`               → ### 其一：旅社（h4）
      - `第一部份：如何召伙伴在...` → #### 第一部份：如何召伙伴 + 新段落在...（硬切）
      - `1.不死者喚出：`           → ### 1.不死者喚出（編號小節）
    入門篇的商店篇把 6 個「其X：」塞在同一個超大 `<p>` 裡，所以我們還要**切斷段落**
    並把 `其X：` 挪出來變獨立標題。
    """
    # 0. 進階篇特有的 inline 段落分割——parser 吃掉換行後，單元X + 第X部份 + 其X
    #    的標題跟內文黏在同一行，沒有分隔符號可用 regex，所以硬做字串 replace。
    #    只有這 5 組 substring 會被取代，其他檔案不受影響。
    inline_splits = [
        # 單元一、單元二（進階篇 委託篇）
        (
            "單元一：旅社任務旅社可接的任務",
            "\n\n### 單元一：旅社任務\n\n旅社可接的任務",
        ),
        (
            "單元二：暗黑同業公會之任務一般旅行家",
            "\n\n### 單元二：暗黑同業公會之任務\n\n一般旅行家",
        ),
        # 第一部份 / 第二部份 / 第三部分（進階篇 伙伴篇 的子章節）
        (
            "第一部份：如何召伙伴在商店篇",
            "\n\n#### 第一部份：如何召伙伴\n\n在商店篇",
        ),
        (
            "第二部份：如何挑選伙伴因為隊伍",
            "\n\n#### 第二部份：如何挑選伙伴\n\n因為隊伍",
        ),
        (
            "第三部分：生離死別戰鬥",
            "\n\n#### 第三部分：生離死別\n\n戰鬥",
        ),
    ]
    for old, new in inline_splits:
        md = md.replace(old, new)

    # 1A. 第N課 Format B：`第N課 XXX篇：內文` 或 `第N課XXX篇：內文`
    #     適用於：進階篇（裝備篇/伙伴篇/求婚篇，內文黏在冒號後）、
    #              終極篇（第一課 事件篇：（特殊事件與結局））、
    #              進階篇第一課（第一課 委託篇：（賺錢法則））
    #     關鍵：篇字作為 title 結尾的分隔符（1999 年小蜜蜂每個 section 都叫 XX篇）
    def _split_ke(m):
        num = m.group(1)
        title = m.group(2)
        rest = m.group(3).strip()
        if rest:
            return f"\n\n## 第{num}課 {title}\n\n{rest}"
        return f"\n\n## 第{num}課 {title}"

    md = re.sub(
        r"第([一二三四五六七八九十])課[ \u3000]?([^\n：:，。]{1,10}篇)[:：]([^\n]*)",
        _split_ke,
        md,
    )
    # 1B. 第N課 Format A：整行就是 heading（如入門篇 `第一課：屬性篇`）
    #     或沒有篇後綴（如終極篇 `第二課 密技及奸招：`）
    md = re.sub(
        r"^(第[一二三四五六七八九十]課[^\n]*)$",
        r"## \1",
        md,
        flags=re.MULTILINE,
    )
    # 2. 行首的 "單元N：XXX" → ### heading（Format A，入門/終極篇用）
    md = re.sub(
        r"^(單元[一二三四五六七八九十][:：][^\n]*)$",
        r"### \1",
        md,
        flags=re.MULTILINE,
    )
    # 3. 行首的 "其N：XXX" → ### heading
    md = re.sub(
        r"^(其[一二三四五六七八九十][:：][^\n]*)$",
        r"### \1",
        md,
        flags=re.MULTILINE,
    )
    # 4. 段落中的 "其N：" 偽 heading（入門篇 商店篇把 6 個塞在同一段）
    #    在 。！？ 之後插入 blank line，並把 `其N：` 用 **bold** 強調
    md = re.sub(
        r"(?<=[。！？])(其[一二三四五六七八九十][:：])",
        r"\n\n**\1**",
        md,
    )
    # 5. 行首的 "N. 標題：..." 或 "N．「標題」：..." 編號小節
    #    (終極篇事件篇、進階篇求婚篇、luna3 密技都用這個 pattern)
    #    限 1-2 位數字避免匹配年份 (如 1998.12.19)，標題限最長 50 字，必須以冒號結尾
    #    允許嵌入半形逗號或中文逗號（進階篇有「2.到寺院調整自己屬性，使自己的屬性與意中人接近些：」
    #    這種複合標題）。用 lazy 匹配以確保抓到第一個冒號就停。
    #    把「編號 + 標題 + 冒號」當 h4 heading，冒號之後的內文切到新段落
    def _numbered_heading(m):
        head = m.group(1)
        rest = m.group(2).strip()
        if rest:
            return f"### {head}\n\n{rest}"
        return f"### {head}"

    md = re.sub(
        r"^(\d{1,2}[\.．]\s*[^\n：:。]{2,50}?[:：])([^\n]*)$",
        _numbered_heading,
        md,
        flags=re.MULTILINE,
    )
    return md


def md_to_html(md: str) -> str:
    """把 parsed 過的 markdown 轉成語意 HTML（<h2>/<h3>/<p>/<ul>/<a>/<strong>）。

    假設：markdown 來自 _parse_oldsite.py 的輸出，結構相對簡單——
    blank line separated paragraphs、`# heading`、偶爾的 `- list item`。
    """
    lines = md.split("\n")
    out = []
    i = 0
    in_list = False

    def close_list():
        nonlocal in_list
        if in_list:
            out.append("</ul>")
            in_list = False

    while i < len(lines):
        line = lines[i].rstrip()

        if not line:
            close_list()
            i += 1
            continue

        # # heading → 根據 # 數量變 h2 / h3 / h4
        m = re.match(r"^(#+)\s+(.+)$", line)
        if m:
            close_list()
            level = min(len(m.group(1)) + 1, 4)  # # → h2, ## → h3, ### → h4
            text = md_inline(m.group(2))
            out.append(f"<h{level}>{text}</h{level}>")
            i += 1
            continue

        # - list item
        if line.startswith("- "):
            if not in_list:
                out.append('<ul>')
                in_list = True
            text = md_inline(line[2:])
            out.append(f"  <li>{text}</li>")
            i += 1
            continue

        # 一般段落：收集直到 blank line 或 heading
        close_list()
        para_lines = [line]
        i += 1
        while i < len(lines):
            nxt = lines[i].rstrip()
            if not nxt or nxt.startswith("#") or nxt.startswith("- "):
                break
            para_lines.append(nxt)
            i += 1
        para_text = " ".join(para_lines).strip()
        if para_text:
            out.append(f"<p>{md_inline(para_text)}</p>")

    close_list()
    return "\n".join(out)


def strip_parser_preamble(md: str) -> str:
    """拿掉解析器加在每個 md 檔前面的 metadata block（到第一個 `---` 為止）+ 重複標題。

    body 開頭常有重複：
      # 入門篇
      入門篇：遊戲小常識        ← 這一行是 1999 年 BBS 貼文的 subtitle，要跳過

    策略：先拿掉第一個 `# heading`，再跳過緊接在它後面的「看起來像 subtitle 的
    單行純文字」（短於 50 字元、包含冒號、沒有 markdown 標記）。
    """
    # --- 切頭：拿掉 parser metadata preamble（到第一個 `---` 為止）---
    parts = md.split("---", 1)
    body = parts[1] if len(parts) == 2 else md
    body = body.lstrip("\n ")
    lines = body.split("\n")

    # --- 切尾：parser 會在結尾加「## 頁面圖片」+ 本地圖檔清單，但那些檔案都不存在 ---
    trailing_markers = ("## 頁面圖片", "## 頁面 embed", "## 頁面embed")
    cut_index = None
    for idx, line in enumerate(lines):
        stripped = line.strip()
        # 偵測到「---」後緊接著 `## 頁面圖片` 的 pattern → 從 `---` 那行開始切掉
        if stripped.startswith(trailing_markers):
            cut_index = idx
            # 往回看是否有前導的 `---`，一起切
            j = idx - 1
            while j >= 0 and not lines[j].strip():
                j -= 1
            if j >= 0 and lines[j].strip() == "---":
                cut_index = j
            break
    if cut_index is not None:
        lines = lines[:cut_index]

    result = []
    # 三階段狀態機：
    #   eating_h1     — 仍在吃開頭連續的 `# heading` 行（LunaticDawn 有 2 個，Luna3 cheats 也有 2 個）
    #   check_subtitle — H1 吃完後，下一個非空行可能是重複的 subtitle 純文字
    #   normal        — 一般內容
    state = "eating_h1"

    for line in lines:
        stripped = line.strip()

        if state == "eating_h1":
            if not stripped:
                continue  # 空行跳過
            if stripped.startswith("# "):
                continue  # H1 跳過
            # 第一個非空、非 H1 的行：轉換狀態
            state = "check_subtitle"
            # 不 continue，讓下面的 check_subtitle 分支決定

        if state == "check_subtitle":
            state = "normal"  # 無論如何都只檢查一次
            # 判斷：短行純文字 + 沒有 markdown 標記 → 視為重複 subtitle，跳過
            if (
                stripped
                and len(stripped) < 50
                and not stripped.startswith(("#", "-", "*", "(", "[", ">"))
            ):
                continue

        result.append(line)

    return "\n".join(result).lstrip("\n ")


# ============================================================
# HTML 模板
# ============================================================

BASE_HEAD = """<!DOCTYPE html>
<html lang="zh-Hant">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · 吟遊詩人的傳說</title>
<meta name="description" content="{meta_desc}">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Noto+Serif+TC:wght@400;700;900&family=Noto+Sans+Mono&display=swap" rel="stylesheet">
<link rel="stylesheet" href="../assets/css/wuxia.css">
</head>
<body>
<div class="wrap">

<header class="site-header">
  <div class="header-inner">
    <div>
      <h1 class="pixel">{title}</h1>
      <div class="header-sub">{subtitle}</div>
    </div>
    <div class="header-sub header-right">
      <div><a href="../">◀ 回主站</a></div>
{header_right_extra}    </div>
  </div>
</header>
"""

BASE_FOOT = """
<footer class="site-footer">
  <div>
    所有 1999-2000 年原創內容版權屬於各原作者；如需引用請參考頁首的引用規則。
    本站由 toni 整理重建，作為數位文化遺產保存。
  </div>
  <div class="footer-big">｢ 吟遊詩人的傳說 · 俠客遊 LUNATIC DAWN ｣</div>
  <div>
    <a href="../">◀ 主站</a> ·
    <a href="../files/">檔案庫</a> ·
    <a href="https://github.com/toniLiuMVP/LunaticDawn" target="_blank" rel="noopener">GitHub</a> ·
    維護：toni
  </div>
</footer>

</div>
</body>
</html>
"""


def render_content_page(page: dict, md: str) -> str:
    """渲染 10 個內容頁（passage/intro、luna4/multiplayer 等）。"""
    body_md = strip_parser_preamble(md)
    body_md = pre_normalize_old_bbs(body_md)
    body_html = md_to_html(body_md)

    meta_desc = f"{page['title']} — {page['subtitle']}。吟遊詩人的傳說 · 俠客遊 Lunatic Dawn 資料站。"

    header_right_extra = (
        f'      <div><a href="{page["subsite_index"]}">▸ {page["subsite"]}索引</a></div>\n'
    )

    breadcrumb = (
        f'<div class="breadcrumb">\n'
        f'  <a href="../">吟遊詩人的傳說</a> / '
        f'<a href="{page["subsite_index"]}">{page["subsite"]}</a> / '
        f'<span class="dim">{page["title"]}</span>\n'
        f'</div>\n'
    )

    attribution_html = ""
    if page.get("attribution"):
        attribution_html = f'<div class="attribution">{page["attribution"]}</div>\n'

    content_section = (
        f'<section class="panel">\n'
        f'  <div class="panel-title">[ {html.escape(page["title"].upper())} ]</div>\n'
        f'  {attribution_html}'
        f'  <div class="prose">\n{body_html}\n  </div>\n'
        f'</section>\n'
    )

    nav_section = f'''
<section class="panel">
  <div class="panel-title">[ NAVIGATION ]</div>
  <p>
    <a href="{page["subsite_index"]}">◀ 回 {page["subsite"]} 索引</a> ·
    <a href="../">▸ 主站</a> ·
    <a href="../files/">▸ 檔案庫</a>
  </p>
</section>
'''

    head = BASE_HEAD.format(
        title=html.escape(page["title"]),
        subtitle=html.escape(page["subtitle"]),
        meta_desc=html.escape(meta_desc),
        header_right_extra=header_right_extra,
    )

    return head + breadcrumb + content_section + nav_section + BASE_FOOT


def render_subsite_index(page: dict) -> str:
    """渲染 5 個子站 index.html（passage/luna3/luna4/steam/general）。"""
    meta_desc = f"{page['title']} — {page['tagline']}"
    header_right_extra = ""

    breadcrumb = (
        f'<div class="breadcrumb">\n'
        f'  <a href="../">吟遊詩人的傳說</a> / '
        f'<span class="dim">{page["title"]}</span>\n'
        f'</div>\n'
    )

    about_section = (
        f'<section class="panel">\n'
        f'  <div class="panel-title">[ ABOUT ]</div>\n'
        f'  <p class="amber">{html.escape(page["tagline"])}</p>\n'
        f'  <p>{html.escape(page["desc"])}</p>\n'
        f'</section>\n'
    )

    # 卡片清單
    cards_html = '<section class="panel">\n  <div class="panel-title">[ CONTENT ]</div>\n'
    cards_html += f'  <h2>{html.escape(page["title"])}頁面</h2>\n'
    cards_html += '  <div class="card-grid">\n'
    for href, title, desc, meta in page["cards"]:
        cards_html += (
            f'    <a class="card" href="{href}">\n'
            f'      <span class="card-title">▸ {html.escape(title)}</span>\n'
            f'      <span class="card-desc">{html.escape(desc)}</span>\n'
            f'      <span class="card-meta">{html.escape(meta)}</span>\n'
            f'    </a>\n'
        )
    cards_html += '  </div>\n</section>\n'

    nav_section = '''
<section class="panel">
  <div class="panel-title">[ NAVIGATION ]</div>
  <p>
    <a href="../">◀ 主站</a> ·
    <a href="../files/">▸ 檔案庫</a> ·
    <a href="../luna2/guides/">▸ 俠客遊 II 攻略</a>
  </p>
</section>
'''

    head = BASE_HEAD.format(
        title=html.escape(page["title"]),
        subtitle=html.escape(page["subtitle"]),
        meta_desc=html.escape(meta_desc),
        header_right_extra=header_right_extra,
    )

    return head + breadcrumb + about_section + cards_html + nav_section + BASE_FOOT


def render_files_index(page: dict, md: str) -> str:
    """渲染檔案庫 index（同時列出 Google Drive 連結 + 本地 44 個歷史附件）。"""
    body_md = strip_parser_preamble(md)
    body_html = md_to_html(body_md)

    meta_desc = "吟遊詩人的傳說 · 俠客遊系列檔案庫——Google Drive 連結 + 1998-2007 年歷史附件。"
    header_right_extra = ""

    breadcrumb = (
        '<div class="breadcrumb">\n'
        '  <a href="../">吟遊詩人的傳說</a> / '
        '<span class="dim">檔案庫</span>\n'
        '</div>\n'
    )

    drive_section = (
        '<section class="panel">\n'
        '  <div class="panel-title">[ GOOGLE DRIVE · 最新版 ]</div>\n'
        '  <p class="amber">由 toni 2019-2023 年持續維護的最新版本</p>\n'
        '  <p class="muted">⭐ 所有 Google Drive 連結都是原舊站檔案庫頁的直接抄本，'
        '請保持以下幾點以避免遊戲問題：</p>\n'
        '  <ul>\n'
        '    <li>遊戲資料夾路徑盡量簡潔並使用英文（例：<code>C:\\ARTDINK\\Lde3</code>）</li>\n'
        '    <li>相關輔助程式放在遊戲資料夾內執行</li>\n'
        '  </ul>\n'
        f'  <div class="prose">\n{body_html}\n  </div>\n'
        '</section>\n'
    )

    # 本地 44 個歷史附件清單
    local_section = build_local_attachments_section()

    nav_section = '''
<section class="panel">
  <div class="panel-title">[ NAVIGATION ]</div>
  <p>
    <a href="../">◀ 主站</a> ·
    <a href="../passage/">▸ 前途道標</a> ·
    <a href="../luna2/guides/">▸ 俠客遊 II 攻略</a>
  </p>
</section>
'''

    head = BASE_HEAD.format(
        title=html.escape(page["title"]),
        subtitle=html.escape(page["subtitle"]),
        meta_desc=html.escape(meta_desc),
        header_right_extra=header_right_extra,
    )

    return head + breadcrumb + drive_section + local_section + nav_section + BASE_FOOT


def build_local_attachments_section() -> str:
    """掃描 files/{luna2,passage,luna3,luna4,steam} 生成 44 檔的歷史附件區。"""
    SECTIONS = [
        ("luna2", "俠客遊 II 歷史附件", "1996-2007 年俠客遊 II 社群修正檔、工具與 1998 BBS 資料包"),
        ("passage", "前途道標 + 第三之書歷史附件", "1999-2007 年前途道標相關社群開發者工具"),
        ("luna3", "未來之書歷史附件", "Lunatic Dawn III 官方更新檔"),
        ("luna4", "俠客遊 IV 歷史附件", "Lunatic Dawn IV 官方更新檔與 LunaticConsortia 工具"),
        ("steam", "Steam 版前途道標截圖", "Steam 版購買流程與中文化教學截圖"),
    ]
    out = [
        '<section class="panel">\n'
        '  <div class="panel-title">[ HISTORICAL ATTACHMENTS · 1998-2007 ]</div>\n'
        '  <p class="amber">44 個從 Google Sites Classic 匯出的歷史附件</p>\n'
        '  <p class="muted">這些都是舊站 2010-2023 年間保存的原始檔案，'
        '檔名保留原樣（含大小寫、空白、甚至 .7z.7z 雙副檔名）作為歷史考證。'
        '詳細檔案清單見 <a href="README.md">README.md</a>。</p>\n'
    ]

    for folder, heading, desc in SECTIONS:
        folder_path = FILES_DIR / folder
        if not folder_path.exists():
            continue
        files = sorted(f for f in folder_path.iterdir() if f.is_file())
        out.append(f'  <h2>{html.escape(heading)}（{len(files)} 檔）</h2>\n')
        out.append(f'  <p class="dim">{html.escape(desc)}</p>\n')
        out.append('  <ul class="file-list">\n')
        for f in files:
            size = f.stat().st_size
            size_s = fmt_size(size)
            fn_display = html.escape(f.name)
            # href 要 URL-encode 空白
            href = f"{folder}/{f.name}".replace(" ", "%20")
            out.append(
                f'    <li>\n'
                f'      <span class="fname"><a href="{html.escape(href)}">{fn_display}</a></span>\n'
                f'      <span class="fsize">{size_s}</span>\n'
                f'    </li>\n'
            )
        out.append('  </ul>\n')

    out.append('</section>\n')
    return "".join(out)


def fmt_size(n: int) -> str:
    if n < 1024:
        return f"{n} B"
    if n < 1024 * 1024:
        return f"{n // 1024} KB"
    return f"{n / (1024 * 1024):.1f} MB"


# ============================================================
# 主流程
# ============================================================

def main():
    print(f"▶ 讀取 markdown 自：{MD_DIR}")
    print(f"▶ 寫出 HTML 至：{ROOT}")
    print()

    total = 0
    for page in PAGES:
        out_path = ROOT / page["out"]
        out_path.parent.mkdir(parents=True, exist_ok=True)

        if page["kind"] == "subsite-index":
            html_out = render_subsite_index(page)
        elif page["kind"] == "content":
            md_path = MD_DIR / page["source"]
            if not md_path.exists():
                print(f"  ⚠️  找不到來源檔：{md_path}")
                continue
            md = md_path.read_text(encoding="utf-8")
            html_out = render_content_page(page, md)
        elif page["kind"] == "files-index":
            md_path = MD_DIR / page["source"]
            md = md_path.read_text(encoding="utf-8") if md_path.exists() else ""
            html_out = render_files_index(page, md)
        else:
            print(f"  ⚠️  未知 kind：{page['kind']}")
            continue

        out_path.write_text(html_out, encoding="utf-8")
        rel = out_path.relative_to(ROOT)
        print(f"  ✓  {str(rel):40s} ({len(html_out):>6,} bytes)")
        total += 1

    print()
    print(f"✅ 完成！共產生 {total} 個 HTML 檔")


if __name__ == "__main__":
    main()
