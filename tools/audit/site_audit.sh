#!/usr/bin/env bash
# Public site audit: runs every check in this file before commit.
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
# Environment (set by the hooks; a manual run needs none of them):
#   LD_AUDIT_ROOT    audit this directory (an export of the index or of HEAD)
#                    instead of the working tree
#   LD_AUDIT_FILES   newline separated file list to audit; with LD_AUDIT_ROOT it
#                    has to match the directory exactly
#   LD_AUDIT_STAGED  set by pre-commit only: A16 holds the sitemap to today for
#                    pages in the commit being made
#
# A rule that cannot do its job (a tool missing or crashing, a file it could not
# read) fails with "could not run". It never reads as a pass: nothing found and
# nothing run have to look different. What a rule says it looked at is held
# against counts the shell takes itself (the files it listed, a plain grep for
# the same pattern), so a rule whose filter or pattern stopped matching fails
# instead of reporting an empty, clean result.
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
# LD_AUDIT_FILES, when set (even to nothing), is the file list to audit: the
# pre-commit hook passes the index listing that way. An empty list then falls
# through to the "no files" guard below instead of silently switching to a
# different source.
if [ "${LD_AUDIT_FILES+set}" = set ]; then
  ALL_TRACKED="$LD_AUDIT_FILES"
else
  GIT_ERR=$(mktemp "${TMPDIR:-/tmp}/site_audit_git.XXXXXX") || { echo "✗ cannot create a scratch file for the audit"; exit 1; }
  ALL_TRACKED=$(git -c core.quotePath=false ls-files 2>"$GIT_ERR")
  GIT_RC=$?
  if [ "$GIT_RC" -ne 0 ]; then
    echo "✗ git ls-files failed (exit $GIT_RC), so the audit cannot list the files to scan."
    sed 's/^/    /' "$GIT_ERR" | head -3
    rm -f "$GIT_ERR"
    exit 1
  fi
  rm -f "$GIT_ERR"
fi
PUB_FILES=$(printf '%s\n' "$ALL_TRACKED" \
  | grep -E "\.(html|js|json|xml|css|md|txt|svg|py|sh|command|bat|yml|conf)$|^LICENSE$" \
  | grep -v "^_local/" \
  | grep -v "^tools/audit/" 2>/dev/null \
  || true)

# When auditing the working tree by hand, a tracked file that was deleted but
# not yet staged is not a violation and not a reason to abort every rule with
# "No such file". Skip it and say so. With LD_AUDIT_ROOT set (hook, selftest,
# HEAD export) the list must match the directory exactly, so a missing file
# stays an error there.
if [ -z "${LD_AUDIT_ROOT:-}" ] && [ -n "$PUB_FILES" ]; then
  KEPT=""
  MISSING_N=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ -f "$f" ]; then
      KEPT="${KEPT}${f}"$'\n'
    else
      MISSING_N=$((MISSING_N+1))
    fi
  done <<< "$PUB_FILES"
  PUB_FILES=$(printf '%s' "$KEPT")
  if [ "$MISSING_N" -gt 0 ]; then
    echo "  Note: $MISSING_N tracked file(s) missing from the working tree, skipped"
  fi
fi

# An empty file list means the audit is looking at the wrong place: a git repo
# with nothing tracked, or a wrong working directory. Report that instead of
# counting the empty string as one file and declaring the site clean. (A git
# failure is reported separately above, with its own exit code.)
if [ -z "$PUB_FILES" ]; then
  echo "✗ Audit found no files to scan. Wrong directory, or nothing tracked here?"
  echo "  (Expected to run from the site root, with git tracking the public files.)"
  exit 1
fi

NUM_FILES=$(printf '%s\n' "$PUB_FILES" | wc -l | tr -d ' ')

# Counts the shell takes itself, so that what a rule says it looked at can be held
# against them. A rule that was handed N files and reports fewer did not do its job
# (a file filter that stopped matching, a pattern that matches nothing), and
# nothing found has to look different from nothing run.
HTML_N=0
JS_N=0
while IFS= read -r _f; do
  case "$_f" in
    '') ;;
    *.html) HTML_N=$((HTML_N+1)) ;;
    *.js) JS_N=$((JS_N+1)) ;;
  esac
done <<< "$PUB_FILES"
ALL_N=0
while IFS= read -r _f; do
  if [ -n "$_f" ]; then ALL_N=$((ALL_N+1)); fi
done <<< "$ALL_TRACKED"
count_lines() { local n=0 l; while IFS= read -r l; do if [ -n "$l" ]; then n=$((n+1)); fi; done <<< "$1"; echo "$n"; }
summary_field() { printf '%s' "$1" | sed -n "s/.* $2=\([0-9][0-9]*\).*/\1/p"; }
# A rule that reports finding no call sites is held against a plain grep, which shares
# no code with it: when that grep still sees the pattern in some html/js file, the
# rule has lost its pattern or its parser, and "no problems" would be a false green.
# Returns 0 (with UNSEEN_MSG set) when the report cannot be trusted.
unseen_sites() {  # unseen_sites <sites> <extended regex>
  [ "$1" = 0 ] || return 1
  local out n
  out=$(grep_pub -lE "$2")
  if pub_grep_failed; then UNSEEN_MSG="the cross-check grep could not run"; return 0; fi
  n=$(printf '%s\n' "$out" | grep -cE '\.(html|js)$')
  if [ "$n" -gt 0 ]; then UNSEEN_MSG="it found no call sites, yet $n html/js file(s) still mention them"; return 0; fi
  return 1
}
FETCH_RAW_RE='(^|[^[:alnum:]_$.])fetch[[:space:]]*\(|(window|self|globalThis)\.fetch[[:space:]]*\('
READ_RAW_RE='readAs(ArrayBuffer|Text|DataURL|BinaryString)[[:space:]]*\(|\.[[:space:]]*(arrayBuffer|text)[[:space:]]*\([[:space:]]*\)'

# Run one grep over every public file. NUL-separated input means quotes and
# spaces in paths cannot stop xargs, and stderr is kept: a grep that could not
# run (bad pattern, unreadable file) is reported as such instead of reading as
# "no hits". -H is always passed by the callers so every hit names its file.
# The grep runs inside a small shell that reports an exit status of 2 or more on
# stderr itself: xargs folds every non-zero status into one value, and a grep
# that dies without a word would otherwise look like a clean run.
PUB_ERR=$(mktemp "${TMPDIR:-/tmp}/site_audit_err.XXXXXX") || { echo "✗ cannot create a scratch file for the audit"; exit 1; }
PUB_RAN=$(mktemp "${TMPDIR:-/tmp}/site_audit_ran.XXXXXX") || { echo "✗ cannot create a scratch file for the audit"; exit 1; }
trap 'rm -f "$PUB_ERR" "$PUB_RAN"' EXIT
grep_pub() {  # grep_pub <flags> <pattern>
  : > "$PUB_ERR"
  : > "$PUB_RAN"
  # fd 3 records that a grep was really started: an xargs that does nothing and
  # exits 0 would otherwise look like a search that found nothing.
  printf '%s\n' "$PUB_FILES" | tr '\n' '\0' \
    | xargs -0 /bin/sh -c 'echo ran >&3; grep "$@"; r=$?; if [ "$r" -ge 2 ]; then echo "grep exited with status $r" >&2; fi; exit 0' sh "$1" -- "$2" 2>>"$PUB_ERR" 3>>"$PUB_RAN"
  local rc=$?
  [ "$rc" -eq 0 ] || echo "xargs exited with status $rc" >> "$PUB_ERR"
  [ -s "$PUB_RAN" ] || echo "no grep was started" >> "$PUB_ERR"
  return 0
}
pub_grep_failed() { [ -s "$PUB_ERR" ] && { sed 's/^/    /' "$PUB_ERR" | head -3; return 0; }; return 1; }

# Python-backed rules finish with a line "OK <hits> <scanned>". Without it the
# interpreter did not run to the end (a crash, or a stand-in that exits 0 and
# prints nothing), whatever its exit status says, and the rule must not pass.
py_done() { local last="${1##*$'\n'}"; [[ "$last" == "OK "* ]]; }
py_body() { local s="$1"; case "$s" in *$'\n'*) printf '%s' "${s%$'\n'*}" ;; *) : ;; esac; }
py_field() {  # py_field <output> <index>: 0 = hits, 1 = scanned, 2 = unreadable
  local last="${1##*$'\n'}" parts=()
  last="${last#OK }"
  read -r -a parts <<< "$last"
  printf '%s' "${parts[$2]:-0}"
}

# Drop the hits whose content (not the file name in front of it) matches an
# accepted form. Done here and not in a second grep so that a filter that fails
# to run is noticed, and so a file name cannot get a hit excused.
IFS= read -r -d '' FILTER_PY <<'PYEOF'
import os, re, sys

accept = os.environ.get('LD_AUDIT_ACCEPT', '')
if not accept:
    print('  internal error: the accepted-forms pattern is missing', file=sys.stderr)
    sys.exit(2)
rx = re.compile(accept)
kept, n = [], 0
for line in sys.stdin.buffer.read().decode('utf-8', 'replace').split('\n'):
    if not line:
        continue
    n += 1
    m = re.match(r'(.*?):(\d+):(.*)\Z', line, re.S)
    if not rx.search(m.group(3) if m else line):
        kept.append(line)
for k in kept:
    print(k)
print('OK %d %d' % (len(kept), n))
PYEOF
filter_hits() { LD_AUDIT_ACCEPT="$1" python3 -c "$FILTER_PY" 2>&1; }


# A1. Internal wave/round/PENDING jargon (BLOCKER)
# 也包含 W## (W08 / W14 / W56 等) - 內部 wave 編號縮寫
print_section "[A1] Internal development jargon (BLOCKER)"
A1_RE='第[一二三四五六七八九十百零壹貳參肆伍陸柒捌玖拾佰0-9]+波|第\s*[0-9]+\s*波|第[一二三四五六七八九十百零0-9][一二三四五六七八九十百零0-9　 ／/、]*[／/][一二三四五六七八九十百零0-9　 ／/、]*波|wave\s*[0-9]+|Wave\s*[0-9]+|round-[0-9]+|Round[ _]?[0-9]+|\b[wW][0-9][0-9]+\b|波次|PENDING|⏳[^：）)]*規劃|scope[- ]?校正|carry[- ]?over|toni\s+(戳穿|挑戰|個人|指示)|逆向工程依賴|反組譯依賴|未完成事項|\bP[0-3]\b|milestone|第\s*[0-9]+\s*輪'
# The exclusion words are not applied by dropping every line they appear on: that
# would also drop a real violation sharing the line (a company name that contains
# the excluded words, printed next to a numbered reference of the kind this rule
# exists to catch). Each hit has the exclusion words blanked out and is then run
# through the main pattern again; only what still matches is a violation. A hit with no file:line prefix (grep's
# "Binary file X matches") cannot be tested again and is reported as it stands.
IFS= read -r -d '' A1_PY <<'PYEOF'
import os, re, subprocess, sys

main = os.environ.get('LD_AUDIT_A1_RE', '')
if not main:
    print('  internal error: the A1 pattern is missing', file=sys.stderr)
    sys.exit(2)

EXCLUDE = re.compile('|'.join([
    '台灣第三波', '第三波文化', '第三波代理', '第三波伺服器', '第三波修改', '第三波網頁',
    '第三波發行', '第三波官方', '第三波的俠客遊', '第三波繁中', '第三波中文',
    r'第三波(?=\s*/)', '第三波(?!波)', r'0\.[0-9]+s', r'height="[0-9]+', r'width="[0-9]+',
]))

# The second pass has to prove it ran. Its input starts with a control line that the
# main pattern is known to match; if the control line does not come back, grep did not
# do its job (it can exit 0 and say nothing), and "no hits" would be a false green.
# A line the exclusion step left untouched was a hit in the first pass and has to be
# one again, so a missing one means the two passes disagree. Either way: stop.
CONTROL = 'wave 1'
rows, direct, scanned = [], [], 0
for line in sys.stdin.buffer.read().decode('utf-8', 'replace').split('\n'):
    if not line.strip():
        continue
    scanned += 1
    m = re.match(r'(.*?):(\d+):(.*)\Z', line, re.S)
    if m:
        text = m.group(3).replace('\0', ' ')
        blanked = EXCLUDE.sub(' ', text)
        rows.append((line, blanked, blanked == text))
    else:
        direct.append(line)

hits = list(direct)
if rows:
    texts = [CONTROL] + [r[1] for r in rows]
    p = subprocess.run(['grep', '-nE', '--', main],
                       input=('\n'.join(texts) + '\n').encode('utf-8'),
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode not in (0, 1):
        sys.stderr.write(p.stderr.decode('utf-8', 'replace'))
        sys.exit(2)
    seen = set()
    for res in p.stdout.decode('utf-8', 'replace').split('\n'):
        if not res:
            continue
        n = re.match(r'(\d+):', res)
        if not n:
            print('  unexpected output from the second pass: ' + res[:80], file=sys.stderr)
            sys.exit(2)
        seen.add(int(n.group(1)))
    if 1 not in seen:
        print('  the second pass did not report its control line, so it cannot be trusted', file=sys.stderr)
        sys.exit(2)
    for i, (orig, blanked, untouched) in enumerate(rows):
        if i + 2 in seen:
            hits.append(orig)
        elif untouched:
            print('  the second pass lost a hit the first pass reported: ' + orig[:80], file=sys.stderr)
            sys.exit(2)
for h in hits:
    print(h)
print('OK %d %d' % (len(hits), scanned))
PYEOF
A1_RAW=$(grep_pub -HnE "$A1_RE")
if pub_grep_failed; then
  print_fail "A1 check could not run - not reporting it as passed"
else
  A1_OUT=$(printf '%s\n' "$A1_RAW" | LD_AUDIT_A1_RE="$A1_RE" python3 -c "$A1_PY" 2>&1); A1_RC=$?
  if [ "$A1_RC" -ne 0 ] || ! py_done "$A1_OUT"; then
    printf '%s\n' "$A1_OUT" | tail -4 | sed 's/^/    /'
    print_fail "A1 check could not run (exit $A1_RC) - not reporting it as passed"
  elif [ "$(py_field "$A1_OUT" 1)" != "$(count_lines "$A1_RAW")" ]; then
    print_fail "A1 check could not run (it examined $(py_field "$A1_OUT" 1) of $(count_lines "$A1_RAW") hit line(s)) - not reporting it as passed"
  else
    HITS=$(py_body "$A1_OUT")
    if [ -z "$HITS" ]; then
      print_pass "No internal dev jargon"
    else
      echo "$HITS" | head -10
      print_fail "Internal dev jargon ($(py_field "$A1_OUT" 0) hits)"
    fi
  fi
fi

# A2. Personal dev paths (BLOCKER) — /Volumes/Work/, NAS paths
# Public path EXAMPLES should use a generic placeholder (/Users/player/), NOT toni's
# actual macOS username. Real leaks: /Volumes/Work/LD/, NAS smb paths, "Mac Mini M4".
print_section "[A2] Personal dev paths / NAS leakage (BLOCKER)"
HITS=$(grep_pub -HnE "/Volumes/(Work|918|Mac Mini M4|Scratch|PLEXTOR|Toni-NAS)/|/Users/toni/|smb://(toni|toniLiu|Mac)|toniLiuMVP\._smb|918%20%E8%B3%87|~/\.claude/|/\.claude/")
if pub_grep_failed; then
  print_fail "A2 check could not run - not reporting it as passed"
elif [ -z "$HITS" ]; then
  print_pass "No personal dev paths leaked"
else
  echo "$HITS" | head -10
  print_fail "Personal dev paths leaked"
fi

# A3. Credentials / secrets pattern (BLOCKER)
print_section "[A3] Credentials / API keys (BLOCKER)"
HITS=$(grep_pub -HnE "(api[_-]?key|secret[_-]?key|password|access[_-]?token)[\"']?\s*[=:]\s*[\"'][a-zA-Z0-9]{16,}|AKIA[0-9A-Z]{16}|sk_live_|ghp_[a-zA-Z0-9]{36}|-----BEGIN [A-Z]")
if pub_grep_failed; then
  print_fail "A3 check could not run - not reporting it as passed"
elif [ -z "$HITS" ]; then
  print_pass "No credentials"
else
  echo "$HITS" | head -10
  print_fail "Possible credentials detected"
fi

# A4. innerHTML XSS check (BLOCKER per CLAUDE.md DOM-only rule)
print_section "[A4] innerHTML usage (BLOCKER, DOM-only rule)"
HITS=$(grep_pub -HnE "\.innerHTML\s*\+?=|\.outerHTML\s*\+?=|insertAdjacentHTML\s*\(|document\.write(ln)?\s*\(")
if pub_grep_failed; then
  print_fail "A4 check could not run - not reporting it as passed"
elif [ -z "$HITS" ]; then
  print_pass "Pure DOM API"
else
  echo "$HITS" | head -10
  print_fail "innerHTML found"
fi

# A5. toni capitalization (BLOCKER, lowercase only)
print_section "[A5] toni naming consistency (BLOCKER)"
HITS=$(grep_pub -HnE "(\bToni\b|\bTONI\b|toni\s*大神|捅你)")
if pub_grep_failed; then
  print_fail "A5 check could not run - not reporting it as passed"
elif [ -z "$HITS" ]; then
  print_pass "toni naming consistent (lowercase 4-letter)"
else
  echo "$HITS" | head -10
  print_fail "Wrong toni capitalization"
fi

# A6. Low-level RE jargon (WARN)
# Whitelisted: "MFC CArchive" — standard Windows API name, legitimate technical context
print_section "[A6] Low-level RE jargon (WARN — review case-by-case)"
HITS=$(grep_pub -HnE "fcn\.[0-9a-f]+|filter-branch|self[- ]?correct|內化教訓|cross[- ]?project|RedTime\b|\bJYQXZ\b|\bSWDA\b|MVP_Baseball|\bAnzai\b|\bALLRM\b|跨專案[^著]|廣場留言|專案廣場")
if pub_grep_failed; then
  print_fail "A6 check could not run - not reporting it as passed"
elif [ -z "$HITS" ]; then
  print_pass "No low-level RE jargon"
else
  echo "$HITS" | head -10
  print_warn "Low-level RE references"
fi

# A7. Email PII (WARN — only toni's mailto allowed)
print_section "[A7] Email addresses (WARN — only toni's mailto)"
A7_RAW=$(grep_pub -HnE "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}")
if pub_grep_failed; then
  print_fail "A7 check could not run - not reporting it as passed"
else
  A7_OUT=$(printf '%s\n' "$A7_RAW" | filter_hits "(luntic\.dawn@gmail\.com|toni\.luna2@gmail\.com|noreply@anthropic\.com|noreply@github\.com|sender@company\.com|user@example\.com|john@example\.com|@example\.com|@example\.org|@2x\.png|@bbs\.|qazzaq\.bbs@|jesse\.bbs@|chiukm@ctimail3\.com)"); A7_RC=$?
  if [ "$A7_RC" -ne 0 ] || ! py_done "$A7_OUT"; then
    printf '%s\n' "$A7_OUT" | tail -4 | sed 's/^/    /'
    print_fail "A7 check could not run (exit $A7_RC) - not reporting it as passed"
  elif [ "$(py_field "$A7_OUT" 1)" != "$(count_lines "$A7_RAW")" ]; then
    print_fail "A7 check could not run (it examined $(py_field "$A7_OUT" 1) of $(count_lines "$A7_RAW") hit line(s)) - not reporting it as passed"
  else
    HITS=$(py_body "$A7_OUT")
    if [ -z "$HITS" ]; then
      print_pass "Only toni's email + BBS-archive emails"
    else
      echo "$HITS" | head -10
      print_warn "Other email addresses found"
    fi
  fi
fi

# A8. Triple-jurisdiction copyright check
print_section "[A8] Copyright (TW §10-1 + JP §2/§12-2 + US §102b/Feist/Sega)"

# 8.1: Forbidden v2.0 phrasing (BLOCKER)
HITS=$(grep_pub -HnE "攻略文件版權屬於原作者，本站僅|事實在二進制裡|逆向解析的完整資料庫")
if pub_grep_failed; then
  print_fail "8.1 check could not run - not reporting it as passed"
elif [ -z "$HITS" ]; then
  print_pass "8.1 No forbidden v2.0 phrasing"
else
  echo "$HITS" | head -3
  print_fail "8.1 Forbidden phrasing detected"
fi

# 8.2: Long literal quotes (>300 char single-string in HTML body)
A82_OUT=$(printf '%s\n' "$PUB_FILES" | python3 -c "
import sys, re
# 300+ char direct quotation = text inside real quotation markup.
# NOT a raw quote-mark span: in HTML those are attribute delimiters, so the old
# pattern measured markup distance, not quoted text (and BSD grep capped {300,} anyway).
PATS = [re.compile(r'\u300c[^\u300d]{300,}\u300d', re.S),
        re.compile(r'\u300e[^\u300f]{300,}\u300f', re.S),
        ]
# NOTE: deliberately NOT measuring whole <blockquote> containers — one blockquote may
# legitimately hold several short attributed quotes plus commentary. The fair-use risk
# is a single continuous verbatim passage, which the quote-mark spans above capture.
TAG = re.compile(r'<[^>]+>')
n, hits = 0, []
for line in sys.stdin:
    f = line.strip()
    if not f.endswith('.html'): continue
    n += 1
    try: t = open(f, encoding='utf-8', errors='replace').read()
    except OSError:
        print(f + '  [UNREADABLE]', file=sys.stderr); sys.exit(3)
    for pat in PATS:
        for m in pat.finditer(t):
            if len(TAG.sub('', m.group(0)).strip()) >= 300:
                hits.append(f'{f}: {len(TAG.sub(chr(32), m.group(0)))} chars quoted')
                break
for h in hits: print(h)
print('OK %d %d' % (len(hits), n))
" 2>&1)
A82_RC=$?
if [ "$A82_RC" -ne 0 ] || ! py_done "$A82_OUT"; then
  printf '%s\n' "$A82_OUT" | tail -4 | sed 's/^/    /'
  print_fail "8.2 check could not run (exit $A82_RC) - not reporting it as passed"
elif [ "$(py_field "$A82_OUT" 1)" != "$HTML_N" ]; then
  print_fail "8.2 check could not run (it looked at $(py_field "$A82_OUT" 1) of $HTML_N page(s)) - not reporting it as passed"
else
  HITS=$(py_body "$A82_OUT")
  if [ -z "$HITS" ]; then
    print_pass "8.2 No 300+ char literal quotes (fair use safe)"
  else
    printf '%s\n' "$HITS" | head -3
    print_warn "8.2 Long literal quotes (review for fair use)"
  fi
fi

# 8.3: Copyrighted scan / book page in public area
IFS= read -r -d '' A83_PY <<'PYEOF'
import re, sys

PAT = re.compile(r'(攻略集|說明書|攻略書).*\.(pdf|png|jpg)|scan.*\.(pdf|png|jpg)|.+book.+page.*\.(pdf|png|jpg)', re.I)
n, hits = 0, []
for line in sys.stdin.buffer.read().decode('utf-8', 'replace').split('\n'):
    f = line.strip('\r')
    if not f:
        continue
    n += 1
    if '_local/' not in f and PAT.search(f):
        hits.append(f)
if n == 0:
    print('  the tracked-file list is empty', file=sys.stderr)
    sys.exit(1)
for h in hits:
    print(h)
print('OK %d %d' % (len(hits), n))
PYEOF
A83_OUT=$(printf '%s\n' "$ALL_TRACKED" | python3 -c "$A83_PY" 2>&1); A83_RC=$?
if [ "$A83_RC" -ne 0 ] || ! py_done "$A83_OUT"; then
  printf '%s\n' "$A83_OUT" | tail -4 | sed 's/^/    /'
  print_fail "8.3 check could not run (exit $A83_RC) - not reporting it as passed"
elif [ "$(py_field "$A83_OUT" 1)" != "$ALL_N" ]; then
  print_fail "8.3 check could not run (it looked at $(py_field "$A83_OUT" 1) of $ALL_N tracked file(s)) - not reporting it as passed"
else
  HITS=$(py_body "$A83_OUT")
  if [ -z "$HITS" ]; then
    print_pass "8.3 No copyrighted scans in public files"
  else
    echo "$HITS" | head -5
    print_fail "8.3 Copyrighted scan in public area"
  fi
fi

# 8.4: Positive copyright disclaimer present (at least one file)
DISCLAIMER_OK=$(grep_pub -lE "(著作權|copyright|fair use|公平使用|事實層|創作性表現)" | wc -l | tr -d ' ')
if pub_grep_failed; then
  print_fail "8.4 check could not run - not reporting it as passed"
elif [ "$DISCLAIMER_OK" -gt 0 ]; then
  print_pass "8.4 Copyright disclaimer present in $DISCLAIMER_OK file(s)"
else
  print_warn "8.4 No copyright disclaimer detected"
fi

# 8.5: Non-existent TW copyright article (BLOCKER) — §10-2 does not exist; idea-expression is §10-1
HITS=$(grep_pub -HnE "§10-2|第 ?10-2 條|10 條之 2")
if pub_grep_failed; then
  print_fail "8.5 check could not run - not reporting it as passed"
elif [ -z "$HITS" ]; then
  print_pass "8.5 No non-existent TW article §10-2 (correct is §10-1)"
else
  echo "$HITS" | head -5
  print_fail "8.5 Wrong TW citation §10-2 (does not exist — use §10-1 idea-expression)"
fi

# A9. Draft / WIP markers (WARN)
print_section "[A9] Draft / WIP markers (WARN)"
A9_RAW=$(grep_pub -HnE "\bTBD\b|\bFIXME\b|\bXXX\b|施工中|未完成|coming soon|[Dd]raft\s+(version|content|文件)")
if pub_grep_failed; then
  print_fail "A9 check could not run - not reporting it as passed"
else
  A9_OUT=$(printf '%s\n' "$A9_RAW" | filter_hits "(待擴充|TODO\.md|未完成 \(NEW)"); A9_RC=$?
  if [ "$A9_RC" -ne 0 ] || ! py_done "$A9_OUT"; then
    printf '%s\n' "$A9_OUT" | tail -4 | sed 's/^/    /'
    print_fail "A9 check could not run (exit $A9_RC) - not reporting it as passed"
  elif [ "$(py_field "$A9_OUT" 1)" != "$(count_lines "$A9_RAW")" ]; then
    print_fail "A9 check could not run (it examined $(py_field "$A9_OUT" 1) of $(count_lines "$A9_RAW") hit line(s)) - not reporting it as passed"
  else
    HITS=$(py_body "$A9_OUT")
    if [ -z "$HITS" ]; then
      print_pass "No draft markers"
    else
      echo "$HITS" | head -5
      print_warn "Draft markers found"
    fi
  fi
fi

# A10. Pirate / infringement site URLs / names (BLOCKER, 2026-05-12 toni 永久規則 #7)
# 不公告盜版/侵權站,即使批判語境也算變相宣傳
print_section "[A10] Pirate / infringement site URLs / names (BLOCKER)"
HITS=$(grep_pub -HnE "wanyx|gamenoir|dos\.zczc|dosgameol|3DM[^v]|好游快爆|游侠|ggheart|blogspot\.com|mediafire\.com|百度网盘|百度網盤|daiseki|chiuinan")
if pub_grep_failed; then
  print_fail "A10 check could not run - not reporting it as passed"
elif [ -z "$HITS" ]; then
  print_pass "No pirate site URLs / names"
else
  echo "$HITS" | head -8
  print_fail "A10: Pirate / infringement site URLs or names found — remove per absolute rule #7"
fi

# A11. fetch() error handler check (WARN, defensive)
# Judged per call site, not per file: a file that has one .catch somewhere used to
# vouch for every other fetch in it. A call site counts as handled when its own
# promise chain ends in .catch, when it is awaited inside a try block that has a
# catch, when it is handed to waitUntil or respondWith, when it is stored in a
# variable that later gets .catch, or when its enclosing function passes the
# promise on and every caller handles it. The same analyzer serves A12.
print_section "[A11] fetch() without error handler (WARN: defensive)"
IFS= read -r -d '' JSGUARD_PY <<'PYEOF'
import os, re, sys

# Shared analyzer for the A11 (fetch error handling) and A12 (file size guard)
# checks. Both need to know where a call sits in the code, so the page scripts
# are first reduced to "code only" text (strings, comments, regex literals and
# template text blanked, same length, newlines kept) and brackets are matched.
# If the brackets do not balance the analyzer cannot trust its own picture of
# the page, so it stops with an error instead of guessing: a rule that reports
# "all fine" on a script it failed to read is a false green.

MODE = os.environ.get('LD_AUDIT_JSMODE', '')
if MODE not in ('A11', 'A12'):
    print('  internal error: LD_AUDIT_JSMODE must be A11 or A12', file=sys.stderr)
    sys.exit(2)

KW_BEFORE_REGEX = {'return', 'typeof', 'instanceof', 'in', 'of', 'new', 'delete',
                   'void', 'throw', 'case', 'do', 'else', 'yield', 'await'}
CTRL_WORDS = {'if', 'for', 'while', 'switch', 'catch', 'with'}
# After the closing parenthesis of these, a slash starts a regular expression
# (`if (ok) /x/.test(v)`), not a division.
CTRL_PAREN = {'if', 'while', 'for', 'with'}


def blank(out, a, b):
    for k in range(a, b):
        if out[k] != '\n':
            out[k] = ' '


def mask_js(src):
    n = len(src)
    out = list(src)
    i = 0
    prev = ''
    prev_word = ''
    tstack = []
    bdepth = 0
    pstack = []
    last_close_kw = ''

    def read_template(j):
        a = j
        while j < n:
            c = src[j]
            if c == '\\':
                j += 2
                continue
            if c == '`':
                blank(out, a, min(j, n))
                return j + 1, 'end'
            if c == '$' and j + 1 < n and src[j + 1] == '{':
                blank(out, a, j)
                return j + 2, 'sub'
            j += 1
        blank(out, a, n)
        return n, 'end'

    while i < n:
        c = src[i]
        if c.isspace():
            i += 1
            continue
        d = src[i + 1] if i + 1 < n else ''
        if c == '/' and d == '/':
            j = src.find('\n', i)
            j = n if j < 0 else j
            blank(out, i, j)
            i = j
            continue
        if c == '/' and d == '*':
            j = src.find('*/', i + 2)
            j = n if j < 0 else j + 2
            blank(out, i, j)
            i = j
            continue
        if c == '"' or c == "'":
            j = i + 1
            while j < n and src[j] != c and src[j] != '\n':
                j += 2 if src[j] == '\\' else 1
            blank(out, i + 1, min(j, n))
            i = j + 1
            prev, prev_word = 'v', ''
            continue
        if c == '`':
            i, kind = read_template(i + 1)
            if kind == 'sub':
                tstack.append(bdepth)
                bdepth = 0
                prev = '{'
            else:
                prev = 'v'
            prev_word = ''
            continue
        if c == '/':
            is_regex = (prev in ('', '(', ',', '=', ':', '[', '!', '&', '|', '?', '{', '}',
                                 ';', '+', '-', '*', '%', '<', '>', '~', '^')
                        or (prev == 'w' and prev_word in KW_BEFORE_REGEX)
                        or (prev == ')' and last_close_kw in CTRL_PAREN))
            if is_regex:
                j = i + 1
                incls = False
                while j < n and src[j] != '\n':
                    ch = src[j]
                    if ch == '\\':
                        j += 2
                        continue
                    if ch == '[':
                        incls = True
                    elif ch == ']':
                        incls = False
                    elif ch == '/' and not incls:
                        break
                    j += 1
                if j < n and src[j] == '/':
                    blank(out, i + 1, j)
                    j += 1
                    while j < n and src[j].isalpha():
                        j += 1
                    i = j
                    prev, prev_word = 'v', ''
                    continue
            prev, prev_word = '/', ''
            i += 1
            continue
        if c.isalpha() or c in '_$' or ord(c) > 127:
            j = i + 1
            while j < n and (src[j].isalnum() or src[j] in '_$' or ord(src[j]) > 127):
                j += 1
            prev, prev_word = 'w', src[i:j]
            i = j
            continue
        if c.isdigit():
            j = i + 1
            while j < n and (src[j].isalnum() or src[j] in '._'):
                j += 1
            prev, prev_word = 'v', ''
            i = j
            continue
        if c == '{':
            bdepth += 1
        elif c == '}':
            if tstack and bdepth == 0:
                bdepth = tstack.pop()
                i, kind = read_template(i + 1)
                if kind == 'sub':
                    tstack.append(bdepth)
                    bdepth = 0
                    prev = '{'
                else:
                    prev = 'v'
                prev_word = ''
                continue
            bdepth -= 1
        elif c == '(':
            pstack.append(prev_word if prev == 'w' else '')
        elif c == ')':
            last_close_kw = pstack.pop() if pstack else ''
        prev, prev_word = c, ''
        i += 1
    return ''.join(out)


SCRIPT_RE = re.compile(r'<script\b([^>]*)>(.*?)</script\s*>', re.I | re.S)
TYPE_RE = re.compile(r'\btype\s*=\s*["\']?([^"\'\s>]+)', re.I)
SRC_RE = re.compile(r'\bsrc\s*=', re.I)


class Page:
    def __init__(self, path, text):
        self.path = path
        self.text = text
        code = [' ' if ch != '\n' else '\n' for ch in text]
        self.blocks = []
        if path.endswith('.html'):
            for m in SCRIPT_RE.finditer(text):
                attrs = m.group(1)
                if SRC_RE.search(attrs):
                    continue
                t = TYPE_RE.search(attrs)
                if t and t.group(1).lower() not in ('text/javascript', 'module', 'application/javascript'):
                    continue
                self.blocks.append((m.start(2), m.end(2)))
        else:
            self.blocks.append((0, len(text)))
        for s, e in self.blocks:
            code[s:e] = list(mask_js(text[s:e]))
        self.code = ''.join(code)
        self.match = {}
        self.rmatch = {}
        for s, e in self.blocks:
            self._match(s, e)
        self.funcs = self._functions()

    def line(self, p):
        return self.text.count('\n', 0, p) + 1

    def block_start(self, p):
        for s, e in self.blocks:
            if s <= p < e:
                return s
        return 0

    def block_span(self, p):
        for s, e in self.blocks:
            if s <= p < e:
                return s, e
        return 0, len(self.code)

    def _match(self, a, b):
        st = []
        pairs = {')': '(', ']': '[', '}': '{'}
        code = self.code
        for k in range(a, b):
            c = code[k]
            if c in '([{':
                st.append(k)
            elif c in ')]}':
                if not st or code[st[-1]] != pairs[c]:
                    raise ValueError('%s:%d: brackets do not balance, the script cannot be analysed'
                                     % (self.path, self.line(k)))
                o = st.pop()
                self.match[o] = k
                self.rmatch[k] = o
        if st:
            raise ValueError('%s:%d: brackets do not balance, the script cannot be analysed'
                             % (self.path, self.line(st[-1])))

    def _name_before(self, a, idx):
        pre = self.code[max(a, idx - 160):idx]
        m = re.search(r'(?:(?:const|let|var)\s+)?([\w$]+)\s*[:=]\s*(?:async\s+)?$', pre)
        if m:
            return m.group(1)
        return None

    def _functions(self):
        code = self.code
        funcs = []
        for o, c in self.match.items():
            if code[o] != '{':
                continue
            a = self.block_start(o)
            k = o - 1
            while k >= a and code[k].isspace():
                k -= 1
            if k < a:
                continue
            name = None
            if k >= 1 and code[k - 1:k + 1] == '=>':
                j = k - 2
                while j >= a and code[j].isspace():
                    j -= 1
                if j >= a and code[j] == ')':
                    head = self.rmatch[j]
                else:
                    while j >= a and (code[j].isalnum() or code[j] in '_$'):
                        j -= 1
                    head = j + 1
                name = self._name_before(a, head)
            elif code[k] == ')':
                po = self.rmatch[k]
                e = po
                while e > a and code[e - 1].isspace():
                    e -= 1
                wstart = e
                while wstart > a and (code[wstart - 1].isalnum() or code[wstart - 1] in '_$'):
                    wstart -= 1
                word = code[wstart:e]
                if not word or word in CTRL_WORDS:
                    continue
                if word == 'function':
                    name = self._name_before(a, wstart)
                else:
                    name = word
            else:
                continue
            funcs.append((o, c, name))
        return funcs

    def innermost(self, p):
        best = None
        for f in self.funcs:
            if f[0] < p < f[1] and (best is None or f[0] > best[0]):
                best = f
        return best

    def stmt_prefix(self, p):
        code = self.code
        lo = self.block_start(p)
        k = p - 1
        depth = 0
        while k >= lo:
            c = code[k]
            if c in ')]':
                depth += 1
            elif c in '([':
                if depth > 0:
                    depth -= 1
            elif c in ';{}' and depth == 0:
                break
            k -= 1
        return code[k + 1:p]

    def chain_ok(self, q):
        # q is the index of the last character of an expression (a closing
        # bracket or the end of an identifier). Walk the rest of the same
        # expression looking for a .catch( at the chain level.
        code = self.code
        n = len(code)
        while True:
            k = q + 1
            depth = 0
            after_comma = False
            left = None
            while k < n:
                c = code[k]
                if c in '([{':
                    depth += 1
                elif c in ')]}':
                    if depth == 0:
                        left = c
                        break
                    depth -= 1
                elif depth == 0 and c == ';':
                    return False
                elif depth == 0 and c == '\n' and not after_comma:
                    # No semicolon: a line that starts with a word starts a new
                    # statement, so a .catch( further down is not ours.
                    m2 = re.compile(r'\s*(.)').match(code, k)
                    if m2 and (m2.group(1).isalnum() or m2.group(1) in '_$'):
                        return False
                elif depth == 0 and c == ',':
                    after_comma = True
                elif depth == 0 and c == '.' and not after_comma and \
                        re.match(r'\.\s*catch\s*\(', code[k:k + 40]):
                    return True
                elif depth == 0 and c == '.' and not after_comma:
                    mt = re.match(r'\.\s*then\s*\(', code[k:k + 40])
                    if mt and self.has_second_arg(k + mt.end() - 1):
                        return True
                k += 1
            if left is None or left == '}':
                return False
            q = k

    def has_second_arg(self, o):
        # True when the call opened at o has a second argument (a rejection
        # handler as in .then(ok, fail)); a trailing comma does not count.
        q = self.match.get(o)
        if q is None:
            return False
        code = self.code
        depth = 0
        for k in range(o + 1, q):
            c = code[k]
            if c in '([{':
                depth += 1
            elif c in ')]}':
                depth -= 1
            elif c == ',' and depth == 0:
                return bool(code[k + 1:q].strip())
        return False

    def in_platform(self, p):
        for m in re.finditer(r'\b(?:waitUntil|respondWith)\s*\(', self.code):
            o = m.end() - 1
            if o < p < self.match.get(o, -1):
                return True
        return False

    def in_try(self, p, inner):
        code = self.code
        for m in re.finditer(r'\btry\s*\{', code):
            o = m.end() - 1
            c = self.match.get(o)
            if c is None or not (o < p < c):
                continue
            if inner is not None and not (inner[0] < o):
                continue
            if re.match(r'\s*catch\b', code[c + 1:c + 24]):
                return True
        return False

    def call_sites(self, name):
        out = []
        code = self.code
        for m in re.finditer(r'(?<![\w$])' + re.escape(name) + r'\s*\(', code):
            o = m.end() - 1
            q = self.match.get(o)
            if q is None:
                continue
            if re.search(r'function\s*\*?\s+$', code[max(0, m.start() - 24):m.start()]):
                continue
            if re.match(r'\s*\{', code[q + 1:q + 12]):
                continue
            out.append((m.start(), q))
        return out

    @staticmethod
    def _flatten(pref):
        # Drop balanced (...) and [...] groups so that only the statement
        # skeleton is left: `const p = cond ? fetch(a) : ` becomes `const p = cond ?   : `.
        prev = None
        while prev != pref:
            prev = pref
            pref = re.sub(r'\([^()]*\)|\[[^\[\]]*\]', ' ', pref)
        return pref

    def _redeclares(self, f, x):
        # Does the function f give x its own meaning (a parameter or a local
        # declaration)? Then an x inside it is not the variable we are tracking.
        code = self.code
        hdr = re.split(r'[;{}]', code[max(0, f[0] - 160):f[0]])[-1]
        if re.search(r'(?<![\w$.])' + re.escape(x) + r'\s*=>', hdr):
            return True
        pm = re.search(r'\(([^()]*)\)\s*(?:=>)?\s*$', hdr)
        if pm and re.search(r'(?<![\w$.])' + re.escape(x) + r'(?![\w$])', pm.group(1)):
            return True
        return re.search(r'\b(?:const|let|var)\s+' + re.escape(x) + r'(?![\w$])',
                         code[f[0]:f[1]]) is not None

    def var_has_catch(self, p, q, x):
        # The promise was stored in x. Look for x.catch(...) later in the same
        # function (a closure inside it counts unless it declares its own x).
        inner = self.innermost(p)
        if inner is not None:
            lo, hi = inner[0], inner[1]
        else:
            lo, hi = self.block_span(p)
        for m in re.finditer(r'(?<![\w$.])' + re.escape(x) + r'(?![\w$])', self.code):
            if not (q < m.start() < hi) or m.start() < lo:
                continue
            fm = self.innermost(m.start())
            shadow = False
            while fm is not None and (inner is None or fm[0] != inner[0]):
                if self._redeclares(fm, x):
                    shadow = True
                    break
                fm = self.innermost(fm[0])
            if shadow:
                continue
            if self.chain_ok(m.end() - 1):
                return True
        return False

    def bare_refs(self, name):
        # Places where the function is handed over without being called
        # (addEventListener('click', load)): whoever receives it ignores the
        # promise it returns, so a rejection inside it is never handled.
        out = []
        code = self.code
        for m in re.finditer(r'(?<![\w$])' + re.escape(name) + r'(?![\w$])', code):
            if re.match(r'\s*\(', code[m.end():m.end() + 12]):
                continue
            if re.match(r'\s*(?:=(?!=)|:(?!:))', code[m.end():m.end() + 12]):
                continue
            if re.search(r'\b(?:function|const|let|var|class|get|set|async)\s*\*?\s+$',
                         code[max(0, m.start() - 24):m.start()]):
                continue
            out.append(m.start())
        return out

    def fetch_handled(self, p, q, depth=0, seen=()):
        if self.chain_ok(q):
            return True
        if self.in_platform(p):
            return True
        pref = self.stmt_prefix(p)
        awaited = re.search(r'\bawait\b', pref) is not None
        inner = self.innermost(p)
        if awaited and self.in_try(p, inner):
            return True
        if not awaited:
            mv = re.search(r'([\w$]+)\s*=\s*(?:[^;{}()]*?[?:]\s*)?$', self._flatten(pref))
            if mv and self.var_has_catch(p, q, mv.group(1)):
                return True
        if inner is not None and inner[2] and depth < 4 and inner[2] not in seen:
            propagates = awaited or re.match(r'\s*return\b', pref) or re.search(r'=>\s*$', pref)
            if propagates:
                sites = self.call_sites(inner[2])
                if sites and not self.bare_refs(inner[2]) and \
                        all(self.fetch_handled(sp, sq, depth + 1, seen + (inner[2],))
                            for sp, sq in sites):
                    return True
        return False

    def regions(self, p):
        # Code regions whose size checks protect position p: the enclosing
        # function, and for anonymous callbacks also the part of the parent
        # function before the callback (a callback inherits the guard that
        # ran before it was defined).
        out = []
        f = self.innermost(p)
        hi = p
        while True:
            if f is None:
                out.append((self.block_start(p), hi))
                return out, None
            out.append((f[0], hi))
            if f[2]:
                return out, f
            hi = f[0]
            f = self.innermost(f[0])

    # A size guard compares a size against a limit: `x.size > MAX`, `MAX < x.size`
    # or a call to ldSizeOk. An assignment, an equality test (`=== 0`, `!== old`)
    # or a Set.size read is not one, and neither is the definition of ldSizeOk.
    # Neither is a floor: `x.size > 0`, `x.size <= 0` and `x.size < MIN_SIZE` only
    # say the file is not empty, they put no ceiling on it. The other side of such
    # a comparison is judged by name and by value (0, 1, a name containing MIN,
    # EMPTY or ZERO); any other small number cannot be told from a real ceiling.
    CH = r'(?:[\w$]+\??\.)*[\w$]+'
    GUARD = re.compile(r'(?P<r1>' + CH + r'|\)|\])\s*\??\.size\s*(?:<=|>=|<(?!<)|>(?!>))'
                       r'|(?<![=\-])[<>]=?\s*(?P<r2>' + CH + r')\s*\??\.size\b'
                       r'|\bldSizeOk\s*\(')
    CHAIN = re.compile(r'[\w$]+(?:\??\.[\w$]+)*\Z')
    FLOOR = re.compile(r'(?:0+(?:\.0+)?|1)\Z|.*(?:min|empty|zero)', re.I)

    def split_args(self, o):
        # Top-level arguments of the call opened at o.
        q = self.match.get(o)
        if q is None:
            return []
        code = self.code
        out, depth, start = [], 0, o + 1
        for k in range(o + 1, q):
            c = code[k]
            if c in '([{':
                depth += 1
            elif c in ')]}':
                depth -= 1
            elif c == ',' and depth == 0:
                out.append(code[start:k])
                start = k + 1
        tail = code[start:q]
        if tail.strip() or out:
            out.append(tail)
        return [x.strip() for x in out]

    def read_target(self, m):
        # The span of the expression that gets read: the first argument of a
        # FileReader style call, the receiver of file.arrayBuffer() / file.text().
        code = self.code
        if 'readAs' in m.group(0):
            o = m.end() - 1
            q = self.match.get(o)
            if q is None:
                return None
            a, k, depth = o + 1, o + 1, 0
            while k < q:
                c = code[k]
                if c in '([{':
                    depth += 1
                elif c in ')]}':
                    depth -= 1
                elif c == ',' and depth == 0:
                    break
                k += 1
            while a < k and code[a].isspace():
                a += 1
            e = k
            while e > a and code[e - 1].isspace():
                e -= 1
            return (a, e) if e > a else None
        e = m.start()
        k = e
        while k > 0:
            c = code[k - 1]
            if c in ')]':
                o = self.rmatch.get(k - 1)
                if o is None:
                    break
                k = o
            elif c.isalnum() or c in '_$':
                while k > 0 and (code[k - 1].isalnum() or code[k - 1] in '_$'):
                    k -= 1
            elif c == '.':
                k -= 1
                if k > 0 and code[k - 1] == '?':
                    k -= 1
            else:
                break
        return (k, e) if e > k else None

    def is_response(self, p, name):
        # Is the plain name a fetch / cache.match Response? Either it was assigned
        # from one earlier in the same function, or it is the parameter of a
        # callback in a chain that starts with fetch(...).
        code = self.code
        inner = self.innermost(p)
        lo = inner[0] if inner is not None else self.block_start(p)
        n = re.escape(name)
        if re.search(r'(?<![\w$.])' + n + r'\s*=\s*(?!=)[^;\n]*?(?<![\w$.])(?:fetch|caches?\.match)\s*\(',
                     code[lo:p]):
            return True
        param = re.compile(r'(?<![\w$.])' + n + r'\s*=>'
                           r'|\(\s*(?:[\w$]+\s*,\s*)*' + n + r'\s*(?:,[^()]*)?\)\s*=>'
                           r'|function\s*[\w$]*\s*\(\s*(?:[\w$]+\s*,\s*)*' + n + r'\b')
        prefs = [self.stmt_prefix(p)]
        f = self.innermost(p)
        while f is not None:
            prefs.append(self.stmt_prefix(f[0]))
            f = self.innermost(f[0])
        return any(re.search(r'(?<![\w$.])fetch\s*\(', pr) and param.search(pr) for pr in prefs)

    def read_subject(self, m):
        # (plain name that is read or None, True when this read is not a whole
        # user-chosen file). Not whole files: a Response (clone(), the value of a
        # fetch), data the page made itself (new Blob(...)), and a bounded slice
        # (file.slice(0, 1024)). The name is None when the expression is anything
        # more complicated than a chain of names (`input.files[0]`).
        span = self.read_target(m)
        if span is None:
            return None, False
        a, e = span
        code = self.code
        expr = code[a:e]
        if code[e - 1] == ')':
            o = self.rmatch.get(e - 1)
            if o is not None and o >= a:
                nm = re.search(r'\.\s*([\w$]+)\s*$', code[a:o])
                if nm and nm.group(1) == 'clone':
                    return None, True
                if nm and nm.group(1) == 'slice':
                    args = self.split_args(o)
                    if len(args) >= 2 and 'size' not in args[1] and 'length' not in args[1]:
                        return None, True
                if code[a] == '(' and re.search(r'(?<![\w$.])(?:fetch|caches?\.match)\s*\(', code[a:e]):
                    return None, True
        if re.search(r'\bnew\s+$', code[max(0, a - 12):a]):
            return None, True
        if re.fullmatch(r'[\w$]+', expr) and self.is_response(m.start(), expr):
            return None, True
        if not self.CHAIN.match(expr):
            return None, False
        return expr.replace('?', ''), False

    def guard_receiver(self, g):
        # The plain name a guard looks at, or None when it cannot be told.
        code = self.code
        if g.group('r1') is not None or g.group('r2') is not None:
            name = g.group('r1') if g.group('r1') is not None else g.group('r2')
            start = g.start('r1') if g.group('r1') is not None else g.start('r2')
            before = code[start - 1] if start > 0 else ''
            if not self.CHAIN.match(name) or before in ('.', ')', ']'):
                return None
            return name.replace('?', '')
        q = self.match.get(g.end() - 1)
        arg = code[g.end():q].strip() if q is not None else ''
        return arg if self.CHAIN.match(arg) else None

    def limit_operand(self, g):
        # The other side of a size comparison: what the size is compared with.
        code = self.code
        if g.group('r1') is not None:
            m2 = re.match(r'\s*([\w$.]+)', code[g.end():g.end() + 60])
            return m2.group(1) if m2 else None
        if g.group('r2') is not None:
            m3 = re.search(r'([\w$.]+)\s*$', code[max(0, g.start() - 60):g.start()])
            return m3.group(1) if m3 else None
        return None

    def _is_guard(self, g, p, subject):
        pos = g.start()
        code = self.code
        if g.group(0).lstrip().startswith('ldSizeOk'):
            if re.search(r'function\s*\*?\s+$', code[max(0, pos - 24):pos]):
                return False
            q = self.match.get(g.end() - 1)
            if q is not None and re.match(r'\s*\{', code[q + 1:q + 12]):
                return False
        else:
            op = self.limit_operand(g)
            if op is not None and self.FLOOR.match(op):
                return False
        # Only code that runs on the way to p counts: a check inside some other
        # function body (one that does not contain p) protects nothing here.
        for o, c, _ in self.funcs:
            if o < pos < c and not (o < p < c):
                return False
        # When both sides are plain names they have to be the same name: the
        # size of some other object says nothing about the file being read.
        if subject is not None:
            r = self.guard_receiver(g)
            if r is not None and r != subject:
                return False
        return True

    def guarded(self, p, subject=None, depth=0, seen=()):
        regs, named = self.regions(p)
        for a, b in regs:
            for g in self.GUARD.finditer(self.code, a, b):
                if self._is_guard(g, p, subject):
                    return True
        if named is not None and named[2] and depth < 3 and named[2] not in seen:
            sites = self.call_sites(named[2])
            if sites and not self.bare_refs(named[2]) and \
                    all(self.guarded(sp, None, depth + 1, seen + (named[2],))
                        for sp, sq in sites):
                return True
        return False


def read_file(path):
    try:
        with open(path, encoding='utf-8', errors='replace') as fh:
            return fh.read()
    except OSError:
        print(path + '  [UNREADABLE]', file=sys.stderr)
        sys.exit(3)


paths = [l.strip() for l in sys.stdin.read().splitlines() if l.strip()]
if not paths:
    print('  cannot read the file list - refusing to report this check as passed', file=sys.stderr)
    sys.exit(1)

sites = 0
nfiles = 0
hits = []
for path in paths:
    if not (path.endswith('.html') or path.endswith('.js')):
        continue
    text = read_file(path)
    try:
        page = Page(path, text)
    except ValueError as e:
        print('  ' + str(e), file=sys.stderr)
        sys.exit(3)
    nfiles += 1
    code = page.code
    if MODE == 'A11':
        for m in re.finditer(r'(?:(?<![\w$.])|(?<=window\.)|(?<=self\.)|(?<=globalThis\.))fetch\s*\(', code):
            o = m.end() - 1
            q = page.match.get(o)
            if q is None:
                continue
            sites += 1
            if not page.fetch_handled(m.start(), q):
                hits.append('  %s:%d: fetch without error handler' % (path, page.line(m.start())))
    else:
        # Every way the page has of pulling a whole file into memory: the FileReader
        # calls and the Blob methods file.arrayBuffer() and file.text().
        for m in re.finditer(r'\??\.\s*(?:readAs(?:ArrayBuffer|Text|DataURL|BinaryString)\s*\(|(?:arrayBuffer|text)\s*\(\s*\))', code):
            sites += 1
            subject, not_a_file = page.read_subject(m)
            if not_a_file:
                continue
            if not page.guarded(m.start(), subject):
                hits.append('  %s:%d: read without size check' % (path, page.line(m.start())))

for h in hits:
    print(h)
print('SUMMARY sites=%d files=%d' % (sites, nfiles))
PYEOF
A11_OUT=$(printf '%s\n' "$PUB_FILES" | LD_AUDIT_JSMODE=A11 python3 -c "$JSGUARD_PY" 2>&1); A11_RC=$?
if [ "$A11_RC" -ne 0 ]; then
  printf '%s\n' "$A11_OUT" | tail -4 | sed 's/^/    /'
  print_fail "A11 check could not run (exit $A11_RC) - not reporting it as passed"
else
  A11_SUM=$(printf '%s\n' "$A11_OUT" | grep '^SUMMARY ' | tail -1)
  A11_LIST=$(printf '%s\n' "$A11_OUT" | grep -v '^SUMMARY ')
  if [ -z "$A11_SUM" ]; then
    print_fail "A11 check could not run (it printed no summary line) - not reporting it as passed"
  elif [ "$(summary_field "$A11_SUM" files)" != "$((HTML_N + JS_N))" ]; then
    print_fail "A11 check could not run (it looked at $(summary_field "$A11_SUM" files) of $((HTML_N + JS_N)) html/js file(s)) - not reporting it as passed"
  elif unseen_sites "$(summary_field "$A11_SUM" sites)" "$FETCH_RAW_RE"; then
    print_fail "A11 check could not run ($UNSEEN_MSG) - not reporting it as passed"
  elif [ -z "$A11_LIST" ]; then
    print_pass "Every fetch() call site has an error handler (${A11_SUM#SUMMARY })"
  else
    printf '%s\n' "$A11_LIST" | head -10
    print_warn "Files with fetch() but no .catch / try-catch handler: $(printf '%s\n' "$A11_LIST" | grep -c .) call site(s)"
  fi
fi

# A12. file.size pre-check guard (WARN, defensive)
# A viewer should check the size of a chosen file before reading it, so a huge
# file cannot exhaust memory. Judged per read site (the FileReader calls readAsArrayBuffer,
# readAsText, readAsDataURL and readAsBinaryString, and the Blob methods
# .arrayBuffer() and .text()) in every public html/js file: a size limit (a relational
# comparison on some .size, or a call to ldSizeOk) has to run on the way to the
# read: earlier in the same function, in the part of the parent function before an
# anonymous callback, or in every caller of the named function. A check inside
# another function body does not count, when both sides are plain names they must
# be the same name, an equality test is not a limit, and neither is a floor
# (size > 0, size < MIN_SIZE). Reads that are not a whole user file are left
# alone: a fetch Response (including clone()), a bounded slice(a, b), and a Blob
# the page built itself.
print_section "[A12] file.size pre-check before reading a file (WARN: defensive)"
A12_OUT=$(printf '%s\n' "$PUB_FILES" | LD_AUDIT_JSMODE=A12 python3 -c "$JSGUARD_PY" 2>&1); A12_RC=$?
if [ "$A12_RC" -ne 0 ]; then
  printf '%s\n' "$A12_OUT" | tail -4 | sed 's/^/    /'
  print_fail "A12 check could not run (exit $A12_RC) - not reporting it as passed"
else
  A12_SUM=$(printf '%s\n' "$A12_OUT" | grep '^SUMMARY ' | tail -1)
  A12_LIST=$(printf '%s\n' "$A12_OUT" | grep -v '^SUMMARY ')
  if [ -z "$A12_SUM" ]; then
    print_fail "A12 check could not run (it printed no summary line) - not reporting it as passed"
  elif [ "$(summary_field "$A12_SUM" files)" != "$((HTML_N + JS_N))" ]; then
    print_fail "A12 check could not run (it looked at $(summary_field "$A12_SUM" files) of $((HTML_N + JS_N)) html/js file(s)) - not reporting it as passed"
  elif unseen_sites "$(summary_field "$A12_SUM" sites)" "$READ_RAW_RE"; then
    print_fail "A12 check could not run ($UNSEEN_MSG) - not reporting it as passed"
  elif [ -z "$A12_LIST" ]; then
    print_pass "Every file read site has a file.size pre-check (${A12_SUM#SUMMARY })"
  else
    printf '%s\n' "$A12_LIST" | head -10
    print_warn "Missing file.size pre-check: $(printf '%s\n' "$A12_LIST" | grep -c .) read site(s)"
  fi
fi

# A13. Inline event handler check (WARN, W49 Security Audit Phase C)
# onclick= / onload= / onerror= 等 inline JS 違反 CSP best practice
# DOM-only rule 強制 addEventListener,inline handler 是 anti-pattern
print_section "[A13] Inline event handlers (WARN — DOM-only rule)"
HITS=$(grep_pub -HnE "\son(click|load|error|mouseover|mouseout|change|submit|focus|blur|keydown|keyup|keypress)\s*=\s*[\"']")
if pub_grep_failed; then
  print_fail "A13 check could not run - not reporting it as passed"
elif [ -z "$HITS" ]; then
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
hits = []
def hit(msg):
    hits.append(msg); print(msg)
n = 0
for f in sys.stdin.read().splitlines():
    f = f.strip()
    if not f: continue
    n += 1
    if not os.path.isfile(f):
        hit(f + '  [UNREADABLE: not found]'); continue
    try:
        with open(f, encoding='utf-8') as fh: data = fh.read()
    except UnicodeDecodeError:
        hit(f + '  [UNREADABLE: not valid UTF-8]'); continue
    except OSError as e:
        hit(f + '  [UNREADABLE: ' + e.__class__.__name__ + ']'); continue
    if '\ufffd' in data: hit(f + '  [U+FFFD replacement char]')
    if PUA.search(data): hit(f + '  [private use area char]')
    if CTRL.search(data): hit(f + '  [control char]')
    for ln, line in enumerate(data.split('\n'), 1):
        if CYRGRK.search(line) and not EXPLAIN.search(line):
            hit(f + ':' + str(ln) + '  [cyrillic/greek amid CJK]')
print('OK %d %d' % (len(hits), n))
" 2>&1)
A14_RC=$?
if [ "$A14_RC" -ne 0 ] || ! py_done "$A14_HITS"; then
  printf '%s\n' "$A14_HITS" | tail -4 | sed 's/^/    /'
  print_fail "A14 check could not run (exit $A14_RC) - not reporting it as passed"
elif [ "$(py_field "$A14_HITS" 1)" != "$NUM_FILES" ]; then
  print_fail "A14 check could not run (it looked at $(py_field "$A14_HITS" 1) of $NUM_FILES file(s)) - not reporting it as passed"
elif [ "$(py_field "$A14_HITS" 0)" = 0 ]; then
  print_pass "No mojibake in any public file"
else
  printf '%s\n' "$(py_body "$A14_HITS")" | head -10
  print_fail "Found mojibake in $(py_field "$A14_HITS" 0) place(s): a decode failure that has to be fixed"
fi

# A15. SEO/a11y anchors that page regeneration silently drops (BLOCKER)
# Rebuilding a guide page rewrites the whole file, and the canonical link,
# structured data and skip link are injected afterwards — so a rebuild without
# the post-processing chain leaves pages that look fine but lost all of it.
print_section "[A15] Canonical / structured data / skip link (BLOCKER)"
IFS= read -r -d '' A15_PY <<'PYEOF'
import os, sys

files = os.environ.get('LD_AUDIT_PUB', '')
if not files.strip():
    print('  cannot read the file list - refusing to report this check as passed')
    sys.exit(1)
# 自測的餌檔要排除，但豁免只在自測時生效：以檔名為條件的永久豁免，
# 對任何真的叫 canary_* 的發佈頁面同樣有效，那是一條以命名繞過 BLOCKER 的路。
selftest = bool(os.environ.get('LD_AUDIT_SELFTEST'))
ANCHORS = [('canonical', 'rel="canonical"'), ('json-ld', 'application/ld+json'),
           ('skip-link', 'class="skip-link"')]
n = unread = nhits = 0
for f in files.splitlines():
    f = f.strip()
    if not f.endswith('.html'):
        continue
    n += 1
    if not os.path.isfile(f):
        print('  %s: UNREADABLE' % f)
        unread += 1
        nhits += 1
        continue
    if selftest and os.path.basename(f).startswith('canary_'):
        continue
    try:
        t = open(f, encoding='utf-8', errors='replace').read()
    except OSError:
        print('  %s: UNREADABLE' % f)
        unread += 1
        nhits += 1
        continue
    miss = [name for name, needle in ANCHORS if needle not in t]
    if miss:
        print('  %s: missing %s' % (f, ' '.join(miss)))
        nhits += 1
print('OK %d %d %d' % (nhits, n, unread))
PYEOF
A15_OUT=$(LD_AUDIT_PUB="$PUB_FILES" python3 -c "$A15_PY" 2>&1); A15_RC=$?
if [ "$A15_RC" -ne 0 ] || ! py_done "$A15_OUT"; then
  printf '%s\n' "$A15_OUT" | tail -4 | sed 's/^/    /'
  print_fail "A15 check could not run (exit $A15_RC) - not reporting it as passed"
elif [ "$(py_field "$A15_OUT" 1)" != "$HTML_N" ]; then
  print_fail "A15 check could not run (it looked at $(py_field "$A15_OUT" 1) of $HTML_N page(s)) - not reporting it as passed"
elif [ "$(py_field "$A15_OUT" 0)" = 0 ]; then
  print_pass "Every page carries canonical, structured data and a skip link"
else
  printf '%s\n' "$(py_body "$A15_OUT")" | head -10
  A15_UNREAD=$(py_field "$A15_OUT" 2)
  A15_MISS=$(( $(py_field "$A15_OUT" 0) - A15_UNREAD ))
  [ "$A15_UNREAD" -gt 0 ] && print_fail "A15 could not read $A15_UNREAD file(s) - not reporting them as passed"
  [ "$A15_MISS" -gt 0 ] && print_fail "$A15_MISS page(s) missing SEO/a11y anchors - did a rebuild skip the post-processing chain?"
fi

# A16. sitemap lastmod must not predate the file's last commit (BLOCKER)
# Search engines only trust lastmod when it is consistently right; once a large
# share of it is wrong they ignore the whole signal. Dates drift because the
# sitemap is maintained by hand while the pages keep changing.
print_section "[A16] sitemap lastmod freshness (BLOCKER)"
# Which content counts as "changed since its last commit" depends on what is being
# audited. staged: the hook, so the index diff against HEAD. worktree: a manual run
# in the repository, so everything changed against HEAD. tree: a clean export of
# committed content (pre-push and the release script), where only history can speak.
if [ -n "${LD_AUDIT_STAGED:-}" ]; then
  A16_MODE=staged
elif [ -z "${LD_AUDIT_ROOT:-}" ]; then
  A16_MODE=worktree
else
  A16_MODE=tree
fi
A16_STALE=$(LD_AUDIT_MODE="$A16_MODE" LD_AUDIT_GIT_ROOT="$GIT_ROOT" python3 - 2>&1 <<'PYEOF'
import datetime, os, re, subprocess

BASE = 'https://toniliumvp.github.io/LunaticDawn/'


def fail(msg):
    print('  ' + msg + ' - refusing to report this check as passed')
    raise SystemExit(1)


try:
    sm = open('sitemap.xml', encoding='utf-8').read()
except OSError:
    fail('sitemap.xml unreadable')
# A sitemap that parses to nothing (emptied, cut short, written in another shape)
# is not a sitemap that is up to date.
urls = re.findall(r'<url>(.*?)</url>', sm, re.S)
n_loc = len(re.findall(r'<loc>', sm))
if not urls or len(urls) != n_loc:
    fail('sitemap.xml has %d <url> block(s) and %d <loc> element(s), so it is empty or damaged'
         % (len(urls), n_loc))

# 歷史一定要跟真實 repo 拿：掃索引副本時 cwd 沒有 .git，
# 查不到日期就沒有比對對象，整條規則會變成永遠通過。
git_root = os.environ.get('LD_AUDIT_GIT_ROOT') or '.'
# Fixed options for every git call below. The output is parsed by shape, and the
# reader's own configuration (colour, diff prefixes, an external diff driver,
# signature display) would otherwise change that shape without any error: the
# parser would find no file in the diff and the rule would pass on nothing.
GIT = ['git', '-C', git_root, '-c', 'core.quotePath=false', '-c', 'color.ui=false',
       '-c', 'diff.noprefix=false', '-c', 'diff.mnemonicPrefix=false',
       '-c', 'log.showSignature=false']
DIFF = ['--no-color', '--no-ext-diff', '--no-textconv', '--src-prefix=a/', '--dst-prefix=b/',
        '--no-renames', '--unified=0']


def git(*args):
    return subprocess.run(GIT + list(args), capture_output=True, encoding='utf-8', errors='replace')


# 跳過只改日期的變更。寫入 dateModified 這個動作本身會產生一個 commit,
# 若把它算成「最後修改」,sitemap 就永遠追不上,形成自我追逐。頁面的
# dateModified 與 sitemap 都以「最後一次實質內容變更」為準,這裡要用同一個
# 定義,否則三邊互相矛盾。只看最近 50 個 commit:純日期 commit 一定在近期。
#
# 判定單位是「這個 commit 裡的這一個檔案」,不是整個 commit:同一個 commit 可以
# 帶走一個頁面的內容修改和另一個頁面因後處理鏈而更新的日期行,後者仍然是只改日期。
# 判定方式是把每一段變更的 - 行與 + 行成對比較:兩行都帶日期標記,而且把日期換成
# 同一個字之後完全相同,才算只改日期。行數不等(新增或刪除一行)、或同一行裡
# 還有別的文字變了(例如和 dateModified 在同一行的 JSON-LD headline),都算內容變更。
# sitemap_refresh.py 與這裡是同一個定義,兩邊要一起改。
DATE_MARKERS = ('"dateModified"', 'footer-updated', '<time datetime=', '<lastmod>')
DATE_RE = re.compile(r'\d{4}-\d{2}-\d{2}')


def parse_diff(text):
    """[(path, hunks, binary, gone)]; a hunk is (removed lines, added lines)."""
    out = []
    for blk in re.split(r'(?m)^diff --git ', text)[1:]:
        head, _, rest = blk.partition('\n')
        path, hunks, binary, gone, cur = None, [], False, False, None
        for l in rest.split('\n'):
            if cur is not None:
                if l.startswith('@@'):
                    cur = ([], [])
                    hunks.append(cur)
                elif l.startswith('-'):
                    cur[0].append(l[1:])
                elif l.startswith('+'):
                    cur[1].append(l[1:])
            elif l.startswith('@@'):
                cur = ([], [])
                hunks.append(cur)
            elif l.startswith('+++ '):
                p2 = l[4:].split('\t')[0]
                if p2.startswith('b/'):
                    path = p2[2:]
            elif l.startswith('Binary files'):
                binary = True
            elif l.startswith('deleted file mode'):
                gone = True
        if path is None and not gone:
            half = (len(head) - 5) // 2
            cand = head[2:2 + half]
            if head == 'a/%s b/%s' % (cand, cand):
                path = cand
        out.append((path, hunks, binary, gone))
    return out


def content_changed(hunks, binary):
    if binary:
        return True
    for removed, added in hunks:
        if not removed or len(removed) != len(added):
            return True
        for a, b in zip(removed, added):
            if not any(m in b for m in DATE_MARKERS) or DATE_RE.sub('D', a) != DATE_RE.sub('D', b):
                return True
    return False


DATE_ONLY = set()     # (commit, path) pairs whose only change is the date lines
recent = git('log', '--format=%H', '-n', '50')
if recent.returncode != 0:
    fail('cannot read git history')
for sha in recent.stdout.split():
    d = git('show', '--format=', *DIFF, sha)
    if d.returncode != 0:
        fail('cannot read commit ' + sha[:10])
    for path, hunks, binary, gone in parse_diff(d.stdout):
        if path and hunks and not binary and not content_changed(hunks, binary):
            DATE_ONLY.add((sha, path))

log = git('log', '--no-color', '--date=short', '--format=%H %ad', '--name-only')
if log.returncode != 0 or not log.stdout.strip():
    fail('cannot read git history')

last = {}
cur_sha = cur = None
for line in log.stdout.split('\n'):
    line = line.strip()
    m = re.fullmatch(r'([0-9a-f]{40}) (\d{4}-\d{2}-\d{2})', line)
    if m:
        cur_sha, cur = m.group(1), m.group(2)
    elif line and cur and (cur_sha, line) not in DATE_ONLY:
        last.setdefault(line, cur)

# Content that is not committed yet. The log above only knows about commits, so a
# page edited right now still carries the date of its previous commit, and a
# sitemap that was not touched looks fresh against it. For anything changed since
# HEAD (or about to be committed), the date to hold the sitemap to is today,
# unless every changed line is one of the date lines the post-processing chain
# writes, which would otherwise make the check chase its own tail.
mode = os.environ.get('LD_AUDIT_MODE', 'tree')
pending = set()
if mode in ('staged', 'worktree'):
    pd = git('diff', *(['--cached'] if mode == 'staged' else ['HEAD']), *DIFF)
    if pd.returncode != 0:
        print('  ' + pd.stderr.strip()[:200])
        fail('cannot read the %s diff' % mode)
    parsed = parse_diff(pd.stdout)
    if pd.stdout.strip() and not parsed:
        fail('the %s diff is not in the expected format' % mode)
    today = datetime.date.today().isoformat()
    for path, hunks, binary, gone in parsed:
        if gone or (not hunks and not binary):
            continue    # removed, or only a mode change: no content moved
        if path is None:
            fail('cannot tell which file a diff block in the %s diff is about' % mode)
        if content_changed(hunks, binary):
            last[path] = today
            pending.add(path)

def valid_date(text):
    # The shape first: fromisoformat alone would also take other spellings
    # (20260903, or a year-week-day form) that a sitemap does not allow.
    if not re.fullmatch(r'\d{4}-\d{2}-\d{2}', text):
        return False
    try:
        datetime.date.fromisoformat(text)
    except ValueError:
        return False
    return True


stale, invalid, checked, compared = [], [], 0, 0
for u in urls:
    mloc = re.search(r'<loc>([^<]+)</loc>', u)
    if not mloc:
        fail('a <url> block in sitemap.xml has no <loc>')
    mlm = re.search(r'<lastmod>([^<]+)</lastmod>', u)
    if not mlm:
        continue
    checked += 1
    loc, lm = mloc.group(1).strip(), mlm.group(1).strip()
    rel = loc[len(BASE):] if loc.startswith(BASE) else ''
    if not rel or rel.endswith('/'):
        rel = (rel or '') + 'index.html'
    if not valid_date(lm):
        # A value that is not a date can never be older than anything, so it would
        # pass the comparison below for good. Search engines drop such a lastmod.
        invalid.append('  %s: lastmod %r is not a valid YYYY-MM-DD date' % (rel, lm))
        continue
    d = last.get(rel)
    if d:
        compared += 1
        if lm < d:
            stale.append('  %s: sitemap=%s, page last changed %s%s'
                         % (rel, lm, d, ' (not committed yet)' if rel in pending else ''))
if checked == 0:
    fail('no <url> block in sitemap.xml carries a <lastmod>')
# Entries that were never put next to a date from git history are entries that were
# not checked. None at all means the history table or the URL mapping is broken.
if compared == 0 and not invalid:
    fail('no sitemap entry could be compared with a date from git history')
for line in invalid + stale:
    print(line)
print('OK %d %d %d %d' % (len(invalid) + len(stale), checked, len(invalid), compared))
PYEOF
)
A16_RC=$?
if [ "$A16_RC" -ne 0 ] || ! py_done "$A16_STALE"; then
  printf '%s\n' "$A16_STALE" | tail -4 | sed 's/^/    /'
  print_fail "A16 check could not run (exit $A16_RC) - not reporting it as passed"
elif [ "$(py_field "$A16_STALE" 0)" = 0 ]; then
  print_pass "Every sitemap entry is at least as new as its file ($(py_field "$A16_STALE" 3) compared)"
else
  printf '%s\n' "$(py_body "$A16_STALE")" | head -10
  A16_BAD=$(py_field "$A16_STALE" 2)
  A16_OLD=$(( $(py_field "$A16_STALE" 0) - A16_BAD ))
  [ "$A16_BAD" -gt 0 ] && print_fail "$A16_BAD sitemap lastmod value(s) that are not valid dates"
  [ "$A16_OLD" -gt 0 ] && print_fail "$A16_OLD sitemap entry(ies) older than the file they point at"
fi

# A17. History layer: every other check reads `git ls-files`, which is the
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
    # 與 commit-msg hook 同一份定義。不含 milestone / carry-over:
    # 那是正常英文詞,擋了會誤殺技術說明,而誤報會訓練人忽略輸出。
    ('planning', re.compile(r'\bPENDING\b|\bP[0-3]\b', re.I)),
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
print('OK %d %d' % (len(path_hits) + len(new), len(objs.splitlines())))
PYEOF
)
A17_RC=$?
if [ "$A17_RC" -ne 0 ] || ! py_done "$A17_OUT"; then
  printf '%s\n' "$A17_OUT" | tail -4 | sed 's/^/    /'
  print_fail "A17 check could not run (exit $A17_RC) - not reporting it as passed"
else
  A17_HITS=$(py_field "$A17_OUT" 0)
  A17_NOTE=$(printf '%s\n' "$A17_OUT" | grep '^  NOTE' || true)
  if [ "$A17_HITS" = 0 ]; then
    print_pass "No new history-layer leakage"
    [ -n "$A17_NOTE" ] && echo "$A17_NOTE"
  else
    py_body "$A17_OUT" | grep '^  A17\.' | head -12
    print_fail "$A17_HITS history-layer leak(s) not on the accepted baseline"
    [ -n "$A17_NOTE" ] && echo "$A17_NOTE"
  fi
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

nhits = unread = n = 0
for f in files.splitlines():
    f = f.strip()
    if not f or not f.endswith('.html'):
        continue
    n += 1
    if not os.path.isfile(f):
        print(f'  {f}: UNREADABLE')
        nhits += 1
        unread += 1
        continue
    try:
        t = open(f, encoding='utf-8', errors='replace').read()
    except OSError:
        print(f'  {f}: UNREADABLE')
        nhits += 1
        unread += 1
        continue
    for name, pat in RULES:
        for m in pat.finditer(t):
            line = t[:m.start()].count('\n') + 1
            print(f'  {f}:{line}: {name}: {m.group(0)[:70]}')
            nhits += 1
print('OK %d %d %d' % (nhits, n, unread))
PYEOF
)
A18_RC=$?
if [ "$A18_RC" -ne 0 ] || ! py_done "$A18_OUT"; then
  printf '%s\n' "$A18_OUT" | tail -4 | sed 's/^/    /'
  print_fail "A18 check could not run (exit $A18_RC) - not reporting it as passed"
elif [ "$(py_field "$A18_OUT" 1)" != "$HTML_N" ]; then
  print_fail "A18 check could not run (it looked at $(py_field "$A18_OUT" 1) of $HTML_N page(s)) - not reporting it as passed"
elif [ "$(py_field "$A18_OUT" 0)" = 0 ]; then
  print_pass "No unredacted poster addresses in archived BBS text"
else
  printf '%s\n' "$(py_body "$A18_OUT")" | head -10
  A18_UNREAD=$(py_field "$A18_OUT" 2)
  A18_MISS=$(( $(py_field "$A18_OUT" 0) - A18_UNREAD ))
  [ "$A18_UNREAD" -gt 0 ] && print_fail "A18 could not read $A18_UNREAD file(s) - not reporting them as passed"
  [ "$A18_MISS" -gt 0 ] && print_fail "$A18_MISS unredacted poster address(es) - the redaction step did not run"
fi

# A19. Characters the wuxia pages need but the shipped font no longer has (BLOCKER)
# fonts-wuxia.css ships Noto Serif TC cut down to the characters the pages use. A page
# that gains a character the cut-down font dropped does not break: that one character
# is drawn in a system font instead, which looks different and measures differently,
# and nothing else would notice. The font is rebuilt from the full original by the
# post-processing chain, so a hand-written page is the case this rule exists for.
#
# What counts as "needed" is defined once, in tools/audit/wuxia_chars.py, and the build
# step imports the same file. A character the full font never had is not reported: it
# fell back to a system font before the cut as well. The listing of what the full font
# can draw is tools/audit/wuxia_font_coverage.txt, written by the build step.
# The module and the listing are read from the audit's own directory and the pages and
# the stylesheet from the audited tree: the pre-commit hook audits an export of the
# index in which this directory exists as well.
print_section "[A19] Characters missing from the shipped wuxia font (BLOCKER)"
A19_OUT=$(LD_AUDIT_PUB="$PUB_FILES" LD_AUDIT_TOOLS="$GIT_ROOT/tools/audit" python3 - 2>&1 <<'PYEOF'
import os, sys

tools = os.environ.get('LD_AUDIT_TOOLS', '')
sys.path.insert(0, tools)
import wuxia_chars as wc

files = [f.strip() for f in os.environ.get('LD_AUDIT_PUB', '').splitlines() if f.strip()]
if not files:
    print('  cannot read the file list - refusing to report this check as passed')
    sys.exit(1)
try:
    problems, pages = wc.audit(files, '.', os.path.join(tools, 'wuxia_font_coverage.txt'))
except (OSError, ValueError, RuntimeError) as e:
    print('  %s: %s' % (type(e).__name__, e))
    sys.exit(1)
nhits = 0
for cp, ch, srcs in problems:
    nhits += 1
    if cp is None:
        print('  %s: referenced by %s but not in the tree' % (ch, srcs[0]))
    else:
        more = ' (+%d more)' % (len(srcs) - 3) if len(srcs) > 3 else ''
        print('  U+%04X %s: %s%s' % (cp, ch, ', '.join(srcs[:3]), more))
print('OK %d %d 0' % (nhits, pages))
PYEOF
)
A19_RC=$?
# The page count is held against a plain grep, which shares no code with the rule:
# a rule that looked at fewer pages than the files that name the stylesheet, or at none,
# did not do its job.
A19_SEEN=$(grep_pub -lF 'fonts-wuxia.css')
if pub_grep_failed; then
  print_fail "A19 check could not run (the cross-check grep failed) - not reporting it as passed"
else
A19_N=$(printf '%s\n' "$A19_SEEN" | grep -cE '\.html$')
if [ "$A19_RC" -ne 0 ] || ! py_done "$A19_OUT"; then
  printf '%s\n' "$A19_OUT" | tail -4 | sed 's/^/    /'
  print_fail "A19 check could not run (exit $A19_RC) - not reporting it as passed"
elif [ "$A19_N" -eq 0 ]; then
  print_fail "A19 check could not run (no page links fonts-wuxia.css, so there is nothing to check) - not reporting it as passed"
elif [ "$(py_field "$A19_OUT" 1)" != "$A19_N" ]; then
  print_fail "A19 check could not run (it looked at $(py_field "$A19_OUT" 1) of $A19_N wuxia page(s)) - not reporting it as passed"
elif [ "$(py_field "$A19_OUT" 0)" = 0 ]; then
  print_pass "Every character the $A19_N wuxia pages need is in the shipped font"
else
  printf '%s\n' "$(py_body "$A19_OUT")" | head -10
  print_fail "$(py_field "$A19_OUT" 0) problem(s): characters missing from the shipped wuxia font, or font files missing - rebuild the subset (subset_wuxia_fonts.py)"
fi
fi

# A20. Content-Security-Policy of every page (BLOCKER)
# GitHub Pages cannot send headers, so each page carries its policy in a <meta> element,
# and the policy lists the sha256 of every inline script of that page. A page whose script
# was edited without refreshing that list does not break loudly: the browser skips the
# script, and whatever it did stops working. The same goes for a page that lost its policy
# element, one whose policy was widened by hand, and one that uses an inline event handler
# or a javascript: URL, which the policy no longer runs.
#
# What the policy says, how a script is hashed and how a page is read are defined once, in
# tools/audit/csp_scripts.py; the build step (csp_hash.py) imports the same file, so the page,
# the writer and this rule cannot drift apart. The module is read from the audit's own
# directory and the pages from the audited tree, as for A19.
#
# Pages named canary_* are the self-test's bait pages and are skipped only while the
# self-test runs, as in A15. The page count is held against the shell's own, and the number
# of pages without a policy against a plain grep that shares no code with the rule.
print_section "[A20] Content-Security-Policy of every page (BLOCKER)"
A20_OUT=$(LD_AUDIT_PUB="$PUB_FILES" LD_AUDIT_TOOLS="$GIT_ROOT/tools/audit" python3 - 2>&1 <<'PYEOF'
import os, sys

sys.path.insert(0, os.environ.get('LD_AUDIT_TOOLS', ''))
import csp_scripts as csp

files = [f.strip() for f in os.environ.get('LD_AUDIT_PUB', '').splitlines() if f.strip()]
if not files:
    print('  cannot read the file list - refusing to report this check as passed')
    sys.exit(1)
selftest = bool(os.environ.get('LD_AUDIT_SELFTEST'))
problems, pages, unread, without = csp.audit(
    files, lambda f: selftest and os.path.basename(f).startswith('canary_'))
for f, msg in problems:
    print('  %s: %s' % (f, msg))
print('OK %d %d %d %d' % (len(problems), pages, unread, without))
PYEOF
)
A20_RC=$?
A20_NOPOLICY=$(grep_pub -LF 'Content-Security-Policy')
if pub_grep_failed; then
  print_fail "A20 check could not run (the cross-check grep failed) - not reporting it as passed"
else
A20_GREP_N=0
while IFS= read -r _f; do
  case "$_f" in
    *.html)
      if [ -n "${LD_AUDIT_SELFTEST:-}" ]; then case "${_f##*/}" in canary_*) continue ;; esac; fi
      A20_GREP_N=$((A20_GREP_N+1)) ;;
  esac
done <<< "$A20_NOPOLICY"
if [ "$A20_RC" -ne 0 ] || ! py_done "$A20_OUT"; then
  printf '%s\n' "$A20_OUT" | tail -4 | sed 's/^/    /'
  print_fail "A20 check could not run (exit $A20_RC) - not reporting it as passed"
elif [ "$(py_field "$A20_OUT" 1)" != "$HTML_N" ]; then
  print_fail "A20 check could not run (it looked at $(py_field "$A20_OUT" 1) of $HTML_N page(s)) - not reporting it as passed"
elif [ "$A20_GREP_N" -gt "$(py_field "$A20_OUT" 3)" ]; then
  print_fail "A20 check could not run (a plain grep finds $A20_GREP_N page(s) that never mention a Content-Security-Policy, the rule counted $(py_field "$A20_OUT" 3)) - not reporting it as passed"
elif [ "$(py_field "$A20_OUT" 0)" = 0 ]; then
  print_pass "All $HTML_N pages carry the policy, and it matches the inline scripts of each page"
else
  printf '%s\n' "$(py_body "$A20_OUT")" | head -10
  A20_UNREAD=$(py_field "$A20_OUT" 2)
  A20_BAD=$(( $(py_field "$A20_OUT" 0) - A20_UNREAD ))
  [ "$A20_UNREAD" -gt 0 ] && print_fail "A20 could not read $A20_UNREAD file(s) - not reporting them as passed"
  [ "$A20_BAD" -gt 0 ] && print_fail "$A20_BAD problem(s) with the Content-Security-Policy of the pages above - run csp_hash.py --apply (it is part of the post-processing chain) or fix what the line says"
fi
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
