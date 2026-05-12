#!/usr/bin/env python3
"""
_build_readme.py — 自動產生 README.md，反映網站最新狀態
每次 GO 發布前自動執行，確保 README 與實際頁面同步。

用法：python3 _build_readme.py
"""

from pathlib import Path
from datetime import datetime
import re
import html as html_module

ROOT = Path(__file__).parent.resolve()

# ============================================================
# 掃描工具函式
# ============================================================

def count_html(subdir: str) -> int:
    """計算指定子目錄下的 HTML 檔案數。"""
    d = ROOT / subdir
    if not d.exists():
        return 0
    return len(list(d.glob("*.html")))


def extract_title(html_path: Path) -> str:
    """從 HTML 的 <title> 標籤取得標題文字。"""
    try:
        text = html_path.read_text(encoding="utf-8", errors="replace")
        m = re.search(r"<title>(.+?)</title>", text)
        if m:
            raw = m.group(1).split("·")[0].strip()
            return html_module.unescape(raw)
    except Exception:
        pass
    return html_path.stem


def list_guides() -> list:
    """掃描 luna2/guides/ 下所有攻略 HTML（排除 index.html）。"""
    guides_dir = ROOT / "luna2" / "guides"
    if not guides_dir.exists():
        return []
    result = []
    for f in sorted(guides_dir.glob("*.html")):
        if f.name == "index.html":
            continue
        title = extract_title(f)
        result.append((f.name, title))
    return result


def check_exists(rel_path: str) -> bool:
    """檢查檔案或目錄是否存在。"""
    return (ROOT / rel_path).exists()


# ============================================================
# 產生 README 內容
# ============================================================

def build_readme() -> str:
    today = datetime.now().strftime("%Y-%m-%d")

    # 統計
    total_html = len(list(ROOT.rglob("*.html")))
    guide_list = list_guides()
    n_guides = len(guide_list)

    has_save_editor = check_exists("luna2/save-editor.html")
    has_ez = check_exists("luna2/ez/index.html")
    has_launcher = check_exists("luna2/launcher/index.html")
    has_passage = check_exists("passage/index.html")
    has_lde3 = check_exists("lde3/index.html")
    has_book = check_exists("book/index.html")
    has_luna3 = check_exists("luna3/index.html")
    has_luna4 = check_exists("luna4/index.html")
    has_steam = check_exists("steam/index.html")
    has_general = check_exists("general/index.html")
    has_sitemap = check_exists("sitemap.xml")
    has_404 = check_exists("404.html")

    # 各區 HTML 數
    n_passage = count_html("passage")
    n_lde3 = count_html("lde3")
    n_luna3 = count_html("luna3")
    n_luna4 = count_html("luna4")

    # 遊戲狀態表
    games = []
    if has_save_editor or n_guides > 0:
        features = []
        if n_guides > 0:
            features.append(f"攻略 {n_guides} 篇")
        if has_save_editor:
            features.append("存檔修改器")
        if has_launcher:
            features.append("啟動器")
        if has_ez:
            features.append("懶人包")
        games.append(("俠客遊 II (Lunatic Dawn II)", "1996", " + ".join(features)))

    if has_book:
        games.append(("未來之書 (Lunatic Dawn: The Book of Futures)", "1998", "獨立子站 + 隱藏角色 + 攻略"))

    if has_luna3 and n_luna3 > 1:
        games.append(("俠客遊 III (Lunatic Dawn III)", "2000", f"密技 + 下載（{n_luna3} 頁）"))
    elif has_luna3:
        games.append(("俠客遊 III (Lunatic Dawn III)", "2000", "密技 + 下載"))

    if has_passage and n_passage > 1:
        games.append(("前途道標 (Lunatic Dawn: Passage of The Book)", "1999", f"完整攻略（{n_passage} 頁）"))
    elif has_passage:
        games.append(("前途道標 (Lunatic Dawn: Passage of The Book)", "1999", "攻略"))

    if has_luna4 and n_luna4 > 1:
        games.append(("俠客遊 IV (Lunatic Dawn IV)", "2001", f"密技（{n_luna4} 頁）"))
    elif has_luna4:
        games.append(("俠客遊 IV (Lunatic Dawn IV)", "2001", "密技"))

    if has_lde3:
        games.append(("第三之書 (Lunatic Dawn: The Third Book)", "2002", "Book 三部曲第三作 · 下載 + 工具 + 18 個歷史檔案"))

    # 組裝 README
    lines = []
    lines.append("# 俠客遊 · Lunatic Dawn 系列資料站")
    lines.append("")
    lines.append("> 俠客遊 (Lunatic Dawn) 是由日本 [Artdink](https://www.artdink.com/) 製作、台灣第三波/美商藝電代理的開放世界 RPG。")
    lines.append(">")
    lines.append("> 由 toni（@toniLiuMVP）維護 — 接續 2000 年 GameBase 遊戲基地與巴哈姆特俠客遊討論板的時代遺產")
    lines.append("")

    lines.append("🎮 **請先至 Steam 購買正版 [俠客遊 I/II/III 合輯](https://store.steampowered.com/app/338070/_/) 或 [前途道標](https://store.steampowered.com/app/335420/_/) 支持原作**")
    lines.append("")
    lines.append("---")
    lines.append("")

    # 系列年表
    lines.append("## 📜 俠客遊系列年表")
    lines.append("")
    lines.append("| 年份 | 原名 | 中文名 | 代理 |")
    lines.append("|------|------|--------|------|")
    lines.append("| 1993 | Lunatic Dawn | 俠客遊 | 日本 [Artdink](https://www.artdink.com/) 發行 |")
    lines.append("| 1996 | Lunatic Dawn II | 俠客遊 II | 台灣第三波 |")
    lines.append("| 1998 | Lunatic Dawn: The Book of Futures | 俠客遊：未來之書 | 台灣第三波 |")
    lines.append("| 1999 | Lunatic Dawn: Passage of The Book | 俠客遊：前途道標 | 台灣第三波 |")
    lines.append("| 2000 | Lunatic Dawn III | 俠客遊 III | 台灣第三波 |")
    lines.append("| 2001 | Lunatic Dawn IV | 俠客遊 IV | 台灣第三波 |")
    lines.append("| 2002 | Lunatic Dawn: The Third Book | 俠客遊：第三之書 | 台灣美商藝電 |")
    lines.append("")

    # 涵蓋表
    lines.append("## 📖 本站涵蓋")
    lines.append("")
    lines.append("| 作品 | 年代 | 本站狀態 |")
    lines.append("|------|------|----------|")
    for name, year, status in games:
        lines.append(f"| {name} | {year} | ✅ {status} |")
    lines.append("")

    # 工具與資源
    lines.append("## 🛠 工具與資源")
    lines.append("")
    if has_save_editor:
        lines.append("- **[俠客遊 II 存檔修改器](./luna2/save-editor.html)** — 瀏覽器版，純 HTML+JS，拖入 LUNACHAR.SAV 即改，160 個角色槽")
    if n_guides > 0:
        lines.append(f"- **[俠客遊 II 完整攻略](./luna2/guides/)** — 整合社群前輩心血（{n_guides} 篇）")
    if has_ez:
        lines.append("- **[懶人包（Luna2_EZ）](./luna2/ez/)** — 內建 DOSBox Staging，解壓即玩，支援 Mac / Windows / Linux")
    if has_launcher:
        lines.append("- **[自己裝啟動器](./luna2/launcher/)** — 搭配 DOSBox-X + GM MIDI 高音質音樂")
    if has_book:
        lines.append("- **[未來之書專區](./book/)** — 1998 · 隱藏角色完整指南 + 新手上手 + 密技 + 攻略集下載")
    if has_passage:
        lines.append("- **[前途道標攻略](./passage/)** — 1999 年 BBS 時代原創攻略（小蜜蜂 / 小傑 / Ertai）")
    if has_lde3:
        lines.append("- **[第三之書專區](./lde3/)** — 2002 年 Book 三部曲第三作 · 18 個歷史檔案 + 下載 + 工具")
    if has_luna3:
        lines.append("- **[俠客遊 III 子站](./luna3/)** — 俠客遊 III (2000) · 密技整理 + 官方更新檔下載")
    if has_luna4:
        lines.append("- **[俠客遊 IV 子站](./luna4/)** — 俠客遊 IV (2001) · 連線方法 / 鞠躬練功法 / 輔助工具下載")
    if has_steam:
        lines.append("- **[Steam 購買指南](./steam/)** — Steam 版購買說明")
    if has_general:
        lines.append("- **[通用資訊](./general/)** — 編碼 FAQ、社群連結")
    if check_exists("luna2/database/index.html"):
        lines.append("- **[俠客遊 II 資料庫](./luna2/database/)** — DOS 二進制檔案格式逆向研究與數值欄位資料")
    lines.append("")

    # 兩種遊玩方式
    if has_ez and has_launcher:
        lines.append("## 🎮 兩種遊玩方式")
        lines.append("")
        lines.append("| | 懶人包（推薦新手） | 自己裝 |")
        lines.append("|---|---|---|")
        lines.append("| 模擬器 | DOSBox Staging（內建） | DOSBox-X（需自行安裝） |")
        lines.append("| 音效 | Adlib/OPL（FM 合成） | GM MIDI（高音質） |")
        lines.append("| 安裝 | 解壓即玩 | 需安裝模擬器 + 設定音效 |")
        lines.append("| 頁面 | [懶人包說明](./luna2/ez/) | [自己裝說明](./luna2/launcher/) |")
        lines.append("")

    # 攻略目錄
    if guide_list:
        lines.append("## 📚 攻略目錄")
        lines.append("")
        lines.append("| 攻略 | 連結 |")
        lines.append("|------|------|")
        for fname, title in guide_list:
            lines.append(f"| {title} | [閱讀](./luna2/guides/{fname}) |")
        lines.append("")

    # 致謝
    lines.append("## 🙏 致謝（1999-2026 跨海玩家、攻略原作者、修改器開發者）")
    lines.append("")
    lines.append("### 站長傳承")
    lines.append("")
    lines.append("**「吟遊詩人的傳說 · 俠客遊小站」** 由 1999 年 BBS 時代的兩位創站站長 **小傑**(LemiyaJay)與 **小蜜蜂**(Yellowbee)創立。**21 世紀初(2000 年代初期)**，toni 從小傑與小蜜蜂手上接手俠客遊小站，持續維護至今 — 後續歷經 Google Pages（2009）→ Google Sites（2010 年代）→ GitHub Pages（2026）三次平台遷移，但站名與精神不變，延續這份俠客遊系列的數位文化傳承。")
    lines.append("")
    lines.append("> 感謝小傑與小蜜蜂兩位創站站長，沒有他們 1999 年的 BBS 時代起點，就沒有 27 年後本站的存在。")
    lines.append("")
    lines.append("### 攻略原作者")
    lines.append("")
    lines.append("| 貢獻 | 作者 |")
    lines.append("|------|------|")
    lines.append("| 俠客遊 II 主攻略（2004-2008） | 青衫 |")
    lines.append("| 俠客遊 II 深度心得 + 多項勘誤（2023 PTT Old-Games）★ | **kyleul** |")
    lines.append("| 俠客遊 II 結婚條件 & 隊友分析（2006 巴哈姆特） | germun |")
    lines.append("| 俠客遊 II 人物起始能力表、弱點額外點數表 | ocrice (yukihiro) |")
    lines.append("| 前途道標完整三部曲攻略（1999） | 小蜜蜂 / 小傑（Yellowbee / LemiyaJay） |")
    lines.append("| 前途道標寶物獵人心得（2000） | Ertai |")
    lines.append("| 未來之書 25 篇 BBS 時代攻略（1998-2000） | BBS 社群匿名整理 |")
    lines.append("| 攻略整理/補充 | 劍俠天才、那伽龍、yjyyang、aldalave11127、jo（謎樣的大叔）、raclim（林秀奕）、PhilJane（矮子小豪）、toni |")
    lines.append("")
    lines.append("### 修改器、工具、逆向工程")
    lines.append("")
    lines.append("| 貢獻 | 作者 |")
    lines.append("|------|------|")
    lines.append("| 俠客遊 II 存檔格式逆向 v4.1（2006） | 聶荊璇（殘楓網） |")
    lines.append("| 俠客遊 II 精確 byte offset 文件 | 李憲忠 (An-Liang Lo) |")
    lines.append("| 俠客遊 II 原版 Windows 修改器 | Morrowind |")
    lines.append("| 俠客遊 II 修改器共同製作者 | kkt_zzz |")
    lines.append("| 俠客遊 II 早期修改筆記（1996） | 伊達政宗、Silver Angel、Yao Shih |")
    lines.append("| 前途道標修改器 v1.2（2005，.NET 2.0）★ 2026 toni 繁中化 | **zxp** |")
    lines.append("| 第三之書修改器 v0.4 | kkarthur |")
    lines.append("| 第三之書管理員 1.0.6 | askacheng |")
    lines.append("| 第三之書流動化啟動器 | anDY & aSKa STUDiO |")
    lines.append("| 第三之書工具開發（2011 跨海寄送） | daggerain |")
    lines.append("| 前途道標角色複製人物存檔包 | Cody |")
    lines.append("")
    lines.append("### 跨海玩家回報（17-19 年前的真實問題佐證 — 本站 2026 字體修復補丁誕生的緣由）")
    lines.append("")
    lines.append("- **tyler_yeung** — 2007 前途道標 XP 字型問題（19 年前最早佐證）")
    lines.append("- **cu54102003** — 2008 XP 字型問題再回報")
    lines.append("- **towaicheung** — 2009 前途道標 XP 字體重疊（17 年前佐證）")
    lines.append("- **Tedk** — 2009 Google Pages 時代協助驗證")
    lines.append("- **linxr_wind** — 2009 第三之書管理員需求回報")
    lines.append("- **timchio** — 2011 俠客遊 IV 重溫詢問")
    lines.append("- **Kelvin Yau** — 2013 第三之書 Win7 相容性早期測試")
    lines.append("- **QQ508091419** — 2020 俠客遊 IV 神之眼路徑詢問")
    lines.append("- **DavidChien / nec81616 / tigerzhou100800 / line841a** — 2020-2021 Google 防毒誤判回報")
    lines.append("- **qq888999123** — 2021「密碼壓縮繞防毒」解法提議")
    lines.append("- **a0961168526** — 2022 阿米卓古 / 第三之書 me 版詢問")
    lines.append("- **raymond0206** — 2022 Win10 亂碼問題")
    lines.append("- **jill90131** — 2023 第三之書入坑詢問（toni TeamViewer 遠端協助）")
    lines.append("- **KO** — 2023-2024 跨年度多次回報 + 乙太劍研究實測")
    lines.append("- **kyleul** — 2007 PTT XP 字型問題 + 2023 PTT 深度心得")
    lines.append("- **ak5511ak5511** — 2024 Steam 購買前途道標 + 中文化詢問")
    lines.append("")
    lines.append("※ 若有遺漏的貢獻者，或希望調整 / 撤除自己名字，請寄信 [luntic.dawn@gmail.com](mailto:luntic.dawn@gmail.com) 通知 toni。")
    lines.append("")

    # 站點資訊
    lines.append("## 📊 站點資訊")
    lines.append("")
    lines.append(f"- 總頁數：**{total_html}** 個 HTML")
    lines.append(f"- 攻略數：**{n_guides}** 篇")
    features_list = []
    if has_sitemap:
        features_list.append("sitemap.xml")
    if has_404:
        features_list.append("404.html")
    features_list.append("Open Graph 標籤")
    features_list.append("本地化字型（零外部依賴）")
    features_list.append("Google Search Console 已驗證")
    lines.append(f"- 基礎建設：{' · '.join(features_list)}")
    lines.append(f"- 最後更新：{today}")
    lines.append("")

    # 授權
    lines.append("## 📜 授權")
    lines.append("")
    lines.append("本站程式碼為 MIT。本站基於數位文化保存目的整理，遊戲本體著作權屬於 [Artdink](https://www.artdink.com/)。站上技術文件為獨立逆向研究成果；公開內容僅限事實層（玩家可見名稱 / 結構觀察 / 數值對照），原版美術 / 劇情對白 / 配樂等創作性表現僅作為研究者個人參考保留，不在本站公開展示。請至 Steam 購買正版 [俠客遊 I/II/III 合輯](https://store.steampowered.com/app/338070/_/) 或 [前途道標](https://store.steampowered.com/app/335420/_/) 支持原作 ARTDINK（俠客遊 IV / 未來之書 / 第三之書 Steam 未上架）。若您是攻略原作者並希望授權變更或撤除，請至 [GitHub Issues](https://github.com/toniLiuMVP/LunaticDawn/issues) 聯繫。")
    lines.append("")
    lines.append("**三邊著作權法依據**：🇹🇼 著作權法 §10-2（事實 / 數據不受保護）+ 🇯🇵 著作権法 §2（創作性要件）+ §12-2（資料庫）+ 🇺🇸 17 USC §102(b) + Feist v. Rural Telephone (1991) + Sega v. Accolade (1992)。完整法律分析見 [系列研究筆記 § 10 國際同類網站對照](./series-research.html)。")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("*「俠客遠行不忘舊路，吟遊詩人傳說永存。」*")
    lines.append("")

    return "\n".join(lines)


# ============================================================
# 主程式
# ============================================================

if __name__ == "__main__":
    readme_path = ROOT / "README.md"
    content = build_readme()

    # 比對是否有變動
    if readme_path.exists():
        old = readme_path.read_text(encoding="utf-8")
        if old == content:
            print("✓ README.md 無變動（已是最新）")
            raise SystemExit(0)

    readme_path.write_text(content, encoding="utf-8")
    print(f"✅ README.md 已更新（{len(content):,} bytes）")
