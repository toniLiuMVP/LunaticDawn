#!/usr/bin/env python3
"""
批次產生俠客遊 II 攻略 HTML 頁面。
把 工具/_utf8/ 下的 TXT 讀進來 → HTML escape → 塞進 retro 模板 → 寫到 luna2/guides/
"""

import html
from pathlib import Path

# 專案路徑
ROOT = Path(__file__).parent.resolve()
TXT_DIR = ROOT.parent / "工具" / "_utf8"
OUT_DIR = ROOT / "luna2" / "guides"

# 攻略頁清單
GUIDES = [
    {
        "out": "walkthrough.html",
        "title": "俠客遊 II 主攻略",
        "subtitle": "青衫主攻略 · 六國地理與任務流程",
        "author": "青衫",
        "author_tag": "ABOUT · BY 青衫",
        "intro": (
            "青衫主攻略是 2004-2008 年間俠客遊 II 最主要的中文攻略文件，涵蓋六國"
            "（薩城、歐德普克、古雷那密、葛雷斯坦、邁瑟、弗雷）的地理、任務流程、"
            "NPC 對話、事件觸發條件。原文來自 "
            "<a href=\"http://ashbone.daiseki.com.tw/chiuinan/\" target=\"_blank\" rel=\"noopener\">青衫的俠客遊小站</a>，"
            "由 2004-2008 年社群前輩整理保存至今。"
        ),
        "source_files": ["Luna2攻略.txt"],
    },
    {
        "out": "items-towns.html",
        "title": "物品與城鎮資料",
        "subtitle": "武器 / 防具 / 消耗品 / 六國商店資料",
        "author": "社群整理",
        "author_tag": "ITEMS & TOWNS",
        "intro": (
            "本站最大的資料庫——完整物品代碼表、武器 / 防具 / 消耗品屬性、"
            "六國城鎮商店商品清單。搭配存檔修改器可以對照物品編號直接放進 CHRITEM.SAV。"
        ),
        "source_files": ["Luna2物品與城鎮資料.txt"],
    },
    {
        "out": "save-format.html",
        "title": "存檔格式解析",
        "subtitle": "聶荊璇 2006 v4.1 · byte-level 逆向工程",
        "author": "聶荊璇（殘楓網）",
        "author_tag": "SAVE FORMAT · BY 聶荊璇",
        "intro": (
            "聶荊璇（殘楓網）2006 年發表的 v4.1 版完整存檔格式文件。涵蓋 13 個 .SAV 檔案的"
            "byte-level 結構——包括 LUNACHAR.SAV（角色）、CHRITEM.SAV（物品）、"
            "OYABUN.SAV（老大）、SCENDATA.SAV（場景）、SHOPITEM.SAV（商店）、"
            "TOWNDATA.SAV / TOWNITEM.SAV（城鎮）、DUNGDATA.SAV（地牢）、"
            "KOBUN.SAV（小弟）、LUNAHEAD.SAV、VDD.SAV / VDDKEY.SAV、HIST.SAV。"
            "本站存檔修改器的 byte offset 表即以此文件為主要參考。"
        ),
        "source_files": ["Luna2存檔解析.txt"],
    },
    {
        "out": "modifier-notes.html",
        "title": "修改筆記",
        "subtitle": "1996 伊達政宗 + Silver Angel · 李憲忠",
        "author": "伊達政宗、Silver Angel、李憲忠",
        "author_tag": "MODIFIER NOTES · 1996",
        "intro": (
            "本文件包含兩組獨立的修改筆記：<br><br>"
            "<strong class=\"amber\">1996.07.30 伊達政宗 &amp; Silver Angel</strong>——"
            "LUNA2.EXE 密碼破解、能力值 / 法術 / 家系 / 弱點的 byte layout、"
            "武器修改的 FPE 技巧。<br><br>"
            "<strong class=\"amber\">李憲忠 (An-Liang Lo)</strong>——精確到 byte 的 offset "
            "對照表：Pos16 年齡、Pos20-22 金錢、Pos42-47 HP/MP/STM 上限、Pos54-61 8 項能力、"
            "Pos120-134 15 項技能、Pos136-145 5 系法術 bitfield。<br><br>"
            "這兩份文件是本站<a href=\"../save-editor.html\">存檔修改器</a>的核心規格來源。"
        ),
        "source_files": ["Luna2修改.txt"],
    },
    {
        "out": "marriage-party.html",
        "title": "結婚條件與隊友分析",
        "subtitle": "germun 2006 · 巴哈姆特 LunaticDawn 看板",
        "author": "germun",
        "author_tag": "MARRIAGE & PARTY · BY germun",
        "intro": (
            "germun 在 2006 年 5 月發表於巴哈姆特 LunaticDawn 看板的深度分析文。"
            "詳細列出結婚的三個條件（親密度 81、魅力差 20、NPC 是人類）、"
            "實體 NPC 與虛擬 NPC 的差異、國王領主會見機制、以及"
            "「配偶死後遣散仍會生小孩」這個蠻詭異的系統 bug。"
        ),
        "source_files": ["[攻略]俠客遊二-結婚條件 及 隊友分析.txt"],
    },
    {
        "out": "starting-stats.html",
        "title": "人物起始能力表",
        "subtitle": "ocrice · 巴哈姆特俠客遊系列討論板",
        "author": "ocrice (yukihiro)",
        "author_tag": "STARTING STATS · BY ocrice",
        "intro": (
            "男女 8 種家系（貴族、農家、一般、學者、傭兵、僧侶、盜賊、孤兒）"
            "的起始能力值對照表。搭配<a href=\"weakness-bonus.html\">弱點額外點數表</a>"
            "可以規劃最理想的初始人物配點。"
        ),
        "source_files": ["Luna2人物起始能力表.txt"],
    },
    {
        "out": "weakness-bonus.html",
        "title": "弱點額外點數表",
        "subtitle": "ocrice · 弱點 vs 初始點數",
        "author": "ocrice (yukihiro)",
        "author_tag": "WEAKNESS BONUS · BY ocrice",
        "intro": (
            "選不同弱點會得到不同的額外能力點數。「沒有恐懼」只有 60 點，"
            "「野獸恐懼症」最高 100 點。本文附上每項弱點的實戰優缺點分析——"
            "例如「不死生物恐懼」在學到神聖系除魔大法之後幾乎無影響。"
        ),
        "source_files": ["Luna2弱點額外點數表.txt"],
    },
    {
        "out": "dos-faq.html",
        "title": "DOS 執行 FAQ",
        "subtitle": "青衫 · 老 Game 執行問答集",
        "author": "青衫",
        "author_tag": "DOS FAQ · BY 青衫",
        "intro": (
            "青衫在 1990 年代末撰寫的老 Game 執行問答集。內容涵蓋 CPU 降速"
            "（moslo）、記憶體不足（DOS=HIGH,UMB）、畫面全黑、音效卡衝突、"
            "純 DOS 模式、Fakecd 破解、MS-DOS 6.22 開機片等當年最常遇到的問題。<br><br>"
            "<strong class=\"amber\">2026 年的版本：</strong>現在有 "
            "<a href=\"https://dosbox-x.com/\" target=\"_blank\" rel=\"noopener\">DOSBox-X</a>"
            "可以在 macOS / Windows / Linux 上完美模擬這些問題的解法（LH + UMB 一鍵搞定）。"
            "本站之後也會推出跨平台啟動器。"
        ),
        "source_files": ["執行dos相關問答集.txt"],
    },
    {
        "out": "readme.html",
        "title": "Readme 與版本紀錄",
        "subtitle": "2004-2008 社群攻略集原始 README",
        "author": "2004-2008 GameBase 社群",
        "author_tag": "README · 2004-2008",
        "intro": (
            "原 2004-2008 社群攻略集的 readme、觀看說明、版權說明、版本更新紀錄。"
            "保留作為數位文化遺產的完整脈絡。"
        ),
        "source_files": ["Readme.txt", "觀看說明.txt", "版權所有.txt"],
    },
]


# ============================================================
# HTML 模板
# ============================================================
TEMPLATE = """<!DOCTYPE html>
<html lang="zh-Hant">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · 俠客遊 II · 吟遊詩人的傳說</title>
<meta name="description" content="{meta_desc}">
<link rel="stylesheet" href="../../assets/css/fonts-wuxia.css">
<link rel="stylesheet" href="../../assets/css/wuxia.css">
<meta property="og:type" content="website">
<meta property="og:title" content="{title} · 俠客遊 II · 吟遊詩人的傳說">
<meta property="og:description" content="{meta_desc}">
<meta property="og:url" content="https://toniliumvp.github.io/LunaticDawn/luna2/guides/{out}">
<meta property="og:site_name" content="吟遊詩人的傳說 · 俠客遊">
<meta name="google-site-verification" content="aQwPgW1H0N4XYMg0Q_takJ0SxDPnRbwyRpinPZjbbJA">
</head>
<body class="guide-page">
<div class="wrap">

<header class="site-header">
  <div class="header-inner">
    <div>
      <h1 class="pixel">{title}</h1>
      <div class="header-sub">LUNATIC DAWN II · {subtitle}</div>
    </div>
    <div class="header-sub header-right">
      <div><a href="../../">◀ 回主站</a></div>
      <div><a href="./">▸ 攻略索引</a></div>
    </div>
  </div>
</header>

<div class="breadcrumb">
  <a href="../../">吟遊詩人的傳說</a> /
  <a href="../../">俠客遊 II</a> /
  <a href="./">攻略</a> /
  <span class="dim">{title}</span>
</div>

<section class="panel">
  <div class="panel-title">[ {author_tag} ]</div>
  <p>{intro}</p>
  <p class="muted">原作者：{author} · 整理：2004-2008 GameBase / 巴哈姆特社群 · 重建：toni 2026</p>
</section>

<section class="panel">
  <div class="panel-title">[ CONTENT · {byte_count} BYTES ]</div>
  <pre class="raw-text">{content}</pre>
</section>

<section class="panel">
  <div class="panel-title">[ NAVIGATION ]</div>
  <p>
    <a href="./">◀ 回攻略索引</a> ·
    <a href="../save-editor.html">▸ 存檔修改器</a> ·
    <a href="../launcher/">▸ 遊戲啟動器</a> ·
    <a href="../../">▸ 主站</a>
  </p>
  <p class="muted">
    需要其他攻略？請回<a href="./">攻略索引</a>查看全部 9 篇文件。
  </p>
</section>

<footer class="site-footer">
  <div>所有攻略文件版權屬於原作者。本站僅為數位文化遺產保存目的整理展示。</div>
  <div class="footer-big">｢ 吟遊詩人的傳說 · 俠客遊 II ｣</div>
  <div>
    <a href="../../">◀ 主站</a> ·
    <a href="./">攻略索引</a> ·
    <a href="../save-editor.html">存檔修改器</a> ·
    維護：toni
  </div>
</footer>

</div>
<script>
/* 自動縮放 .raw-text 字型：
   - 找最寬的「表格行」（含 Box Drawing ─│ 或 3+空格 或 3+全形空格的行）
   - 按比例縮小字型讓表格行完整顯示不換行
   - 段落行（無對齊格式）由 CSS pre-wrap 自然換行 */
(function(){{
  var timer;
  var tableRe=/[\\u2500-\\u257F]|   |\\t|\\u3000.*\\u3000.*\\u3000/;
  function fit(){{
    var els=document.querySelectorAll('.raw-text');
    for(var i=0;i<els.length;i++){{
      var el=els[i];
      el.style.fontSize='';
      var lines=el.textContent.split('\\n');
      var target='';
      for(var j=0;j<lines.length;j++){{
        if(tableRe.test(lines[j])&&lines[j].length>target.length) target=lines[j];
      }}
      if(!target) continue;
      var ruler=document.createElement('span');
      ruler.style.cssText='position:absolute;visibility:hidden;white-space:pre;font:inherit;';
      ruler.textContent=target;
      el.appendChild(ruler);
      var lineW=ruler.offsetWidth;
      ruler.remove();
      var cs=getComputedStyle(el);
      var maxFS=parseFloat(cs.fontSize);
      var padL=parseFloat(cs.paddingLeft),padR=parseFloat(cs.paddingRight);
      var availW=el.clientWidth-padL-padR;
      if(lineW<=availW) continue;
      var fs=Math.floor(maxFS*availW/lineW*2)/2;
      if(fs<8) fs=8;
      el.style.fontSize=fs+'px';
    }}
  }}
  window.addEventListener('load',fit);
  window.addEventListener('resize',function(){{clearTimeout(timer);timer=setTimeout(fit,150);}});
}})();
</script>
</body>
</html>
"""


def build_guide(guide):
    """讀 TXT、escape、填模板、寫 HTML。"""
    # 合併多個來源檔（readme.html 用到）
    parts = []
    total_bytes = 0
    for fname in guide["source_files"]:
        path = TXT_DIR / fname
        if not path.exists():
            print(f"  ⚠️  找不到來源檔：{path}")
            continue
        raw = path.read_text(encoding="utf-8")
        total_bytes += path.stat().st_size
        # 多檔時用分隔線分開
        if len(guide["source_files"]) > 1:
            parts.append(f"════════════════════════════════════════════════════════════\n"
                         f"  檔案：{fname}\n"
                         f"════════════════════════════════════════════════════════════\n")
        parts.append(raw)
        if len(guide["source_files"]) > 1:
            parts.append("\n\n")

    content_raw = "".join(parts)

    # HTML escape（防止 < > & 被當成 tag）
    content_escaped = html.escape(content_raw)

    # 產生 meta description（取 intro 的純文字前 150 字）
    # 為了安全，移除所有 HTML tag
    import re
    intro_plain = re.sub(r"<[^>]+>", "", guide["intro"])
    intro_plain = intro_plain.replace('"', "'").strip()
    meta_desc = intro_plain[:150]

    # 填模板
    html_out = TEMPLATE.format(
        title=guide["title"],
        subtitle=guide["subtitle"],
        author=guide["author"],
        author_tag=guide["author_tag"],
        intro=guide["intro"],
        meta_desc=meta_desc,
        out=guide["out"],
        content=content_escaped,
        byte_count=f"{total_bytes:,}",
    )

    out_path = OUT_DIR / guide["out"]
    out_path.write_text(html_out, encoding="utf-8")

    print(f"  ✓  {guide['out']:<25} ({total_bytes:>6,} bytes → {len(html_out):>6,} bytes HTML)")


def main():
    print(f"▶ 讀取 TXT 檔自：{TXT_DIR}")
    print(f"▶ 寫出 HTML 至：{OUT_DIR}")
    print()

    if not OUT_DIR.exists():
        OUT_DIR.mkdir(parents=True)

    for guide in GUIDES:
        build_guide(guide)

    print()
    print(f"✅ 完成！共產生 {len(GUIDES)} 個攻略頁面")


if __name__ == "__main__":
    main()
