@echo off
rem Export kit modules from art_src\kit\*.blend, import them into Godot and
rem refresh the wrapper scenes + kit\catalog.tres (ENVIRONMENT_PLAN.md phase 0).
rem Double-click after saving a .blend, or run: tools\export_kit.bat kit_walls.blend
setlocal
set BLENDER=C:\projects\blender-5.2.2-windows-x64\blender-5.2.2-windows-x64\blender.exe
set GODOT=C:\projects\Godot_v4.7.2-stable_mono_win64_console.exe
set PROJ=%~dp0..
if not exist "%BLENDER%" (
  echo Blender not found at %BLENDER% - edit the BLENDER line in this file.
  pause
  exit /b 1
)
if not exist "%GODOT%" (
  echo Godot not found at %GODOT% - edit the GODOT line in this file.
  pause
  exit /b 1
)
echo Exporting modules from Blender...
"%BLENDER%" --background --factory-startup --python "%PROJ%\tools\export_kit.py" -- %* || goto :fail
echo Importing into Godot...
rem Twice: the first pass may create new materials, the second registers their IDs.
"%GODOT%" --headless --path "%PROJ%" --import >nul 2>nul
"%GODOT%" --headless --path "%PROJ%" --import >nul 2>nul
echo Refreshing wrapper scenes and catalog...
"%GODOT%" --headless --path "%PROJ%" --script res://tools/kit_catalog.gd || goto :fail
echo.
echo Done. If the Godot editor is open it picks up the changes automatically.
if "%~1"=="" pause
exit /b 0
:fail
echo.
echo Export failed - see the messages above.
if "%~1"=="" pause
exit /b 1
