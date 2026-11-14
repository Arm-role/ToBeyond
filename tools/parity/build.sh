#!/usr/bin/env bash
# Check and build the game, printing only what matters.
#   tools/parity/build.sh --check   parse every script (~0.3 s each), verify skill-doc references
#                                   (check_refs.py), and smoke-run the Domino scene headless (TB_DOMINO_OK)
#   (TB_SKIP_REFS=1 skips the reference check; evals use it on old code bases)
#   tools/parity/build.sh --regress [--update]   the check, then the artifact + domino regression
#                                   against tools/parity/baseline (--update rewrites it)
#   tools/parity/build.sh           the check, then import + Web export to build/web (~1 min)
# Full logs: build/import.log, build/export.log
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-$(command -v godot || bash tools/parity/setup_godot.sh)}
mkdir -p build
fail=0
for f in $(find scripts -name '*.gd' | sort); do
  if ! out=$("$GODOT" --headless --path . --check-only --script "res://$f" 2>&1); then
    echo "$out" | grep -E "ERROR|at: " | head -6; fail=1
  fi
done
[ "$fail" = 1 ] && { echo "check FAILED (parse errors above)"; exit 1; }
[ -n "${TB_SKIP_REFS:-}" ] || python3 tools/parity/check_refs.py || { echo "check FAILED (stale skill-doc references)"; exit 1; }
# Domino smoke (main scene): the view prints TB_DOMINO_OK once the first hand is dealt
drun=$(timeout 60 "$GODOT" --headless --path . -- --domino-smoke 2>&1)
if ! echo "$drun" | grep -q "^TB_DOMINO_OK"; then
  echo "$drun" | grep -E "SCRIPT ERROR|^ERROR|^ +at: " | head -8
  echo "check FAILED (the Domino scene did not reach the first hand)"; exit 1
fi
# The old game (?mode=classic) is smoke-run only on request: TB_CLASSIC_SMOKE=1
if [ -n "${TB_CLASSIC_SMOKE:-}" ]; then
  crun=$(timeout 60 "$GODOT" --headless --path . -- --mode=classic --dbg=main --rects=/dev/null 2>&1)
  echo "$crun" | grep -q "^TB_RECTS" || { echo "check FAILED (classic game did not reach the test state)"; exit 1; }
fi
echo "check OK"
[ "${1:-}" = "--check" ] && exit 0
[ "${1:-}" = "--regress" ] && exec bash tools/parity/regress.sh "${2:-}"

start=$(date +%s)
git rev-parse --short HEAD > build_info.txt 2>/dev/null || true
"$GODOT" --headless --path . --import > build/import.log 2>&1
mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html > build/export.log 2>&1
code=$?
if [ $code -ne 0 ] || [ ! -f build/web/index.pck ] || [ "$(stat -c %Y build/web/index.pck)" -lt "$start" ]; then
  grep -E "ERROR|error" build/export.log | head -15
  echo "build FAILED (exit $code) — see build/export.log, build/import.log"; exit 1
fi
grep -E "SCRIPT ERROR|^ERROR" build/export.log | head -8
echo "build OK in $(( $(date +%s) - start ))s -> build/web ($(du -sh build/web | cut -f1))"
