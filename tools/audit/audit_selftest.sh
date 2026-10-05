#!/usr/bin/env bash
# Audit self-test: proves every site_audit.sh rule can actually go RED.
#
# Why this exists: a rule that can never fire is indistinguishable, in output,
# from a rule that passes. Both print a green tick. Two rules (8.2, 8.3) once sat
# permanently green because of environment quirks, not because the site was clean:
#   - 8.2 used grep -E '{300,}'; BSD grep caps repetition at 255 and errored out,
#     with stderr sent to /dev/null, so "no hits" meant "the check crashed".
#   - 8.3 matched CJK filenames against `git ls-files`, which octal-escapes
#     non-ASCII paths by default (core.quotePath), so the pattern never matched.
#
# This script plants a deliberate violation for each rule, confirms the audit
# reports it, and removes it again. Run it after editing site_audit.sh.
#
# What counts as proof, for every planted check:
#   1. The rule is green on the clean tree first. A rule that is already red
#      proves nothing about the bait.
#   2. The rule's own section reports the violation, and that section names the
#      planted file (or the planted value). A hit on some other file, or a message
#      that also appears when the rule passes, is not proof.
#   3. The report has the weight its level promises. The audit's own section title
#      says whether a rule is a BLOCKER or a WARN. A BLOCKER bait has to raise the
#      summary's Blockers above the clean run, turn the Status line to BLOCKED and
#      make the audit exit non-zero. A WARN bait has to raise Warnings only and
#      leave the exit status where the clean run had it. Without this a BLOCKER that
#      was quietly demoted to a WARN, or one that prints its failure without
#      counting it, still shows the section text and still passes the checks above,
#      while the audit tells the bad page "CLEAN (safe to commit)". Where the title
#      carries no level (the A8 sub-rules), the level is the marker the audit itself
#      printed on the report line (✗ or ⚠), and the counts and the exit status are
#      held against that marker. A demotion of such a sub-rule cannot be told from a
#      deliberate choice here, because the audit declares no level to compare with.
#   4. Every python-backed rule is also broken on purpose (a crash canary) and has
#      to go red with "could not run", because a crashed rule prints nothing and
#      nothing reads as clean.
#   5. A2 is planted once per file type the audit scans (not only .html), and its
#      section has to name every bait. Every other bait is a page, so an audit whose
#      file filter had shrunk to pages would stay green on all of them.
# The list of rules is read from the audit's own output, so a rule that is added
# to site_audit.sh without a bait here fails this run instead of passing unnoticed.
# The list of file types is read from the audit's own filter in the same way.
#
# Anything not proven (dead check, missing bait, anchor that no longer matches,
# clone that could not be built) fails the run. Nothing is skipped quietly.
#
# Usage: ./tools/audit/audit_selftest.sh
# Exit 0 = every rule proved live. Exit 1 = at least one rule was not proven.

set -uo pipefail
cd "$(dirname "$0")/../.."

AUDIT=./tools/audit/site_audit.sh
AUDIT_BAK=./tools/audit/.site_audit.sh.selftest-bak
SM=sitemap.xml
SM_BAK=""
SCRATCH=""
CANARIES=()
PASS=0
FAIL=0
SKIP=0
COVERED=" "

# The crash canaries below edit site_audit.sh in place and the A16 bait edits
# sitemap.xml in place, so the trap puts both back. A trap does not survive
# SIGKILL: a hard kill would leave a broken audit behind, and a broken audit prints
# green. So an interrupted run is also repaired on the way in, not only trusted to
# the way out.
cleanup() {
  if [ -f "$AUDIT_BAK" ]; then cp "$AUDIT_BAK" "$AUDIT"; rm -f "$AUDIT_BAK"; fi
  if [ -n "$SM_BAK" ] && [ -f "$SM_BAK" ]; then cp "$SM_BAK" "$SM"; rm -f "$SM_BAK"; fi
  for f in "${CANARIES[@]:-}"; do
    [ -n "$f" ] || continue
    git rm -f --cached "$f" -q 2>/dev/null
    rm -f "$f"
  done
  if [ -n "$SCRATCH" ] && [ -d "$SCRATCH" ]; then rm -rf "$SCRATCH"; fi
}
# INT and TERM have to end the run, not just clean up and carry on; exiting from
# them is what fires the EXIT trap that does the cleanup.
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [ -f "$AUDIT_BAK" ]; then
  echo "  ⚠ found a leftover audit backup from an interrupted run, restoring it"
  cp "$AUDIT_BAK" "$AUDIT"
  rm -f "$AUDIT_BAK"
fi

# A15 exempts files named canary_* only while this is set, so the bait below does
# not trip it while real pages stay covered.
export LD_AUDIT_SELFTEST=1

# Refuse to run against a dirty tree: the canary dance stages and unstages files,
# and we must not disturb work in progress. A git that fails is not a clean tree:
# the failure has to stop the run, not read as "nothing to report".
ST=$(git status --porcelain -- . ':!tools/audit' 2>&1) || {
  echo "✗ git status failed, cannot confirm a clean tree"
  printf '%s\n' "$ST" | head -3 | sed 's/^/    /'
  exit 1
}
if [ -n "$ST" ]; then
  echo "✗ working tree has uncommitted changes outside tools/audit, aborting."
  echo "  (self-test stages temp files; run it from a clean tree)"
  exit 1
fi

# macOS mktemp -d without a template ignores $TMPDIR and writes to the internal
# disk, so a template is always given.
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/ld-selftest.XXXXXX") || { echo "✗ cannot create a scratch directory"; exit 1; }

run_audit() { bash "$AUDIT" </dev/null 2>&1; }
contains() { [[ "$1" == *"$2"* ]]; }

# section_of <audit output> <tag such as "[A1]">: the lines of one rule section.
# The separator lines are found with index() so that the match is byte based and
# does not depend on the locale or on how awk treats multibyte characters.
section_of() {
  printf '%s\n' "$1" | awk -v tag="$2" '
    index($0, tag) && !on { on = 1; n = 0; next }
    on && index($0, "══") == 1 { n++; if (n == 2) exit; next }
    on { print }'
}

# heading_of <audit output> <tag>: the section title line. It carries the level the
# audit declares for the rule, such as "(BLOCKER)" or "(WARN: defensive)".
heading_of() { printf '%s\n' "$1" | awk -v tag="$2" 'index($0, tag) { print; exit }'; }

# declared_level <title>: BLOCKER or WARN as the title says it, nothing when it says
# neither.
declared_level() {
  case "$1" in
    *"(BLOCKER"*) echo BLOCKER ;;
    *"(WARN"*) echo WARN ;;
  esac
}

# marked_line <section> <text>: the first line of the section that starts with a
# failure marker (✗ from print_fail, ⚠ from print_warn) and carries the text. Hit
# lines quoted from pages have no marker, so none of them can stand in for it.
marked_line() {
  printf '%s\n' "$1" | awk -v t="$2" '($1 == "✗" || $1 == "⚠") && index($0, t) { print; exit }'
}

# summary_count <audit output> <Blockers|Warnings>: the number on the audit's summary
# line (the last such line). Nothing when the line is missing or is not a number.
summary_count() {
  printf '%s\n' "$1" | awk -v k="$2:" '$1 == k && $2 ~ /^[0-9]+$/ { v = $2 } END { if (v != "") print v }'
}

# severity_verdict <tag> <report text> <audit output> <exit status> <clean output>
# <clean exit status>: prints "ok <LEVEL>" when the report has the weight its level
# promises, otherwise "bad <reason>". The clean output and status belong to a run of
# the same audit without the bait, and every count is held against them. The report
# text is what the marked line says, which is not always the text that proves the
# bait was seen (A17 names its hits on lines without a marker).
severity_verdict() {
  local tag="$1" report="$2" out="$3" rc="$4" ref="$5" refrc="$6"
  local declared line marker level b0 w0 b1 w1
  declared=$(declared_level "$(heading_of "$out" "$tag")")
  line=$(marked_line "$(section_of "$out" "$tag")" "$report")
  case "$line" in
    "  ✗ "*) marker=BLOCKER ;;
    "  ⚠ "*) marker=WARN ;;
    *) echo "bad no ✗ or ⚠ line in the section carries the report text"; return ;;
  esac
  if [ -n "$declared" ] && [ "$declared" != "$marker" ]; then
    echo "bad the section title says $declared but the report line is marked $marker"; return
  fi
  level="${declared:-$marker}"
  b0=$(summary_count "$ref" Blockers); w0=$(summary_count "$ref" Warnings)
  b1=$(summary_count "$out" Blockers); w1=$(summary_count "$out" Warnings)
  if [ -z "$b0" ] || [ -z "$w0" ] || [ -z "$b1" ] || [ -z "$w1" ]; then
    echo "bad the summary has no Blockers or Warnings count to compare"; return
  fi
  if [ "$level" = BLOCKER ]; then
    [ "$b1" -gt "$b0" ] || { echo "bad a BLOCKER report did not raise the Blockers count ($b0 -> $b1)"; return; }
    contains "$out" "Status: ✗ BLOCKED" || { echo "bad a BLOCKER report did not turn the Status line to BLOCKED"; return; }
    [ "$rc" -ne 0 ] || { echo "bad a BLOCKER report did not make the audit exit non-zero"; return; }
  else
    [ "$w1" -gt "$w0" ] || { echo "bad a WARN report did not raise the Warnings count ($w0 -> $w1)"; return; }
    [ "$b1" -eq "$b0" ] || { echo "bad the WARN bait also raised the Blockers count ($b0 -> $b1), so its exit status proves nothing"; return; }
    [ "$rc" -eq "$refrc" ] || { echo "bad a WARN-only report changed the exit status ($refrc -> $rc)"; return; }
  fi
  echo "ok $level"
}

# clean_baseline <label> <tag> <expect>: returns 0 when the rule is green on the
# clean tree. Otherwise records the failure and returns 1.
clean_baseline() {
  local label="$1" tag="$2" expect="$3" s
  s=$(section_of "$BASELINE" "$tag")
  if [ -z "$s" ]; then
    echo "  ✗ $label: cannot prove it, the clean run has no section $tag"
    FAIL=$((FAIL+1)); return 1
  fi
  if contains "$s" "$expect"; then
    echo "  ✗ $label: cannot prove it, the rule is already red on a clean tree"
    FAIL=$((FAIL+1)); return 1
  fi
  return 0
}

# prove <label> <tag> <expect> <needle> <audit output> <exit status> [<clean output>
# <clean exit status> [<report text>]]: the rule's own section has to carry the
# failure text and has to name the bait, and the report has to have the weight the
# rule's level promises (see severity_verdict). The clean run defaults to the
# baseline and the report text to the failure text. The first word of the label is
# the rule id and is recorded as covered when the check fires.
prove() {
  local label="$1" tag="$2" expect="$3" needle="$4" out="$5" rc="$6"
  local ref="${7-$BASELINE}" refrc="${8-$BASE_RC}" report="${9-$3}" s id v
  id="${label%% *}"
  s=$(section_of "$out" "$tag")
  if ! { contains "$s" "$expect" && contains "$s" "$needle"; }; then
    echo "  ✗ $label: DEAD CHECK (violation planted, the rule did not report it)"
    FAIL=$((FAIL+1)); return
  fi
  v=$(severity_verdict "$tag" "$report" "$out" "$rc" "$ref" "$refrc")
  if [ "${v%% *}" != ok ]; then
    echo "  ✗ $label: WRONG WEIGHT (${v#bad })"
    FAIL=$((FAIL+1)); return
  fi
  echo "  ✓ $label: fires on the planted bait (${v#ok }, exit $rc)"
  PASS=$((PASS+1))
  COVERED="$COVERED$id "
}

# plant_existing <file> <expect> <label> <tag> [needle]: the file already exists.
# The needle defaults to the file name.
plant_existing() {
  local file="$1" expect="$2" label="$3" tag="$4" needle="${5:-$1}" out rc
  if ! clean_baseline "$label" "$tag" "$expect"; then rm -f "$file"; return; fi
  git add -f "$file" 2>/dev/null
  CANARIES+=("$file")
  out=$(run_audit); rc=$?
  prove "$label" "$tag" "$expect" "$needle" "$out" "$rc"
  git rm -f --cached "$file" -q 2>/dev/null
  rm -f "$file"
  CANARIES=()
}

# plant <file> <expect> <label> <tag> [needle], bait text on stdin.
plant() { cat > "$1"; plant_existing "$@"; }

echo "════════════════════════════════════════════"
echo "  Audit self-test: can every rule go red?"
echo "════════════════════════════════════════════"

# NEGATIVE CONTROL FIRST. Before trusting any "rule stayed green = dead check"
# verdict, prove the audit runs at all. Without this, a script that cannot execute
# (lost exec bit, bad shebang, syntax error) makes EVERY rule look dead, which is
# exactly what happened the first time this self-test was run.
BASELINE=$(run_audit)
BASE_RC=$?
if ! contains "$BASELINE" "AUDIT SUMMARY"; then
  echo "  ✗ negative control FAILED: the audit did not produce a summary."
  echo "    Every rule would look 'dead'. Fix the audit script before reading results."
  echo "    ---- audit output was: ----"
  printf '%s\n' "$BASELINE" | head -5
  exit 1
fi
echo "  ✓ negative control: audit runs and reports (clean run: Blockers $(summary_count "$BASELINE" Blockers), Warnings $(summary_count "$BASELINE" Warnings), exit $BASE_RC)"
echo ""

plant canary_a1.html "Internal dev jargon" "A1 internal jargon" "[A1]" <<'EOF'
<p>第三十波 PENDING scope 校正 milestone</p>
EOF

plant canary_a2.html "Personal dev paths leaked" "A2 personal paths" "[A2]" <<'EOF'
<p>/Volumes/Work/LD/ 與 smb://toniLiuMVP</p>
EOF

# Only the tool-config alternatives of the A2 pattern match these two, so each one
# proves its own branch: a home-relative path and an absolute one.
plant canary_a2b.html "Personal dev paths leaked" "A2b tool-config path (home relative)" "[A2]" <<'EOF'
<p>~/.claude/NOTES.md</p>
EOF

plant canary_a2c.html "Personal dev paths leaked" "A2c tool-config path (absolute)" "[A2]" <<'EOF'
<p>/opt/tool/.claude/settings</p>
EOF

# A2 reads every file type the audit scans, not only pages. Every other bait here is
# an .html file, so an audit whose file filter had shrunk to pages would stay green on
# all of them. Each file type gets a bait of its own, all carrying the same A2 path,
# and the A2 section has to name every one. The needle is "<name>:", the form grep -Hn
# prints, because canary_ext.js alone is also the beginning of canary_ext.json. A2
# shows at most ten hit lines, so the baits go in two audits and not in one.
EXT_BAITS="js json md txt py sh css xml svg yml conf command bat"

plant_ext_batch() {  # plant_ext_batch <extension>...
  local ext f out rc s v missing="" nmiss=0 nok
  for ext in "$@"; do
    f="canary_ext.$ext"
    printf '%s\n' '/Volumes/Work/LD/ canary' > "$f"
    CANARIES+=("$f")
    git add -f "$f" 2>/dev/null
  done
  out=$(run_audit); rc=$?
  for f in "${CANARIES[@]}"; do
    git rm -f --cached "$f" -q 2>/dev/null
    rm -f "$f"
  done
  CANARIES=()
  s=$(section_of "$out" "[A2]")
  for ext in "$@"; do
    if ! contains "$s" "canary_ext.$ext:"; then missing="$missing .$ext"; nmiss=$((nmiss+1)); fi
  done
  if [ -n "$missing" ]; then
    echo "  ✗ A2 file types:$missing DEAD (the rule never looked at that kind of file)"
    FAIL=$((FAIL+nmiss))
  fi
  nok=$(($# - nmiss))
  [ "$nok" -gt 0 ] || return
  v=$(severity_verdict "[A2]" "Personal dev paths leaked" "$out" "$rc" "$BASELINE" "$BASE_RC")
  if [ "${v%% *}" != ok ]; then
    echo "  ✗ A2 file types: WRONG WEIGHT (${v#bad })"
    FAIL=$((FAIL+nok))
  else
    echo "  ✓ A2 file types ($*): each one named in the A2 section (${v#ok }, exit $rc)"
    PASS=$((PASS+nok))
  fi
}

if clean_baseline "A2 file types" "[A2]" "Personal dev paths leaked"; then
  plant_ext_batch js json md txt py sh css
  plant_ext_batch xml svg yml conf command bat
fi

# The file types to bait come from the audit's own filter, so a type added there
# without a bait above is reported instead of passing unnoticed. (LICENSE is the only
# scanned name without an extension and is a real tracked file, so it has no bait.)
FILTER_EXTS=$(python3 - <<'PYEXT' 2>&1
import re, sys
s = open('tools/audit/site_audit.sh', encoding='utf-8').read()
m = re.findall(r'grep -E "\\\.\(([a-z]+(?:\|[a-z]+)*)\)\$', s)
if len(m) != 1:
    print('the file type filter occurs %d times, expected once' % len(m))
    sys.exit(2)
print(' '.join(m[0].split('|')))
PYEXT
)
FILTER_RC=$?
if [ "$FILTER_RC" -ne 0 ] || [ -z "$FILTER_EXTS" ]; then
  echo "  ✗ A2 file types: could not read the file type filter from the audit ($FILTER_EXTS)"
  FAIL=$((FAIL+1))
else
  UNBAITED=""
  for e in $FILTER_EXTS; do
    [ "$e" = html ] && continue
    contains " $EXT_BAITS " " $e " || UNBAITED="$UNBAITED .$e"
  done
  if [ -n "$UNBAITED" ]; then
    echo "  ✗ A2 file types: the audit scans$UNBAITED but no bait here covers it"
    FAIL=$((FAIL+1))
  fi
fi

plant canary_a3.html "Possible credentials detected" "A3 credentials" "[A3]" <<'EOF'
<p>api_key = "abcdefghij0123456789abcdef"</p>
EOF

plant canary_a4.html "innerHTML found" "A4 innerHTML" "[A4]" <<'EOF'
<script>document.body.innerHTML = "x";</script>
EOF

plant canary_a5.html "Wrong toni capitalization" "A5 toni casing" "[A5]" <<'EOF'
<p>Toni 大神</p>
EOF

plant canary_a6.html "Low-level RE references" "A6 RE jargon" "[A6]" <<'EOF'
<p>fcn.00535ed0 filter-branch</p>
EOF

plant canary_a7.html "Other email addresses found" "A7 email PII" "[A7]" <<'EOF'
<p>realperson@hinet.net</p>
EOF

plant canary_a81.html "8.1 Forbidden phrasing detected" "A8.1 forbidden phrasing" "[A8]" <<'EOF'
<p>攻略文件版權屬於原作者，本站僅</p>
EOF

python3 -c "
open('canary_a82.html','w').write('<html><p>'+chr(0x300c)+('文'*400)+chr(0x300d)+'</p></html>')"
plant_existing canary_a82.html "8.2 Long literal quotes" "A8.2 long verbatim quote" "[A8]"

# 8.3 keys off the FILENAME (CJK), not file contents, so it must be an image name.
: > "canary_攻略集_page1.png"
plant_existing "canary_攻略集_page1.png" "8.3 Copyrighted scan in public area" "A8.3 copyrighted scan filename" "[A8]"

# 8.4 warns on ABSENCE of a disclaimer, so its bait is a page without one, audited
# on its own through LD_AUDIT_FILES. The control run uses a page that has the
# wording and has to stay quiet, which shows the rule tells the two apart.
if clean_baseline "A8.4 disclaimer presence" "[A8]" "8.4 No copyright disclaimer detected"; then
  CANARIES+=("canary_a84.html")
  printf '<html><body><p>plain page</p></body></html>\n' > canary_a84.html
  OUT=$(LD_AUDIT_FILES="canary_a84.html" bash "$AUDIT" </dev/null 2>&1); OUT_RC=$?
  printf '<html><body><p>copyright notice</p></body></html>\n' > canary_a84.html
  CTL=$(LD_AUDIT_FILES="canary_a84.html" bash "$AUDIT" </dev/null 2>&1); CTL_RC=$?
  rm -f canary_a84.html; CANARIES=()
  S_BAIT=$(section_of "$OUT" "[A8]")
  S_CTL=$(section_of "$CTL" "[A8]")
  if contains "$S_BAIT" "8.4 No copyright disclaimer detected" \
     && ! contains "$S_CTL" "8.4 No copyright disclaimer detected" \
     && contains "$S_CTL" "8.4 Copyright disclaimer present in 1 file"; then
    # The control run is the clean reference for the counts: both runs audit a single
    # page, so whatever else that page trips is the same on both sides.
    V84=$(severity_verdict "[A8]" "8.4 No copyright disclaimer detected" "$OUT" "$OUT_RC" "$CTL" "$CTL_RC")
    if [ "${V84%% *}" = ok ]; then
      echo "  ✓ A8.4 disclaimer presence: fires on a page without one (${V84#ok }, exit $OUT_RC), quiet on a page with one"
      PASS=$((PASS+1)); COVERED="${COVERED}A8.4 "
    else
      echo "  ✗ A8.4 disclaimer presence: WRONG WEIGHT (${V84#bad })"
      FAIL=$((FAIL+1))
    fi
  else
    echo "  ✗ A8.4 disclaimer presence: DEAD CHECK (a page without a disclaimer was not reported, or the control page was)"
    FAIL=$((FAIL+1))
  fi
fi

plant canary_a85.html "8.5 Wrong TW citation" "A8.5 nonexistent TW article" "[A8]" <<'EOF'
<p>台灣著作權法 §10-2 規定</p>
EOF

plant canary_a9.html "Draft markers found" "A9 draft markers" "[A9]" <<'EOF'
<p>TBD FIXME 施工中</p>
EOF

plant canary_a10.html "Pirate / infringement site URLs or names found" "A10 pirate sites" "[A10]" <<'EOF'
<p>wanyx dosgameol</p>
EOF

# Two baits for the two newest A10 alternatives, written the way a public page
# would carry them (a link), one alternative each so that neither can hide behind
# the other. Reserved example domains keep the bait from naming a real site.
plant canary_a10b.html "Pirate / infringement site URLs or names found" "A10b old game download host (daiseki)" "[A10]" <<'EOF'
<p><a href="http://faq.daiseki.example/qa.htm">old FAQ</a></p>
EOF

plant canary_a10c.html "Pirate / infringement site URLs or names found" "A10c old game download path (chiuinan)" "[A10]" <<'EOF'
<p><a href="http://host.example/chiuinan/qa.htm">old FAQ</a></p>
EOF

plant canary_a11.html "no .catch" "A11 fetch without catch" "[A11]" <<'EOF'
<script>fetch('./x.json').then(r=>r.json())</script>
EOF

plant canary_a12_viewer.html "Missing file.size pre-check" "A12 file.size guard" "[A12]" <<'EOF'
<script>const r=new FileReader();r.readAsArrayBuffer(f);</script>
EOF

plant canary_a13.html "prefer addEventListener" "A13 inline handlers" "[A13]" <<'EOF'
<button onclick="alert(1)">x</button>
EOF

printf '<p>\xef\xbf\xbd</p>\n' > canary_a14.html
plant_existing canary_a14.html "Found mojibake in" "A14 mojibake" "[A14]"

# A15 bait cannot be named canary_* (that is exactly what A15 skips in self-test
# mode), so it gets its own prefix.
printf '<html><body><p>page with no canonical, no structured data, no skip link</p></body></html>\n' > probe_a15.html
plant_existing probe_a15.html "page(s) missing SEO/a11y anchors" "A15 canonical/structured-data/skip-link" "[A15]" "probe_a15.html: missing"

# A16 bait: claim in the sitemap that a page is older than its last change. The
# first lastmod becomes 2000-01-01, and the section has to show that very value.
if clean_baseline "A16 sitemap freshness" "[A16]" "older than the file they point at"; then
  if [ ! -f "$SM" ]; then
    echo "  ✗ A16 sitemap freshness: sitemap.xml is missing, cannot plant the bait"; FAIL=$((FAIL+1))
  else
    SM_BAK=$(mktemp "${TMPDIR:-/tmp}/ld-selftest-sm.XXXXXX") || { echo "  ✗ A16 sitemap freshness: no scratch file"; FAIL=$((FAIL+1)); SM_BAK=""; }
    if [ -n "$SM_BAK" ]; then
      cp "$SM" "$SM_BAK"
      python3 - <<'PYBAIT'
import re
s = open('sitemap.xml', encoding='utf-8').read()
t = re.sub(r'<lastmod>[^<]+</lastmod>', '<lastmod>2000-01-01</lastmod>', s, count=1)
if t == s:
    raise SystemExit('the sitemap bait changed nothing')
open('sitemap.xml', 'w', encoding='utf-8').write(t)
PYBAIT
      PLANTED=$?
      OUT=$(run_audit); OUT_RC=$?
      cp "$SM_BAK" "$SM"; rm -f "$SM_BAK"; SM_BAK=""
      if [ "$PLANTED" -ne 0 ]; then
        echo "  ✗ A16 sitemap freshness: the bait could not be planted"; FAIL=$((FAIL+1))
      else
        prove "A16 sitemap freshness" "[A16]" "older than the file they point at" "sitemap=2000-01-01" "$OUT" "$OUT_RC"
      fi
    fi
  fi
fi

# A18 bait: an unredacted poster address, the shape the redaction step removes. It
# uses a documentation address block and a reserved domain, so the bait does not
# republish a real host; the shape is unchanged and A18 still fires on it.
printf '%s\n' '<html><body><pre>posted from 198-51-100-7.adsl.dynamic.example</pre></body></html>' > probe_a18.html
plant_existing probe_a18.html "unredacted poster address(es)" "A18 unredacted poster addresses" "[A18]"

# A17 reads git history, so its bait is history: a throwaway clone gets one commit
# with a non-generic message and one path under pdf-pages/ that is added and then
# removed. The clone runs its own copy of the working audit script, so its git root
# is the clone and this repository is never touched. It is proven twice: green on
# the clone before the bait goes in, red after.
A17_DIR="$SCRATCH/a17"
mkdir -p "$A17_DIR"
A17_OK=0
if git clone -q --no-hardlinks . "$A17_DIR/c" 2>/dev/null && cp "$AUDIT" "$A17_DIR/c/tools/audit/site_audit.sh"; then
  A17_CLEAN=$(bash "$A17_DIR/c/tools/audit/site_audit.sh" </dev/null 2>&1); A17_CLEAN_RC=$?
  A17_S=$(section_of "$A17_CLEAN" "[A17]")
  if [ -z "$A17_S" ]; then
    echo "  ✗ A17 history layer: cannot prove it, the clean clone has no A17 section"; FAIL=$((FAIL+1))
  elif contains "$A17_S" "A17.1" || contains "$A17_S" "A17.2" || ! contains "$A17_S" "No new history-layer leakage"; then
    echo "  ✗ A17 history layer: cannot prove it, the rule is not green on a clean clone"; FAIL=$((FAIL+1))
  else
    A17_OK=1
  fi
else
  echo "  ✗ A17 history layer: could not build the throwaway clone, not proven"; FAIL=$((FAIL+1))
fi
if [ "$A17_OK" = 1 ]; then
  if ( cd "$A17_DIR/c" \
       && G='git -c core.hooksPath=/dev/null -c commit.gpgsign=false -c user.name=canary -c user.email=canary@example.com' \
       && $G commit -q --allow-empty -m 'canary: 第九十九波 PENDING' \
       && mkdir -p pdf-pages && : > pdf-pages/canary.png \
       && git add -f pdf-pages/canary.png && $G commit -q -m 'chore: c1' \
       && git rm -q pdf-pages/canary.png && $G commit -q -m 'chore: c2' ); then
    A17_OUT=$(bash "$A17_DIR/c/tools/audit/site_audit.sh" </dev/null 2>&1); A17_RC=$?
    # The hits are named on lines without a marker; the marked line is the count.
    A17_REPORT="history-layer leak(s) not on the accepted baseline"
    prove "A17.2 commit message layer" "[A17]" "A17.2 non-generic message" "canary: 第九十九波" "$A17_OUT" "$A17_RC" "$A17_CLEAN" "$A17_CLEAN_RC" "$A17_REPORT"
    prove "A17.1 path layer (added then removed)" "[A17]" "A17.1 copyrighted scan" "pdf-pages/canary.png" "$A17_OUT" "$A17_RC" "$A17_CLEAN" "$A17_CLEAN_RC" "$A17_REPORT"
  else
    echo "  ✗ A17 history layer: could not plant the history bait in the clone, not proven"; FAIL=$((FAIL+1))
  fi
fi

# Crash canaries. Every python-backed rule assigns `VAR=$(python3 ...)`, which
# collects stdout only: a traceback goes to stderr, so VAR comes back empty and
# empty reads exactly like "found nothing". That mistake has been made more than
# once in this repo, so each of those rules is tested for it directly: break the
# interpreter and require that rule's own section to say "could not run" and the
# audit to exit non-zero.
cp "$AUDIT" "$AUDIT_BAK"

# crash_canary <label> <anchor> <tag=text> [<tag=text> ...]
# Puts a line that cannot be parsed in front of the anchor (which must occur exactly
# once in the audit) and runs the audit.
crash_canary() {
  local label="$1" anchor="$2" pair tag text out rc ok=1 prc
  shift 2
  for pair in "$@"; do
    tag="${pair%%=*}"; text="${pair#*=}"
    if contains "$(section_of "$BASELINE" "$tag")" "could not run"; then
      echo "  ✗ $label crash canary: cannot prove it, $tag already says could not run on a clean tree"
      FAIL=$((FAIL+1)); return
    fi
  done
  cp "$AUDIT_BAK" "$AUDIT"
  python3 - "$anchor" <<'PYCRASH'
import sys
p = 'tools/audit/site_audit.sh'
s = open(p, encoding='utf-8').read()
a = sys.argv[1]
if s.count(a) != 1:
    raise SystemExit(2)
open(p, 'w', encoding='utf-8').write(s.replace(a, 'deliberate crash canary\n' + a, 1))
PYCRASH
  prc=$?
  if [ "$prc" -ne 0 ]; then
    cp "$AUDIT_BAK" "$AUDIT"
    echo "  ⚠ $label crash canary: the anchor no longer occurs exactly once, not proven"
    SKIP=$((SKIP+1)); return
  fi
  out=$(run_audit); rc=$?
  cp "$AUDIT_BAK" "$AUDIT"
  [ "$rc" -ne 0 ] || ok=0
  for pair in "$@"; do
    tag="${pair%%=*}"; text="${pair#*=}"
    contains "$(section_of "$out" "$tag")" "$text" || ok=0
  done
  if [ "$ok" = 1 ]; then
    echo "  ✓ $label goes red when its interpreter crashes"
    PASS=$((PASS+1))
  else
    echo "  ✗ $label still prints green when its interpreter crashes: FALSE GREEN"
    FAIL=$((FAIL+1))
  fi
}

crash_canary "A1" $'EXCLUDE = re.compile(\'|\'.join([' "[A1]=A1 check could not run"
crash_canary "A7 and A9 (shared filter)" 'rx = re.compile(accept)' "[A7]=A7 check could not run" "[A9]=A9 check could not run"
crash_canary "8.2" 'PATS = [re.compile(' "[A8]=8.2 check could not run"
crash_canary "8.3" $'PAT = re.compile(r\'(攻略集|' "[A8]=8.3 check could not run"
crash_canary "A11 and A12 (shared analyzer)" $'KW_BEFORE_REGEX = {\'return\'' "[A11]=A11 check could not run" "[A12]=A12 check could not run"
crash_canary "A14" 'PUA = re.compile(' "[A14]=A14 check could not run"
crash_canary "A15" $'ANCHORS = [(\'canonical\',' "[A15]=A15 check could not run"
crash_canary "A16 (history table)" $'BASE = \'https://toniliumvp.github.io/LunaticDawn/\'' "[A16]=A16 check could not run"
crash_canary "A16 (uncommitted changes)" $'mode = os.environ.get(\'LD_AUDIT_MODE\', \'tree\')' "[A16]=A16 check could not run"
crash_canary "A17" 'PATH_PATTERNS = [' "[A17]=A17 check could not run"
crash_canary "A18" $'MARK = r\'' "[A18]=A18 check could not run"
cp "$AUDIT_BAK" "$AUDIT"; rm -f "$AUDIT_BAK"

# Coverage. The rules to expect come from the audit's own output, so a rule added
# to site_audit.sh without a bait here is reported instead of passing unnoticed.
# A8 is a bundle of sub-rules (8.1 .. 8.5 as printed) and A17 has two layers.
EXPECTED=""
for id in $(printf '%s\n' "$BASELINE" | grep -oE '^  \[A[0-9]+\]' | tr -d ' []'); do
  case "$id" in
    A8)
      for n in $(section_of "$BASELINE" "[A8]" | grep -oE '^  [^ ]+ 8\.[0-9]+' | grep -oE '8\.[0-9]+'); do
        EXPECTED="$EXPECTED A$n"
      done ;;
    A17) EXPECTED="$EXPECTED A17.1 A17.2" ;;
    *)   EXPECTED="$EXPECTED $id" ;;
  esac
done
if [ -z "$EXPECTED" ]; then
  echo "  ✗ coverage: could not read the list of rules from the audit output"
  FAIL=$((FAIL+1))
fi
MISSING=""
for id in $EXPECTED; do
  contains "$COVERED" " $id " || MISSING="$MISSING $id"
done
if [ -n "$MISSING" ]; then
  echo "  ✗ coverage: no planted check proved these rules:$MISSING"
  FAIL=$((FAIL+1))
fi
if [ "$PASS" -eq 0 ]; then
  echo "  ✗ nothing was proven"
  FAIL=$((FAIL+1))
fi

echo ""
echo "  live rules: $PASS   dead checks: $FAIL   not proven: $SKIP"
if [ "$FAIL" -gt 0 ] || [ "$SKIP" -gt 0 ]; then
  echo "  Status: ✗ at least one rule was not proven live, fix before trusting a green audit"
  exit 1
fi
echo "  Status: ✓ all $PASS planted checks fired"
exit 0
