@echo off
title Maze Wars Launcher
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Play-MazeWars.ps1"
exit /b %ERRORLEVEL%
