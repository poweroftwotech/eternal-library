#!/bin/sh
# Persistence gate (ENVIRONMENT_PLAN.md 6.5.7, phase-4-design.md 8.1.7): each mode is its own OS
# process, so nothing survives in memory between them. Run from Git Bash:
#   sh tests/persist_gate.sh
GODOT=/c/projects/Godot_v4.7.2-stable_mono_win64_console.exe
PROJ=C:/projects/eternal-library
SAVE=--save=user://test/persist.json
AREA_SAVE=--save=user://test/persist_area.json
AREA_SEED=--area-seed=2
# phase-5-design.md 5.6.9: the same two area processes in the Lower Stacks.
LS_SAVE=--save=user://test/persist_lower_stacks.json
LS_SEED=--area-seed=9
# phase-6-design.md 5.7.6: through the gorge's door into the Lower Stacks and back.
DOOR_SAVE=--save=user://test/persist_door.json
# phase 7 steps 3-4: the camp from kit pieces, where the game starts, and its door to the Gorge.
CAMP_SAVE=--save=user://test/persist_camp.json
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
timeout 300 "$GODOT" --headless --path "$PROJ" --script res://tests/persist_test.gd -- area_save "$LS_SAVE" --fresh "$LS_SEED" --area-id=lower_stacks > /tmp/persist_ls_save.log 2>&1 || { grep -E "persist_test|FAIL|ERROR|  " /tmp/persist_ls_save.log; exit 1; }
grep -E "persist_test|FAIL|aged" /tmp/persist_ls_save.log
timeout 300 "$GODOT" --headless --path "$PROJ" --script res://tests/persist_test.gd -- area_load "$LS_SAVE" --area-id=lower_stacks > /tmp/persist_ls_load.log 2>&1 || { grep -E "persist_test|FAIL|ERROR|  " /tmp/persist_ls_load.log; exit 1; }
grep -E "persist_test|FAIL|aged" /tmp/persist_ls_load.log
timeout 300 "$GODOT" --headless --path "$PROJ" --script res://tests/persist_test.gd -- door_save "$DOOR_SAVE" --fresh > /tmp/persist_door_save.log 2>&1 || { grep -E "persist_test|FAIL|ERROR|  " /tmp/persist_door_save.log; exit 1; }
grep -E "persist_test|FAIL" /tmp/persist_door_save.log
timeout 300 "$GODOT" --headless --path "$PROJ" --script res://tests/persist_test.gd -- door_cross "$DOOR_SAVE" > /tmp/persist_door_cross.log 2>&1 || { grep -E "persist_test|FAIL|ERROR|  " /tmp/persist_door_cross.log; exit 1; }
grep -E "persist_test|FAIL" /tmp/persist_door_cross.log
timeout 300 "$GODOT" --headless --path "$PROJ" --script res://tests/persist_test.gd -- door_back "$DOOR_SAVE" > /tmp/persist_door_back.log 2>&1 || { grep -E "persist_test|FAIL|ERROR|  " /tmp/persist_door_back.log; exit 1; }
grep -E "persist_test|FAIL" /tmp/persist_door_back.log
timeout 300 "$GODOT" --headless --path "$PROJ" --script res://tests/persist_test.gd -- camp_save "$CAMP_SAVE" --fresh > /tmp/persist_camp_save.log 2>&1 || { grep -E "persist_test|FAIL|ERROR|  " /tmp/persist_camp_save.log; exit 1; }
grep -E "persist_test|FAIL" /tmp/persist_camp_save.log
timeout 300 "$GODOT" --headless --path "$PROJ" --script res://tests/persist_test.gd -- camp_load "$CAMP_SAVE" > /tmp/persist_camp_load.log 2>&1 || { grep -E "persist_test|FAIL|ERROR|  " /tmp/persist_camp_load.log; exit 1; }
grep -E "persist_test|FAIL" /tmp/persist_camp_load.log
timeout 300 "$GODOT" --headless --path "$PROJ" --script res://tests/persist_test.gd -- camp_cross "$CAMP_SAVE" > /tmp/persist_camp_cross.log 2>&1 || { grep -E "persist_test|FAIL|ERROR|  " /tmp/persist_camp_cross.log; exit 1; }
grep -E "persist_test|FAIL" /tmp/persist_camp_cross.log
timeout 300 "$GODOT" --headless --path "$PROJ" --script res://tests/persist_test.gd -- camp_back "$CAMP_SAVE" > /tmp/persist_camp_back.log 2>&1 || { grep -E "persist_test|FAIL|ERROR|  " /tmp/persist_camp_back.log; exit 1; }
grep -E "persist_test|FAIL" /tmp/persist_camp_back.log
echo "persist_gate: all sixteen processes passed"
