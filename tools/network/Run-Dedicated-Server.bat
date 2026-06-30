@echo off
REM Dedicated server — opens the server dashboard (not the game client).
setlocal
set "GAME_DIR=%LOCALAPPDATA%\MazeWars"
set "EXE=%GAME_DIR%\MazeWars.exe"
if not exist "%EXE%" set "EXE=%~dp0..\..\build\MazeWars.exe"
if not exist "%EXE%" (
  echo MazeWars.exe not found. Run Play-MazeWars.bat once or export the game.
  pause
  exit /b 1
)
echo Opening Windows Firewall for UDP 7777 (admin prompt once)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0open-firewall-port.ps1\"\" -Quiet'"
echo Starting Maze Wars dedicated server dashboard on UDP 7777...
"%EXE%" --dedicated-server
