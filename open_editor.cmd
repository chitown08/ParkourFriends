@echo off
rem Opens this project in the Godot editor. (Double-clicking the Godot exe itself runs the game instead,
rem because it notices the project in its folder.)
start "" "%~dp0Godot_v4.7.2-stable_win64.exe" --editor --path "%~dp0."
