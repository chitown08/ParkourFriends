@echo off
rem Builds the game for Windows into build\windows\ (what friends get: no developer tools),
rem then runs the built game's self-check (every world loads, outfits, music, Steam).
rem Needs Godot's export templates installed (Editor > Manage Export Templates).
set GODOT="%~dp0Godot_v4.7.2-stable_win64_console.exe"
set OUT=%~dp0build\windows
if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%OUT%"
%GODOT% --headless --path "%~dp0." --import >nul 2>&1
%GODOT% --headless --path "%~dp0." --export-release "Windows" "%OUT%\ParkourFriends.exe" >"%~dp0build\export.log" 2>&1
if not exist "%OUT%\ParkourFriends.exe" (
	echo Build failed: see build\export.log
	set RESULT=1
	goto done
)
start "" /wait "%OUT%\ParkourFriends.exe" --headless --log-file "%~dp0build\check.log" -- --check-build
set RESULT=%ERRORLEVEL%
type "%~dp0build\check.log"
if %RESULT%==0 (echo Built %OUT%\ParkourFriends.exe) else (echo The built game failed its self-check: see above)
:done
if "%1"=="" pause
exit /b %RESULT%
