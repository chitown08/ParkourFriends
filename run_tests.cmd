@echo off
rem Runs the automated gameplay tests (no window opens). Double-click me or run from a terminal.
set GODOT="%~dp0Godot_v4.7.2-stable_win64_console.exe"
rem Refresh Godot's list of scripts first, so newly added files are found.
%GODOT% --headless --path "%~dp0." --import >nul 2>&1
%GODOT% --headless --path "%~dp0." --script res://tests/run_tests.gd
set RESULT=%ERRORLEVEL%
if "%1"=="" pause
exit /b %RESULT%
