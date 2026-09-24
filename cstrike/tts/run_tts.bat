@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title incom_tts

where node >nul 2>&1
if errorlevel 1 (
    echo Node.js not found. Install it and add to PATH.
    pause
    exit /b 1
)

where ffmpeg >nul 2>&1
if errorlevel 1 (
    echo ffmpeg not found. Install it and add to PATH.
    pause
    exit /b 1
)

:run
echo (%time%) Starting incom_tts...
node "%~dp0incom_tts.js"
echo (%time%) incom_tts stopped, restarting...
timeout /t 2 /nobreak >nul
goto run
