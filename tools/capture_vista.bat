@echo off
rem Renders the overlook on THIS machine's GPU (Forward+) and compares it with
rem the box art (tests/compare_vista.gd, ART_DIRECTION.md section 8).
setlocal
set GODOT=C:\projects\Godot_v4.7.2-stable_mono_win64_console.exe
set PROJ=%~dp0..
if not exist "%GODOT%" (
  echo Godot not found at %GODOT% - edit the GODOT line in this file.
  pause
  exit /b 1
)
echo Importing assets...
"%GODOT%" --headless --path "%PROJ%" --import >nul 2>nul
echo Rendering overlook... (a game window opens for a few seconds)
"%GODOT%" --path "%PROJ%" --resolution 1600x900 --script res://tests/capture.gd -- "%PROJ%\previews\vista_v013.png" vista_concept 120
"%GODOT%" --headless --path "%PROJ%" --script res://tests/compare_vista.gd -- "%PROJ%\previews\vista_v013.png"
echo.
echo Done. Image is previews\vista_v013.png.
pause
