@echo off
rem Renders the concept-matched view on THIS machine's GPU (Forward+) and
rem prints the luminance comparison (tests/compare_concept.gd, no Python needed).
rem Double-click from Explorer, or run from the project folder.
setlocal
set GODOT=C:\projects\Godot_v4.7.2-stable_mono_win64_console.exe
set PROJ=%~dp0..
if not exist "%GODOT%" (
  echo Godot not found at %GODOT% - edit the GODOT line in this file.
  pause
  exit /b 1
)
rem Import first: captures taken before the px textures import render white.
echo Importing assets...
"%GODOT%" --headless --path "%PROJ%" --import >nul 2>nul
echo Rendering concept view... (a game window opens for a few seconds)
"%GODOT%" --path "%PROJ%" --resolution 1600x900 --script res://tests/capture.gd -- "%PROJ%\previews\concept_v011.png" concept 120
"%GODOT%" --path "%PROJ%" --resolution 1600x900 --script res://tests/capture.gd -- "%PROJ%\previews\garden_v011.png" garden 120
"%GODOT%" --headless --path "%PROJ%" --script res://tests/compare_concept.gd -- "%PROJ%\previews\concept_v011.png"
where python >nul 2>nul && python "%PROJ%\tools\compare_concept.py" "%PROJ%\previews\concept_v011.png"
echo.
echo Done. Images are in the previews folder.
pause
