#!/usr/bin/env bash
# Point git at the tracked hooks directory, then prove the hooks will actually
# run. Run once after cloning:
#   bash tools/install-hooks.sh
#
# Setting core.hooksPath is not enough. Git only executes a hook that carries
# the execute bit, and this repo has core.fileMode=false (set years ago for the
# SMB working copy), so a local chmod never reaches the index and a fresh clone
# lands the hook at 644. The previous version of this script set the path,
# printed "Hooks now in effect", listed the filenames, and exited 0 -- while
# installing hooks that git would skip without a word.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

git config core.hooksPath .githooks
echo "✓ core.hooksPath -> .githooks"
echo

fail=0
found=0
for hook in .githooks/*; do
  [ -f "$hook" ] || continue
  found=$((found + 1))
  name=$(basename "$hook")

  # Repair the working copy if the clone landed it non-executable.
  [ -x "$hook" ] || chmod +x "$hook" 2>/dev/null || true

  mode=$(git ls-files -s "$hook" | awk '{print $1}')
  if [ -x "$hook" ] && [ "$mode" = "100755" ]; then
    echo "  ✓ $name — will run (index $mode)"
  else
    echo "  ✗ $name — git would SKIP this hook"
    [ -x "$hook" ] || echo "      working copy is not executable"
    [ "$mode" = "100755" ] || echo "      index records $mode; fix with:"
    [ "$mode" = "100755" ] || echo "        git update-index --chmod=+x $hook && git commit -m 'chore: mark hook executable'"
    fail=1
  fi
done

if [ "$found" = 0 ]; then
  echo "✗ No hooks found in .githooks/ — nothing was installed."
  exit 1
fi

echo
if [ "$fail" = 0 ]; then
  echo "✓ $found hook(s) verified executable."
else
  echo "✗ At least one hook would be skipped silently. Fix before relying on it."
  exit 1
fi
