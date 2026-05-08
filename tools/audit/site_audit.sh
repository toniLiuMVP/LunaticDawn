#!/usr/bin/env bash
# Public site comprehensive audit — runs all 9 audits before commit.
#
# Triple-jurisdiction copyright check:
#   - 台灣著作權法 §10-2 (事實/數據不受保護)
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

cd "$(dirname "$0")/../.."  # walk to LunaticDawn root
ROOT=$(pwd)

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
# Filter to text-content files only (skip binaries like PNG/woff2/SAV)
PUB_FILES=$(git ls-files \
  | grep -E "\.(html|js|json|xml|css|md|txt|svg)$" \
  | grep -v "^_local/" 2>/dev/null \
  || true)

NUM_FILES=$(echo "$PUB_FILES" | wc -l | tr -d ' ')

# A1. Internal wave/round/PENDING jargon (BLOCKER)
# 也包含 W## (W08 / W14 / W56 等) - 內部 wave 編號縮寫
print_section "[A1] Internal development jargon (BLOCKER)"
HITS=$(echo "$PUB_FILES" | xargs -I{} grep -nE "第[一二三四五六七八九十百零壹貳參肆伍陸柒捌玖拾佰0-9]+波|第\s*[0-9]+\s*波|wave\s*[0-9]+|Wave\s*[0-9]+|round-[0-9]+|Round[ _]?[0-9]+|\bW[0-9][0-9]\b|波次|PENDING|⏳[^：）)]*規劃|scope[- ]?校正|carry[- ]?over|toni\s+(戳穿|挑戰|個人|指示)|逆向工程依賴|反組譯依賴|未完成事項" {} 2>/dev/null \
  | grep -vE "(台灣第三波|第三波文化|第三波代理|第三波伺服器|第三波修改|第三波網頁|第三波發行|第三波官方|第三波的俠客遊|第三波繁中|第三波中文|0\.[0-9]+s|height=\"[0-9]+|width=\"[0-9]+)")
if [ -z "$HITS" ]; then
  print_pass "No internal dev jargon"
else
  echo "$HITS" | head -10
  print_fail "Internal dev jargon ($(echo "$HITS" | wc -l | tr -d ' ') hits)"
fi

# A2. Personal dev paths (BLOCKER) — /Volumes/Work/, NAS paths
# /Users/toni/ is OK as a Mac path EXAMPLE in docs (every Mac user has /Users/USERNAME).
# Real leaks: /Volumes/Work/LD/ (toni's actual dev location), NAS smb paths, "Mac Mini M4"
print_section "[A2] Personal dev paths / NAS leakage (BLOCKER)"
HITS=$(echo "$PUB_FILES" | xargs -I{} grep -nE "/Volumes/(Work|918|Mac Mini M4|Scratch|PLEXTOR|Toni-NAS)/|smb://(toni|toniLiu|Mac)|toniLiuMVP\._smb|918%20%E8%B3%87" {} 2>/dev/null)
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
HITS=$(echo "$PUB_FILES" | xargs -I{} grep -nE "\.innerHTML\s*=" {} 2>/dev/null)
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
HITS=$(echo "$PUB_FILES" | xargs -I{} grep -nE "fcn\.[0-9a-f]+|filter-branch|self[- ]?correct|內化教訓|cross[- ]?project|RedTime\b|\bJYQXZ\b|\bSWDA\b|MVP_Baseball|\bALLRM\b|跨專案[^著]|廣場留言|專案廣場" {} 2>/dev/null)
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
print_section "[A8] Copyright (TW §10-2 + JP §2/§12-2 + US §102b/Feist/Sega)"

# 8.1: Forbidden v2.0 phrasing (BLOCKER)
HITS=$(echo "$PUB_FILES" | xargs -I{} grep -nE "攻略文件版權屬於原作者，本站僅|事實在二進制裡|逆向解析的完整資料庫" {} 2>/dev/null)
if [ -z "$HITS" ]; then
  print_pass "8.1 No forbidden v2.0 phrasing"
else
  echo "$HITS" | head -3
  print_fail "8.1 Forbidden phrasing detected"
fi

# 8.2: Long literal quotes (>300 char single-string in HTML body)
HITS=$(echo "$PUB_FILES" | grep -E "\.html$" | xargs -I{} grep -nE '("[^"]{300,}")' {} 2>/dev/null | head -3)
if [ -z "$HITS" ]; then
  print_pass "8.2 No 300+ char literal quotes (fair use safe)"
else
  print_warn "8.2 Long literal quotes (review for fair use)"
fi

# 8.3: Copyrighted scan / book page in public area
HITS=$(git ls-files | grep -iE "(攻略集|說明書|攻略書).*\.(pdf|png|jpg)|scan.*\.(pdf|png|jpg)|.+book.+page.*\.(pdf|png|jpg)" | grep -v "_local/")
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
