@echo off
REM Run a Maze Wars dedicated lobby server (auto-starts when all players ready).
setlocal
set "GAME_DIR=%LOCALAPPDATA%\MazeWars"
set "EXE=%GAME_DIR%\MazeWars.exe"
if not exist "%EXE%" set "EXE=%~dp0..\..\build\MazeWars.exe"
if not exist "%EXE%" (
  echo MazeWars.exe not found. Run Play-MazeWars.bat once or export the game.
  pause
  exit /b 1
)
echo Starting dedicated server on UDP 7777...
"%EXE%" --dedicated-server
