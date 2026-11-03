@echo off
rem Runs the automated gameplay tests (no window opens). Double-click me or run from a terminal.
rem "run_tests.cmd items" runs only the test files with "items" in their name.
set GODOT="%~dp0Godot_v4.7.2-stable_win64_console.exe"
rem Refresh Godot's list of scripts first, so newly added files are found.
%GODOT% --headless --path "%~dp0." --import >nul 2>&1
rem --fixed-fps 60: run the game flat out instead of in real time (each frame still counts as 1/60 s).
%GODOT% --headless --fixed-fps 60 --path "%~dp0." --script res://tests/run_tests.gd -- %*
set RESULT=%ERRORLEVEL%
if "%1"=="" pause
exit /b %RESULT%
