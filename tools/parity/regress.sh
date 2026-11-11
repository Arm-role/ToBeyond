#!/usr/bin/env bash
# Compare the headless regression scripts with the committed baseline in tools/parity/baseline/.
#   tools/parity/regress.sh            run artifact_regress, chaos_use, chaos_dump and diff (exit 1 on any diff)
#   tools/parity/regress.sh --update   rewrite the baseline (do this only for an intended change, commit the diff)
# The scripts are deterministic (two runs are byte-identical); only Godot's banner line is dropped.
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-$(command -v godot || bash tools/parity/setup_godot.sh)}
mkdir -p tools/parity/baseline build/regress
fail=0
for s in artifact_regress chaos_use chaos_dump; do
  out=build/regress/$s.txt
  timeout 120 "$GODOT" --headless --path . --script "res://tools/parity/$s.gd" 2>&1 | grep -v '^Godot Engine v' | sed '/./,$!d' > "$out"
  if grep -qE "SCRIPT ERROR|^ERROR" "$out" || [ ! -s "$out" ]; then
    echo "regress $s: script error or empty output (see $out)"; grep -E "SCRIPT ERROR|^ERROR" "$out" | head -5; fail=1; continue
  fi
  if [ "${1:-}" = "--update" ]; then cp "$out" "tools/parity/baseline/$s.txt"; echo "baseline updated: $s ($(wc -l < "$out") lines)"; continue; fi
  if [ ! -f "tools/parity/baseline/$s.txt" ]; then echo "regress $s: no baseline (run --update)"; fail=1; continue; fi
  if ! diff -q "tools/parity/baseline/$s.txt" "$out" >/dev/null; then
    echo "regress $s: DIFFERS from baseline"; diff -u "tools/parity/baseline/$s.txt" "$out" | head -40 | cut -c1-220; fail=1; continue
  fi
  echo "regress $s: OK"
done
[ "$fail" = 1 ] && { echo "regress FAILED"; exit 1; }
[ "${1:-}" = "--update" ] || echo "regress OK"
