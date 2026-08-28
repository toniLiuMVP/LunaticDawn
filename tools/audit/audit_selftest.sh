#!/usr/bin/env bash
# Audit self-test — proves every site_audit.sh rule can actually go RED.
#
# Why this exists: a rule that can never fire is indistinguishable, in output,
# from a rule that passes. Both print a green tick. Two rules (8.2, 8.3) sat
# permanently green because of environment quirks, not because the site was clean:
#   - 8.2 used grep -E '{300,}'; BSD grep caps repetition at 255 and errored out,
#     with stderr sent to /dev/null, so "no hits" meant "the check crashed".
#   - 8.3 matched CJK filenames against `git ls-files`, which octal-escapes
#     non-ASCII paths by default (core.quotePath), so the pattern never matched.
#
# This script plants a deliberate violation for each rule, confirms the audit
# catches it, and removes it again. Run it after editing site_audit.sh.
#
# Usage: ./tools/audit/audit_selftest.sh
# Exit 0 = every rule proved live. Exit 1 = at least one rule is a dead check.

set -uo pipefail
cd "$(dirname "$0")/../.."

AUDIT=./tools/audit/site_audit.sh
CANARIES=()
PASS=0
FAIL=0

cleanup() {
  for f in "${CANARIES[@]:-}"; do
    [ -n "$f" ] || continue
    git rm -f --cached "$f" -q 2>/dev/null
    rm -f "$f"
  done
}
trap cleanup EXIT INT TERM

# Refuse to run against a dirty tree: the canary dance stages and unstages files,
# and we must not disturb work in progress.
if [ -n "$(git status --porcelain -- . ':!tools/audit' 2>/dev/null)" ]; then
  echo "✗ working tree has uncommitted changes outside tools/audit — aborting."
  echo "  (self-test stages temp files; run it from a clean tree)"
  exit 1
fi

# plant <file> <expected-substring-in-audit-output> <label> [heredoc content on stdin]
plant() {
  local file="$1" expect="$2" label="$3"
  cat > "$file"
  git add -f "$file" 2>/dev/null
  CANARIES+=("$file")
  local out
  out=$(bash $AUDIT 2>&1)
  if echo "$out" | grep -q "$expect"; then
    echo "  ✓ $label — fires"
    PASS=$((PASS+1))
  else
    echo "  ✗ $label — DEAD CHECK (planted a violation, audit stayed green)"
    FAIL=$((FAIL+1))
  fi
  git rm -f --cached "$file" -q 2>/dev/null
  rm -f "$file"
  CANARIES=()
}

echo "════════════════════════════════════════════"
echo "  Audit self-test — can every rule go red?"
echo "════════════════════════════════════════════"

# NEGATIVE CONTROL FIRST. Before trusting any "rule stayed green = dead check"
# verdict, prove the audit runs at all. Without this, a script that cannot execute
# (lost exec bit, bad shebang, syntax error) makes EVERY rule look dead — which is
# exactly what happened the first time this self-test was run.
BASELINE=$(bash $AUDIT 2>&1)
if ! echo "$BASELINE" | grep -q "AUDIT SUMMARY"; then
  echo "  ✗ negative control FAILED — the audit did not produce a summary."
  echo "    Every rule would look 'dead'. Fix the audit script before reading results."
  echo "    ---- audit output was: ----"
  echo "$BASELINE" | head -5
  exit 1
fi
echo "  ✓ negative control — audit runs and reports"
echo ""

plant canary_a1.html "Internal dev jargon" "A1 internal jargon" <<'EOF'
<p>第三十波 PENDING scope 校正 milestone</p>
EOF

plant canary_a2.html "Personal dev paths" "A2 personal paths" <<'EOF'
<p>/Volumes/Work/LD/ 與 smb://toniLiuMVP</p>
EOF

plant canary_a3.html "credentials" "A3 credentials" <<'EOF'
<p>api_key = "abcdefghij0123456789abcdef"</p>
EOF

plant canary_a4.html "innerHTML found" "A4 innerHTML" <<'EOF'
<script>document.body.innerHTML = "x";</script>
EOF

plant canary_a5.html "toni capitalization" "A5 toni casing" <<'EOF'
<p>Toni 大神</p>
EOF

plant canary_a6.html "Low-level RE" "A6 RE jargon" <<'EOF'
<p>fcn.00535ed0 filter-branch</p>
EOF

plant canary_a7.html "email addresses found" "A7 email PII" <<'EOF'
<p>realperson@hinet.net</p>
EOF

plant canary_a81.html "8.1 Forbidden phrasing" "A8.1 forbidden phrasing" <<'EOF'
<p>攻略文件版權屬於原作者，本站僅</p>
EOF

python3 -c "
import sys
open('canary_a82.html','w').write('<html><p>'+chr(0x300c)+('文'*400)+chr(0x300d)+'</p></html>')"
git add -f canary_a82.html 2>/dev/null
CANARIES+=("canary_a82.html")
OUT=$(bash $AUDIT 2>&1)
if echo "$OUT" | grep -q "8.2 Long literal quotes"; then
  echo "  ✓ A8.2 long verbatim quote — fires"; PASS=$((PASS+1))
else
  echo "  ✗ A8.2 long verbatim quote — DEAD CHECK"; FAIL=$((FAIL+1))
fi
git rm -f --cached canary_a82.html -q 2>/dev/null; rm -f canary_a82.html; CANARIES=()

# 8.3 keys off the FILENAME (CJK), not file contents — must be an image name.
touch "canary_攻略集_page1.png"
git add -f "canary_攻略集_page1.png" 2>/dev/null
CANARIES+=("canary_攻略集_page1.png")
OUT=$(bash $AUDIT 2>&1)
if echo "$OUT" | grep -q "8.3 Copyrighted scan"; then
  echo "  ✓ A8.3 copyrighted scan filename — fires"; PASS=$((PASS+1))
else
  echo "  ✗ A8.3 copyrighted scan filename — DEAD CHECK"; FAIL=$((FAIL+1))
fi
git rm -f --cached "canary_攻略集_page1.png" -q 2>/dev/null
rm -f "canary_攻略集_page1.png"; CANARIES=()

plant canary_a85.html "8.5 Wrong TW citation" "A8.5 nonexistent TW article" <<'EOF'
<p>台灣著作權法 §10-2 規定</p>
EOF

plant canary_a9.html "Draft markers" "A9 draft markers" <<'EOF'
<p>TBD FIXME 施工中</p>
EOF

plant canary_a10.html "Pirate / infringement" "A10 pirate sites" <<'EOF'
<p>wanyx dosgameol</p>
EOF

plant canary_a11.html "no .catch" "A11 fetch without catch" <<'EOF'
<script>fetch('./x.json').then(r=>r.json())</script>
EOF

plant canary_a12_viewer.html "Missing file.size" "A12 file.size guard" <<'EOF'
<script>const r=new FileReader();r.readAsArrayBuffer(f);</script>
EOF

plant canary_a13.html "inline event handler" "A13 inline handlers" <<'EOF'
<button onclick="alert(1)">x</button>
EOF

printf '<p>\xef\xbf\xbd</p>\n' > canary_a14.html
git add -f canary_a14.html 2>/dev/null
CANARIES+=("canary_a14.html")
OUT=$(bash $AUDIT 2>&1)
if echo "$OUT" | grep -q "U+FFFD mojibake"; then
  echo "  ✓ A14 mojibake — fires"; PASS=$((PASS+1))
else
  echo "  ✗ A14 mojibake — DEAD CHECK"; FAIL=$((FAIL+1))
fi
git rm -f --cached canary_a14.html -q 2>/dev/null; rm -f canary_a14.html; CANARIES=()

echo ""
echo "  live rules: $PASS   dead checks: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "  Status: ✗ at least one rule cannot fire — fix before trusting a green audit"
  exit 1
fi
echo "  Status: ✓ every rule proved live"
echo ""
echo "  Note: 8.4 (disclaimer present) is an inverted check — it warns on ABSENCE,"
echo "  so it is not canary-testable by planting a violation. It currently passes"
echo "  because disclaimers exist; verify by inspection if it ever goes green-on-empty."
exit 0
