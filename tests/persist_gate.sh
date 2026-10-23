#!/bin/sh
# Persistence gate (ENVIRONMENT_PLAN.md 6.5.7, phase-4-design.md 8.1.7): each mode is its own OS
# process, so nothing survives in memory between them. Run from Git Bash:
#   sh tests/persist_gate.sh
GODOT=/c/projects/Godot_v4.7.2-stable_mono_win64_console.exe
PROJ=C:/projects/eternal-library
SAVE=--save=user://test/persist.json
AREA_SAVE=--save=user://test/persist_area.json
AREA_SEED=--area-seed=2
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
timeout 300 "$GODOT" --headless --path "$PROJ" --script res://tests/persist_test.gd -- area_save "$AREA_SAVE" --fresh "$AREA_SEED" > /tmp/persist_area_save.log 2>&1 || { grep -E "persist_test|FAIL|ERROR|  " /tmp/persist_area_save.log; exit 1; }
grep -E "persist_test|FAIL|aged" /tmp/persist_area_save.log
timeout 300 "$GODOT" --headless --path "$PROJ" --script res://tests/persist_test.gd -- area_load "$AREA_SAVE" > /tmp/persist_area_load.log 2>&1 || { grep -E "persist_test|FAIL|ERROR|  " /tmp/persist_area_load.log; exit 1; }
grep -E "persist_test|FAIL|aged" /tmp/persist_area_load.log
echo "persist_gate: all seven processes passed"
