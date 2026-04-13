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
    has_luna3 = check_exists("luna3/index.html")
    has_luna4 = check_exists("luna4/index.html")
    has_steam = check_exists("steam/index.html")
    has_files = check_exists("files/index.html")
    has_general = check_exists("general/index.html")
    has_sitemap = check_exists("sitemap.xml")
    has_404 = check_exists("404.html")

    # 各區 HTML 數
    n_passage = count_html("passage")
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

    if has_luna3 and n_luna3 > 1:
        games.append(("未來之書 (Lunatic Dawn III)", "1998", f"密技 + 更新檔（{n_luna3} 頁）"))
    elif has_luna3:
        games.append(("未來之書 (Lunatic Dawn III)", "1998", "密技 + 更新檔"))

    if has_passage and n_passage > 1:
        games.append(("前途道標 (Lunatic Dawn Passage)", "1999", f"完整攻略（{n_passage} 頁）"))
    elif has_passage:
        games.append(("前途道標 (Lunatic Dawn Passage)", "1999", "攻略"))

    if has_luna4 and n_luna4 > 1:
        games.append(("俠客遊 III (Lunatic Dawn FX)", "2001", f"密技（{n_luna4} 頁）"))
    elif has_luna4:
        games.append(("俠客遊 III (Lunatic Dawn FX)", "2001", "密技"))

    # 組裝 README
    lines = []
    lines.append("# 俠客遊 · Lunatic Dawn 系列資料站")
    lines.append("")
    lines.append("> 「吟遊詩人的傳說」— 台灣 DOS 時代 Artdink 經典 RPG 系列的玩家資料庫與工具站")
    lines.append(">")
    lines.append("> 由 toni（@toniLiuMVP）維護 — 接續 2004 年 GameBase 遊戲基地與巴哈姆特俠客遊討論板的時代遺產")
    lines.append("")

    lines.append("🎮 **請先至 Steam 購買正版遊戲支持原作**")
    lines.append("- [俠客遊 II / III](https://store.steampowered.com/app/338070/)")
    lines.append("- [前途道標](https://store.steampowered.com/app/335420/)")
    lines.append("")
    lines.append("---")
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
        lines.append(f"- **[俠客遊 II 完整攻略](./luna2/guides/)** — 整合 2004-2008 年社群前輩心血（{n_guides} 篇）")
    if has_ez:
        lines.append("- **[懶人包（Luna2_EZ）](./luna2/ez/)** — 內建 DOSBox Staging，解壓即玩，支援 Mac / Windows / Linux")
    if has_launcher:
        lines.append("- **[自己裝啟動器](./luna2/launcher/)** — 搭配 DOSBox-X + GM MIDI 高音質音樂")
    if has_passage:
        lines.append("- **[前途道標攻略](./passage/)** — 1999 年 BBS 時代原創攻略（小蜜蜂 / 小傑 / Ertai）")
    if has_luna3:
        lines.append("- **[未來之書密技](./luna3/)** — 未來之書 + 前途道標 + 俠客遊 III 密技彙整")
    if has_files:
        lines.append("- **[檔案庫](./files/)** — 修正檔、工具、更新檔下載")
    if has_steam:
        lines.append("- **[Steam 購買指南](./steam/)** — Steam 版購買說明")
    if has_general:
        lines.append("- **[通用資訊](./general/)** — 編碼 FAQ、社群連結")
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
    lines.append("## 🙏 致謝（2004-2008 GameBase / 巴哈姆特討論板前輩）")
    lines.append("")
    lines.append("| 貢獻 | 作者 |")
    lines.append("|------|------|")
    lines.append("| 俠客遊 II 攻略原作者 | 青衫 |")
    lines.append("| 存檔格式逆向工程 | 聶荊璇（殘楓網） |")
    lines.append("| 原版 Windows 修改器 | Morrowind |")
    lines.append("| 修改筆記（1996） | 伊達政宗、Silver Angel |")
    lines.append("| 精確 byte offset 文件 | 李憲忠 |")
    lines.append("| 人物起始能力表 | ocrice (yukihiro) |")
    lines.append("| 前途道標攻略 | 小蜜蜂、小傑、Ertai |")
    lines.append("| 攻略整理/補充 | 劍俠天才、那伽龍、yjyyang、aldalave11127、jo（謎樣的大叔）、raclim（林秀奕）、PhilJane（矮子小豪）、toni |")
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
    lines.append("本站程式碼為 MIT。社群整理的攻略、物品資料、存檔解析文件版權屬於原作者，本站僅為**數位文化遺產保存**目的整理展示。如原作者希望撤除，請開 Issue 告知。")
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
