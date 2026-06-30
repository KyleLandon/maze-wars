@echo off
title Maze Wars - Open Firewall Port
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0open-firewall-port.ps1""'"
exit /b 0
