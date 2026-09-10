#!/usr/bin/env bash
# Public site comprehensive audit — runs all 14 checks before commit.
#
# Triple-jurisdiction copyright check:
#   - 台灣著作權法 §10-1 (思想/表達二分法,事實/數據不受保護;§10-2 不存在,勿用)
#   - 日本著作権法 §2 創作性 + §12-2 資料庫
#   - 美國 17 USC §102(b) facts not protected, Feist v. Rural (1991), Sega v. Accolade (1992)
#
# Usage:
#   ./tools/audit/site_audit.sh           # report
#   ./tools/audit/site_audit.sh --strict  # warnings = blockers
#
# Returns: exit 0 if clean (or only warnings in non-strict), exit 1 if blocking issue.
#
# CRITICAL: only audits files actually tracked by git (i.e. files that reach
# GitHub / GitHub Pages). Gitignored files (ARCHITECTURE.md, _local/, docs/*.md,
# etc.) are intentionally skipped — they never reach the public site.

set -uo pipefail

# 預設掃工作區（手動執行時想看的是「我正在編輯的東西」）。
# pre-commit 會設 LD_AUDIT_ROOT 指向索引內容的副本，因為真正要進版本庫的是索引，
# 而 git add 之後再編輯、只暫存部分變更、stash 之後 pop，都會讓兩者不同。
GIT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ROOT="${LD_AUDIT_ROOT:-$GIT_ROOT}"
cd "$ROOT"

# Strict mode: warns become blockers
STRICT=0
[ "${1:-}" = "--strict" ] && STRICT=1

# Track issues
BLOCKERS=0
WARNINGS=0

print_section() {
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  $1"
  echo "════════════════════════════════════════════════════════════"
}

print_pass() { echo "  ✓ $1"; }
print_warn() { echo "  ⚠ $1"; WARNINGS=$((WARNINGS+1)); }
print_fail() { echo "  ✗ $1"; BLOCKERS=$((BLOCKERS+1)); }

# Use git ls-files — ONLY files tracked by git reach the public site
# Filter to text-content files only (skip binaries like PNG/woff2/SAV).
#
# Scripts and config are included: anything tracked here is visible to anyone
# browsing the repository, so scripts leak paths and notes just as pages do.
#
# tools/audit/ is excluded on purpose: this script carries the search patterns
# themselves and the self-test carries deliberate violations as bait, so
# scanning them would make the audit fail against its own rulebook.
if [ -n "${LD_AUDIT_FILES:-}" ]; then
  ALL_TRACKED="$LD_AUDIT_FILES"
else
  ALL_TRACKED=$(git -c core.quotePath=false ls-files)
fi
PUB_FILES=$(printf '%s\n' "$ALL_TRACKED" \
  | grep -E "\.(html|js|json|xml|css|md|txt|svg|py|sh|command|bat|yml|conf)$|^LICENSE$" \
  | grep -v "^_local/" \
  | grep -v "^tools/audit/" 2>/dev/null \
  || true)

# An empty file list means the audit is looking at the wrong place — a git
# repo with nothing tracked, or a wrong working directory. Report that instead
# of counting the empty string as one file and declaring the site clean.
if [ -z "$PUB_FILES" ]; then
  echo "✗ Audit found no files to scan. Wrong directory, or nothing tracked here?"
  echo "  (Expected to run from the site root, with git tracking the public files.)"
  exit 1
fi

NUM_FILES=$(printf '%s\n' "$PUB_FILES" | wc -l | tr -d ' ')

# A1. Internal wave/round/PENDING jargon (BLOCKER)
# 也包含 W## (W08 / W14 / W56 等) - 內部 wave 編號縮寫
print_section "[A1] Internal development jargon (BLOCKER)"
HITS=$(echo "$PUB_FILES" | xargs -I{} grep -nE "第[一二三四五六七八九十百零壹貳參肆伍陸柒捌玖拾佰0-9]+波|第\s*[0-9]+\s*波|第[一二三四五六七八九十百零0-9][一二三四五六七八九十百零0-9　 ／/、]*[／/][一二三四五六七八九十百零0-9　 ／/、]*波|wave\s*[0-9]+|Wave\s*[0-9]+|round-[0-9]+|Round[ _]?[0-9]+|\b[wW][0-9][0-9]+\b|波次|PENDING|⏳[^：）)]*規劃|scope[- ]?校正|carry[- ]?over|toni\s+(戳穿|挑戰|個人|指示)|逆向工程依賴|反組譯依賴|未完成事項|\bP[0-3]\b|milestone|第\s*[0-9]+\s*輪" {} 2>/dev/null \
  | grep -vE "(台灣第三波|第三波文化|第三波代理|第三波伺服器|第三波修改|第三波網頁|第三波發行|第三波官方|第三波的俠客遊|第三波繁中|第三波中文|第三波\s*/|第三波([^波]|$)|0\.[0-9]+s|height=\"[0-9]+|width=\"[0-9]+)")
if [ -z "$HITS" ]; then
  print_pass "No internal dev jargon"
else
  echo "$HITS" | head -10
  print_fail "Internal dev jargon ($(echo "$HITS" | wc -l | tr -d ' ') hits)"
fi

# A2. Personal dev paths (BLOCKER) — /Volumes/Work/, NAS paths
# Public path EXAMPLES should use a generic placeholder (/Users/player/), NOT toni's
# actual macOS username. Real leaks: /Volumes/Work/LD/, NAS smb paths, "Mac Mini M4".
print_section "[A2] Personal dev paths / NAS leakage (BLOCKER)"
HITS=$(echo "$PUB_FILES" | xargs -I{} grep -nE "/Volumes/(Work|918|Mac Mini M4|Scratch|PLEXTOR|Toni-NAS)/|/Users/toni/|smb://(toni|toniLiu|Mac)|toniLiuMVP\._smb|918%20%E8%B3%87" {} 2>/dev/null)
if [ -z "$HITS" ]; then
  print_pass "No personal dev paths leaked"
else
  echo "$HITS" | head -10
  print_fail "Personal dev paths leaked"
fi

# A3. Credentials / secrets pattern (BLOCKER)
print_section "[A3] Credentials / API keys (BLOCKER)"
HITS=$(echo "$PUB_FILES" | xargs -I{} grep -nE "(api[_-]?key|secret[_-]?key|password|access[_-]?token)[\"']?\s*[=:]\s*[\"'][a-zA-Z0-9]{16,}|AKIA[0-9A-Z]{16}|sk_live_|ghp_[a-zA-Z0-9]{36}|-----BEGIN [A-Z]" {} 2>/dev/null)
if [ -z "$HITS" ]; then
  print_pass "No credentials"
else
  echo "$HITS" | head -10
  print_fail "Possible credentials detected"
fi

# A4. innerHTML XSS check (BLOCKER per CLAUDE.md DOM-only rule)
print_section "[A4] innerHTML usage (BLOCKER, DOM-only rule)"
HITS=$(printf '%s\n' "$PUB_FILES" | xargs -I{} grep -nE "\.innerHTML\s*\+?=|\.outerHTML\s*\+?=|insertAdjacentHTML\s*\(|document\.write(ln)?\s*\(" {} 2>/dev/null)
if [ -z "$HITS" ]; then
  print_pass "Pure DOM API"
else
  echo "$HITS" | head -10
  print_fail "innerHTML found"
fi

# A5. toni capitalization (BLOCKER, lowercase only)
print_section "[A5] toni naming consistency (BLOCKER)"
HITS=$(echo "$PUB_FILES" | xargs -I{} grep -nE "(\bToni\b|\bTONI\b|toni\s*大神|捅你)" {} 2>/dev/null)
if [ -z "$HITS" ]; then
  print_pass "toni naming consistent (lowercase 4-letter)"
else
  echo "$HITS" | head -10
  print_fail "Wrong toni capitalization"
fi

# A6. Low-level RE jargon (WARN)
# Whitelisted: "MFC CArchive" — standard Windows API name, legitimate technical context
print_section "[A6] Low-level RE jargon (WARN — review case-by-case)"
HITS=$(echo "$PUB_FILES" | xargs -I{} grep -nE "fcn\.[0-9a-f]+|filter-branch|self[- ]?correct|內化教訓|cross[- ]?project|RedTime\b|\bJYQXZ\b|\bSWDA\b|MVP_Baseball|\bAnzai\b|\bALLRM\b|跨專案[^著]|廣場留言|專案廣場" {} 2>/dev/null)
if [ -z "$HITS" ]; then
  print_pass "No low-level RE jargon"
else
  echo "$HITS" | head -10
  print_warn "Low-level RE references"
fi

# A7. Email PII (WARN — only toni's mailto allowed)
print_section "[A7] Email addresses (WARN — only toni's mailto)"
HITS=$(echo "$PUB_FILES" | xargs -I{} grep -nE "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" {} 2>/dev/null \
  | grep -vE "(luntic\.dawn@gmail\.com|toni\.luna2@gmail\.com|noreply@anthropic\.com|noreply@github\.com|sender@company\.com|user@example\.com|john@example\.com|@example\.com|@example\.org|@2x\.png|@bbs\.|qazzaq\.bbs@|jesse\.bbs@|chiukm@ctimail3\.com)" )
if [ -z "$HITS" ]; then
  print_pass "Only toni's email + BBS-archive emails"
else
  echo "$HITS" | head -10
  print_warn "Other email addresses found"
fi

# A8. Triple-jurisdiction copyright check
print_section "[A8] Copyright (TW §10-1 + JP §2/§12-2 + US §102b/Feist/Sega)"

# 8.1: Forbidden v2.0 phrasing (BLOCKER)
HITS=$(echo "$PUB_FILES" | xargs -I{} grep -nE "攻略文件版權屬於原作者，本站僅|事實在二進制裡|逆向解析的完整資料庫" {} 2>/dev/null)
if [ -z "$HITS" ]; then
  print_pass "8.1 No forbidden v2.0 phrasing"
else
  echo "$HITS" | head -3
  print_fail "8.1 Forbidden phrasing detected"
fi

# 8.2: Long literal quotes (>300 char single-string in HTML body)
HITS=$(echo "$PUB_FILES" | grep -E "\.html$" | python3 -c "
import sys, re
# 300+ char direct quotation = text inside real quotation markup.
# NOT a raw \\\" ... \\\" span: in HTML those are attribute delimiters, so the old
# pattern measured markup distance, not quoted text (and BSD grep capped {300,} anyway).
PATS = [re.compile(r'\u300c[^\u300d]{300,}\u300d', re.S),
        re.compile(r'\u300e[^\u300f]{300,}\u300f', re.S),
        ]
# NOTE: deliberately NOT measuring whole <blockquote> containers — one blockquote may
# legitimately hold several short attributed quotes plus commentary. The fair-use risk
# is a single continuous verbatim passage, which the quote-mark spans above capture.
TAG = re.compile(r'<[^>]+>')
for line in sys.stdin:
    f = line.strip()
    if not f: continue
    try: t = open(f, encoding='utf-8', errors='replace').read()
    except OSError: continue
    for pat in PATS:
        for m in pat.finditer(t):
            if len(TAG.sub('', m.group(0)).strip()) >= 300:
                print(f'{f}: {len(TAG.sub(chr(32), m.group(0)))} chars quoted')
                break
" 2>&1)
A82_RC=$?
if [ "$A82_RC" -ne 0 ]; then
  printf '%s\n' "$HITS" | tail -4 | sed 's/^/    /'
  print_fail "8.2 check could not run (exit $A82_RC) - not reporting it as passed"
elif [ -z "$HITS" ]; then
  print_pass "8.2 No 300+ char literal quotes (fair use safe)"
else
  print_warn "8.2 Long literal quotes (review for fair use)"
fi

# 8.3: Copyrighted scan / book page in public area
HITS=$(printf '%s\n' "$ALL_TRACKED" | grep -iE "(攻略集|說明書|攻略書).*\.(pdf|png|jpg)|scan.*\.(pdf|png|jpg)|.+book.+page.*\.(pdf|png|jpg)" | grep -v "_local/")
if [ -z "$HITS" ]; then
  print_pass "8.3 No copyrighted scans in public files"
else
  echo "$HITS" | head -5
  print_fail "8.3 Copyrighted scan in public area"
fi

# 8.4: Positive copyright disclaimer present (at least one file)
DISCLAIMER_OK=$(echo "$PUB_FILES" | xargs -I{} grep -lE "(著作權|copyright|fair use|公平使用|事實層|創作性表現)" {} 2>/dev/null | wc -l | tr -d ' ')
if [ "$DISCLAIMER_OK" -gt 0 ]; then
  print_pass "8.4 Copyright disclaimer present in $DISCLAIMER_OK file(s)"
else
  print_warn "8.4 No copyright disclaimer detected"
fi

# 8.5: Non-existent TW copyright article (BLOCKER) — §10-2 does not exist; idea-expression is §10-1
HITS=$(echo "$PUB_FILES" | xargs -I{} grep -nE "§10-2|第 ?10-2 條|10 條之 2" {} 2>/dev/null | head -5)
if [ -z "$HITS" ]; then
  print_pass "8.5 No non-existent TW article §10-2 (correct is §10-1)"
else
  echo "$HITS" | head -5
  print_fail "8.5 Wrong TW citation §10-2 (does not exist — use §10-1 idea-expression)"
fi

# A9. Draft / WIP markers (WARN)
print_section "[A9] Draft / WIP markers (WARN)"
HITS=$(echo "$PUB_FILES" | xargs -I{} grep -nE "\bTBD\b|\bFIXME\b|\bXXX\b|施工中|未完成|coming soon|[Dd]raft\s+(version|content|文件)" {} 2>/dev/null \
  | grep -vE "(待擴充|TODO\.md|未完成 \(NEW)")
if [ -z "$HITS" ]; then
  print_pass "No draft markers"
else
  echo "$HITS" | head -5
  print_warn "Draft markers found"
fi

# A10. Pirate / infringement site URLs / names (BLOCKER, 2026-05-12 toni 永久規則 #7)
# 不公告盜版/侵權站,即使批判語境也算變相宣傳
print_section "[A10] Pirate / infringement site URLs / names (BLOCKER)"
HITS=$(echo "$PUB_FILES" | xargs -I{} grep -nE "wanyx|gamenoir|dos\.zczc|dosgameol|3DM[^v]|好游快爆|游侠|ggheart|blogspot\.com|mediafire\.com|百度网盘|百度網盤" {} 2>/dev/null)
if [ -z "$HITS" ]; then
  print_pass "No pirate site URLs / names"
else
  echo "$HITS" | head -8
  print_fail "A10: Pirate / infringement site URLs or names found — remove per absolute rule #7"
fi

# A11. fetch() error handler check (WARN, W49 Security Audit B1)
# 對每個含 fetch 的檔案,檢查整檔是否有 .catch / try-catch
print_section "[A11] fetch() without error handler (WARN — defensive)"
MISSING_CATCH=""
for f in $PUB_FILES; do
  if grep -q "fetch(" "$f" 2>/dev/null; then
    if ! grep -qE "\.catch\(|try\s*\{|catch\s*\(" "$f" 2>/dev/null; then
      MISSING_CATCH="$MISSING_CATCH $(basename $f)"
    fi
  fi
done
if [ -z "$MISSING_CATCH" ]; then
  print_pass "All files with fetch() have error handler"
else
  print_warn "Files with fetch() but no .catch / try-catch:$MISSING_CATCH"
fi

# A12. file.size pre-check guard (WARN, W49 Security Audit B2)
# Binary viewer/editor 應該在 FileReader 前驗 file.size,避免 OOM
print_section "[A12] file.size pre-check in binary viewers (WARN — defensive)"
# $PUB_FILES 已經是換行分隔的,tr 是多餘的 —— 而且有害:含空白的路徑會被切成
# 兩段不存在的檔名,而找不到檔案是靜默失敗、判定為「沒問題」。
VIEWERS=$(printf '%s\n' "$PUB_FILES" | grep -E "viewer|editor|modifier|dashboard" | grep "\.html$")
if [ -z "$VIEWERS" ]; then
  print_pass "No binary viewer files found"
else
  MISSING=""
  for v in $VIEWERS; do
    if grep -q "readAsArrayBuffer\|FileReader" "$v" 2>/dev/null; then
      if ! grep -qE "file\.size\s*[><=!]" "$v" 2>/dev/null; then
        MISSING="$MISSING $(basename $v)"
      fi
    fi
  done
  if [ -z "$MISSING" ]; then
    print_pass "All binary viewers have file.size pre-check"
  else
    print_warn "Missing file.size pre-check:$MISSING"
  fi
fi

# A13. Inline event handler check (WARN, W49 Security Audit Phase C)
# onclick= / onload= / onerror= 等 inline JS 違反 CSP best practice
# DOM-only rule 強制 addEventListener,inline handler 是 anti-pattern
print_section "[A13] Inline event handlers (WARN — DOM-only rule)"
HITS=$(echo "$PUB_FILES" | xargs -I{} grep -nE "\son(click|load|error|mouseover|mouseout|change|submit|focus|blur|keydown|keyup|keypress)\s*=\s*[\"']" {} 2>/dev/null)
if [ -z "$HITS" ]; then
  print_pass "No inline event handlers (DOM-only rule maintained)"
else
  echo "$HITS" | head -5
  COUNT=$(echo "$HITS" | wc -l | tr -d ' ')
  print_warn "Found $COUNT inline event handler(s) — prefer addEventListener"
fi

# A14. Mojibake / U+FFFD replacement char (BLOCKER, W110 mojibake audit)
# U+FFFD = decode-failure artifact. Catches the Big5/EUDC/encoding bugs fixed in
# W110 (item names, recipe bullets, BBS guide chars, Big5 @-delimiter truncation).
# 發現新破字 pattern → 加進此條形成永久防線(LD 規則)。
# 全站零容忍(W110:godseye 混合編碼 cp932/cp950 per-line decode 已修,無白名單)。
print_section "[A14] Mojibake: replacement / private-use / control chars (BLOCKER)"
A14_HITS=$(printf '%s\n' "$PUB_FILES" | python3 -c "
import sys, os, re
# 這個站的資料是從 Big5 與 cp932 老檔抽出來的，破字不只 U+FFFD 一種型態。
# 私用區字元來自 Big5 造字區誤映（框線會變成空白方塊），控制字元來自截斷，
# 兩者全站目前都是 0，所以可以零白名單直接擋。
# 西里爾與希臘字母另外處理：站上有兩處是刻意展示 cp950 誤映的例子，
# 同一行有說明文字時放行，沒說明的才算破字。
PUA = re.compile(r'[\ue000-\uf8ff]')
CTRL = re.compile(r'[\x00-\x08\x0b\x0c\x0e-\x1f]')
CYRGRK = re.compile(r'[\u0400-\u04ff\u0370-\u03ff]')
EXPLAIN = re.compile(r'cp950|Big5|big5|顯示為|誤映|亂碼|未翻譯|編碼')
for f in sys.stdin.read().splitlines():
    f = f.strip()
    if not f: continue
    if not os.path.isfile(f):
        print(f + '  [UNREADABLE: not found]'); continue
    try:
        with open(f, encoding='utf-8') as fh: data = fh.read()
    except UnicodeDecodeError:
        print(f + '  [UNREADABLE: not valid UTF-8]'); continue
    except OSError as e:
        print(f + '  [UNREADABLE: ' + e.__class__.__name__ + ']'); continue
    if '\ufffd' in data: print(f + '  [U+FFFD replacement char]')
    if PUA.search(data): print(f + '  [private use area char]')
    if CTRL.search(data): print(f + '  [control char]')
    for n, line in enumerate(data.split('\n'), 1):
        if CYRGRK.search(line) and not EXPLAIN.search(line):
            print(f + ':' + str(n) + '  [cyrillic/greek amid CJK]')
" 2>&1)
A14_RC=$?
if [ "$A14_RC" -ne 0 ]; then
  printf '%s\n' "$A14_HITS" | tail -4 | sed 's/^/    /'
  print_fail "A14 check could not run (exit $A14_RC) - not reporting it as passed"
elif [ -z "$A14_HITS" ]; then
  print_pass "No mojibake in any public file"
else
  echo "$A14_HITS" | head -10
  COUNT=$(echo "$A14_HITS" | grep -c .)
  print_fail "Found mojibake in $COUNT place(s) — decode failure, must fix"
fi

# A15. SEO/a11y anchors that page regeneration silently drops (BLOCKER)
# Rebuilding a guide page rewrites the whole file, and the canonical link,
# structured data and skip link are injected afterwards — so a rebuild without
# the post-processing chain leaves pages that look fine but lost all of it.
print_section "[A15] Canonical / structured data / skip link (BLOCKER)"
A15_MISSING=$(printf '%s\n' "$PUB_FILES" | grep -E "\.html$" | while read -r f; do
  [ -f "$f" ] || continue
  # 自測的餌檔要排除，但豁免只在自測時生效：以檔名為條件的永久豁免，
  # 對任何真的叫 canary_* 的發佈頁面同樣有效，那是一條以命名繞過 BLOCKER 的路。
  if [ -n "${LD_AUDIT_SELFTEST:-}" ]; then
    [[ "$(basename "$f")" == canary_* ]] && continue
  fi
  miss=""
  grep -q 'rel="canonical"' "$f" || miss="$miss canonical"
  grep -q 'application/ld+json' "$f" || miss="$miss json-ld"
  grep -q 'class="skip-link"' "$f" || miss="$miss skip-link"
  [ -n "$miss" ] && echo "  $f —$miss"
done)
if [ -z "$A15_MISSING" ]; then
  print_pass "Every page carries canonical, structured data and a skip link"
else
  echo "$A15_MISSING" | head -10
  COUNT=$(echo "$A15_MISSING" | grep -c .)
  print_fail "$COUNT page(s) missing SEO/a11y anchors — did a rebuild skip the post-processing chain?"
fi

# A16. sitemap lastmod must not predate the file's last commit (BLOCKER)
# Search engines only trust lastmod when it is consistently right; once a large
# share of it is wrong they ignore the whole signal. Dates drift because the
# sitemap is maintained by hand while the pages keep changing.
print_section "[A16] sitemap lastmod freshness (BLOCKER)"
A16_STALE=$(LD_AUDIT_GIT_ROOT="$GIT_ROOT" python3 - 2>&1 <<'PYEOF'
import os, re, subprocess
BASE = 'https://toniliumvp.github.io/LunaticDawn/'
try:
    sm = open('sitemap.xml', encoding='utf-8').read()
except OSError:
    print('sitemap.xml unreadable'); raise SystemExit
# 一次取出所有檔案的最後提交日，避免每個 URL 都跑一次 git
last = {}
# 歷史一定要跟真實 repo 拿：掃索引副本時 cwd 沒有 .git，
# 查不到日期就沒有比對對象，整條規則會變成永遠通過。
git_root = os.environ.get('LD_AUDIT_GIT_ROOT') or '.'
log = subprocess.run(['git', '-C', git_root, '-c', 'core.quotePath=false', 'log',
                      '--date=short', '--format=%ad', '--name-only'],
                     capture_output=True, text=True).stdout
if not log.strip():
    print('  cannot read git history - refusing to report this check as passed')
    raise SystemExit(1)
cur = None
for line in log.split('\n'):
    line = line.strip()
    if re.fullmatch(r'\d{4}-\d{2}-\d{2}', line):
        cur = line
    elif line and cur:
        last.setdefault(line, cur)
for loc, lm in re.findall(r'<loc>([^<]+)</loc>\s*<lastmod>([^<]+)</lastmod>', sm):
    rel = loc[len(BASE):] if loc.startswith(BASE) else ''
    if not rel or rel.endswith('/'):
        rel = (rel or '') + 'index.html'
    d = last.get(rel)
    if d and lm < d:
        print(f'  {rel}: sitemap={lm} last commit={d}')
PYEOF
)
A16_RC=$?
if [ "$A16_RC" -ne 0 ]; then
  printf '%s\n' "$A16_STALE" | tail -4 | sed 's/^/    /'
  print_fail "A16 check could not run (exit $A16_RC) - not reporting it as passed"
elif [ -z "$A16_STALE" ]; then
  print_pass "Every sitemap entry is at least as new as its file"
else
  echo "$A16_STALE" | head -10
  COUNT=$(echo "$A16_STALE" | grep -c .)
  print_fail "$COUNT sitemap entry(ies) older than the file they point at"
fi

# A17. History layer: the other 16 checks all read `git ls-files`, which is the
# HEAD tree. Anything that was ever committed stays reachable through the API
# by SHA even after it is removed from HEAD, so a check that only reads HEAD
# reports clean on a repo that is still serving the thing it was meant to catch.
#
# A17.1 looks at paths that ever existed. A17.2 looks at commit messages, which
# GitHub renders in full -- subject and body -- to anonymous visitors. The old
# check for that ran `git log --oneline -20`: no bodies, last twenty only.
print_section "[A17] History layer: paths and commit messages (BLOCKER)"
A17_OUT=$(LD_AUDIT_GIT_ROOT="$GIT_ROOT" python3 - 2>&1 <<'PYEOF'
import os, re, subprocess, sys

root = os.environ.get('LD_AUDIT_GIT_ROOT') or '.'

def git(*args):
    return subprocess.run(['git', '-C', root, '-c', 'core.quotePath=false', *args],
                          capture_output=True, text=True).stdout

# A17.1 -- paths that ever existed anywhere in history.
objs = git('rev-list', '--objects', '--all')
if not objs.strip():
    print('  cannot read git history - refusing to report this check as passed')
    sys.exit(1)

PATH_PATTERNS = [
    ('copyrighted scan', re.compile(r'pdf-pages|書掃|攻略集.*\.(png|jpe?g)$|scan.*page', re.I)),
    ('credential file',  re.compile(r'(^|/)\.env$|\.pem$|\.key$|credentials|secrets', re.I)),
]
path_hits = []
for line in objs.splitlines():
    parts = line.split(' ', 1)
    if len(parts) < 2:
        continue
    sha, path = parts
    for name, pat in PATH_PATTERNS:
        if pat.search(path):
            path_hits.append(f'  A17.1 {name}: {path} (blob {sha[:10]})')

# A17.2 -- commit messages across all of history.
MSG_RULES = [
    ('cjk',      re.compile(r'[一-鿿぀-ヿ]')),
    ('wave',     re.compile(r'第[一二三四五六七八九十百零0-9]{1,4}波|波次|wave\s*\d|round-?\d|\bW\d{2,3}\b', re.I)),
    ('planning', re.compile(r'\bPENDING\b|\bP[0-3]\b|scope 校正|milestone|carry-over', re.I)),
    ('name',     re.compile(r'\btoni\b', re.I)),
    ('ai',       re.compile(r'co-authored-by:\s*claude', re.I)),
]

baseline = set()
bl_path = os.path.join(root, 'tools', 'audit', 'history-baseline.txt')
if os.path.exists(bl_path):
    for line in open(bl_path, encoding='utf-8'):
        line = line.strip()
        if line and not line.startswith('#'):
            baseline.add(line.split()[0])

log = git('log', '--all', '--format=%H%x09%s%x1f%b%x1e')
if not log.strip():
    print('  cannot read commit messages - refusing to report this check as passed')
    sys.exit(1)

known, new = 0, []
for rec in log.split('\x1e'):
    rec = rec.strip()
    if not rec:
        continue
    head, _, body = rec.partition('\x1f')
    sha, _, subj = head.partition('\t')
    text = subj + '\n' + body
    kinds = sorted({n for n, p in MSG_RULES if p.search(text)})
    if not kinds:
        continue
    if sha in baseline:
        known += 1
    else:
        new.append(f'  A17.2 non-generic message [{",".join(kinds)}]: {sha[:10]} {subj[:64]}')

for h in path_hits:
    print(h)
for h in new:
    print(h)
if known:
    print(f'  NOTE {known} older commit(s) carry non-generic messages, listed in '
          f'tools/audit/history-baseline.txt. They are reachable by SHA through '
          f'the API; rewriting history would empty that file.')
PYEOF
)
A17_RC=$?
A17_HITS=$(echo "$A17_OUT" | grep -c '^  A17\.' || true)
A17_NOTE=$(echo "$A17_OUT" | grep '^  NOTE' || true)
if [ "$A17_RC" -ne 0 ]; then
  printf '%s\n' "$A17_OUT" | tail -4 | sed 's/^/    /'
  print_fail "A17 check could not run (exit $A17_RC) - not reporting it as passed"
elif [ "$A17_HITS" -eq 0 ]; then
  print_pass "No new history-layer leakage"
  [ -n "$A17_NOTE" ] && echo "$A17_NOTE"
else
  echo "$A17_OUT" | grep '^  A17\.' | head -12
  print_fail "$A17_HITS history-layer leak(s) not on the accepted baseline"
  [ -n "$A17_NOTE" ] && echo "$A17_NOTE"
fi

# A18. Unredacted poster addresses in archived BBS text (BLOCKER)
# The post-processing chain redacts these, but the chain is fail-fast and the
# redaction step was one of six: any earlier step failing meant the pages were
# already on disk with the original reverse-DNS hostnames in them, and nothing
# here would have noticed -- A7 only looks at email addresses.
# So this rule is deliberately independent of whether that chain ran at all,
# because someone can also run a generator directly and skip the chain.
#
# It matches the source-field shapes rather than bare IPv4: every dotted quad
# on this site is a version number or localhost, and flagging those would only
# train people to ignore the output.
print_section "[A18] Unredacted BBS poster addresses (BLOCKER)"
# The file list travels in an environment variable, not on stdin: the heredoc
# already occupies stdin to feed the interpreter its source, so piping the list
# in as well means the heredoc wins, the loop never runs a single iteration --
# and the rule prints a tick. The first version of this check was dead that way
# and only three planted samples revealed it.
A18_OUT=$(LD_AUDIT_PUB="$PUB_FILES" python3 - 2>&1 <<'PYEOF'
import sys, os, re

MARK = r'\[?historical IP redacted'
RULES = [
    ('unredacted Origin/From',
     re.compile(r'※\s*Origin:[^\n]{0,120}?◆\s*From:\s*(?!' + MARK + r')[^\s<][^\n<]{0,80}')),
    ('unredacted 修改 field',
     re.compile(r'※\s*修改:\s*[0-9/: ]{0,30}\[(?!' + MARK + r')[^\]\n]{1,80}\]')),
    ('reverse-DNS hostname',
     re.compile(r'\b\d{1,3}-\d{1,3}-\d{1,3}-\d{1,3}\.[a-z0-9][a-z0-9.-]{2,}', re.I)),
]

files = os.environ.get('LD_AUDIT_PUB', '')
if not files.strip():
    print('  cannot read the file list - refusing to report this check as passed')
    sys.exit(1)

for f in files.splitlines():
    f = f.strip()
    if not f or not f.endswith('.html'):
        continue
    if not os.path.isfile(f):
        continue
    try:
        t = open(f, encoding='utf-8', errors='replace').read()
    except OSError:
        continue
    for name, pat in RULES:
        for m in pat.finditer(t):
            line = t[:m.start()].count('\n') + 1
            print(f'  {f}:{line}: {name}: {m.group(0)[:70]}')
PYEOF
)
A18_RC=$?
if [ "$A18_RC" -ne 0 ]; then
  printf '%s\n' "$A18_OUT" | tail -4 | sed 's/^/    /'
  print_fail "A18 check could not run (exit $A18_RC) - not reporting it as passed"
elif [ -z "$A18_OUT" ]; then
  print_pass "No unredacted poster addresses in archived BBS text"
else
  echo "$A18_OUT" | head -10
  A18_N=$(echo "$A18_OUT" | grep -c .)
  print_fail "$A18_N unredacted poster address(es) - the redaction step did not run"
fi

# Summary
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  AUDIT SUMMARY"
echo "════════════════════════════════════════════════════════════"
echo "  Files scanned: $NUM_FILES (git-tracked only — gitignored files NOT checked)"
echo "  Blockers:  $BLOCKERS"
echo "  Warnings:  $WARNINGS"

if [ $BLOCKERS -eq 0 ] && { [ $WARNINGS -eq 0 ] || [ $STRICT -eq 0 ]; }; then
  echo "  Status: ✓ CLEAN (safe to commit)"
  exit 0
else
  if [ $BLOCKERS -gt 0 ]; then
    echo "  Status: ✗ BLOCKED ($BLOCKERS blocker(s) — fix before commit)"
  else
    echo "  Status: ⚠ STRICT MODE ($WARNINGS warning(s) blocked commit)"
  fi
  exit 1
fi
