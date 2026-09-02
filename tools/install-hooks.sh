#!/usr/bin/env bash
# Point git at the tracked hooks directory so a fresh clone gets the same
# pre-commit audit as the original working copy. Run once after cloning:
#   bash tools/install-hooks.sh
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git config core.hooksPath .githooks
echo "✓ core.hooksPath -> .githooks"
echo "  Hooks now in effect:"
ls -1 .githooks
