#!/usr/bin/env bash
# Runs every headless test. Usage: ./run_tests.sh   (needs `godot` 4.4+ on PATH)
set -u
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1
status=0
for t in test_ragdoll_drop test_traversal test_game; do
  echo "=== $t"
  "$GODOT" --headless --path . "res://tests/$t.tscn" 2>&1 | grep -E "PASS|FAIL|RESULT|SCRIPT ERROR|ERROR:" || true
  rc=${PIPESTATUS[0]}
  if [ "$rc" -ne 0 ]; then status=1; echo "!! $t exited with $rc"; fi
done
exit $status
