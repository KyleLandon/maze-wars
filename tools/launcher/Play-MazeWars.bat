@echo off
title Maze Wars Launcher
cd /d "%~dp0"

echo Maze Wars Launcher
echo Folder: %~dp0
echo.

if not exist "%~dp0Play-MazeWars.ps1" (
    echo [ERROR] Play-MazeWars.ps1 is missing from this folder.
    echo.
    echo You need all launcher files together:
    echo   Play-MazeWars.bat
    echo   Play-MazeWars.ps1
    echo   config.json
    echo.
    echo If you received a zip, extract the whole folder first.
    echo.
    pause
    exit /b 1
)

if not exist "%~dp0config.json" (
    echo [ERROR] config.json is missing from this folder.
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Play-MazeWars.ps1"
set EXIT_CODE=%ERRORLEVEL%

echo.
if %EXIT_CODE% NEQ 0 (
    echo Launcher failed ^(exit code %EXIT_CODE%^).
) else (
    echo Launcher finished. If the game opened, you can close this window.
)
pause
exit /b %EXIT_CODE%
