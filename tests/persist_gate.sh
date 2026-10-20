#!/bin/sh
# Phase 3 persistence gate (ENVIRONMENT_PLAN.md 6.5.7): each mode is its own OS
# process, so nothing survives in memory between them. Run from Git Bash:
#   sh tests/persist_gate.sh
GODOT=/c/projects/Godot_v4.7.2-stable_mono_win64_console.exe
PROJ=C:/projects/eternal-library
SAVE=--save=user://test/persist.json
set -e
timeout 300 "$GODOT" --headless --path "$PROJ" --script res://tests/persist_test.gd -- save "$SAVE" --fresh --gen-seed=7 > /tmp/persist_save.log 2>&1 || { grep -E "persist_test|FAIL|ERROR" /tmp/persist_save.log; exit 1; }
grep -E "persist_test|FAIL" /tmp/persist_save.log
timeout 300 "$GODOT" --headless --path "$PROJ" --script res://tests/persist_test.gd -- load "$SAVE" > /tmp/persist_load.log 2>&1 || { grep -E "persist_test|FAIL|ERROR" /tmp/persist_load.log; exit 1; }
grep -E "persist_test|FAIL" /tmp/persist_load.log
timeout 300 "$GODOT" --headless --path "$PROJ" --script res://tests/persist_test.gd -- reverted "$SAVE" > /tmp/persist_reverted.log 2>&1 || { grep -E "persist_test|FAIL|ERROR" /tmp/persist_reverted.log; exit 1; }
grep -E "persist_test|FAIL" /tmp/persist_reverted.log
timeout 300 "$GODOT" --headless --path "$PROJ" --script res://tests/persist_test.gd -- age "$SAVE" --advance-years=40 > /tmp/persist_age.log 2>&1 || { grep -E "persist_test|FAIL|ERROR" /tmp/persist_age.log; exit 1; }
grep -E "persist_test|FAIL" /tmp/persist_age.log
timeout 300 "$GODOT" --headless --path "$PROJ" --script res://tests/persist_test.gd -- age_again "$SAVE" > /tmp/persist_age_again.log 2>&1 || { grep -E "persist_test|FAIL|ERROR" /tmp/persist_age_again.log; exit 1; }
grep -E "persist_test|FAIL" /tmp/persist_age_again.log
echo "persist_gate: all five processes passed"
