@echo off
echo Building Hindsight Deployment Guide PDF...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0Build-PDF.ps1"
echo.
pause
