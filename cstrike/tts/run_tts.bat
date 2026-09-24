@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title incom_tts

:: ---------- winget ----------
where winget >nul 2>&1
if errorlevel 1 (
    echo [ERROR] winget not found. Please install App Installer from Microsoft Store.
    pause
    exit /b 1
)

:: ---------- Node.js ----------
where node >nul 2>&1
if errorlevel 1 (
    echo [INFO] Node.js not found. Installing Node.js LTS via winget...
    winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo [ERROR] Failed to install Node.js. Please install manually: https://nodejs.org/
        pause
        exit /b 1
    )
    echo [INFO] Node.js installed. Please close this window and run start.bat again to refresh PATH.
    pause
    exit /b 0
)

:: ---------- FFmpeg ----------
where ffmpeg >nul 2>&1
if errorlevel 1 (
    echo [INFO] FFmpeg not found. Installing FFmpeg via winget...
    winget install -e --id Gyan.FFmpeg --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo [ERROR] Failed to install FFmpeg. Please install manually: https://ffmpeg.org/
        pause
        exit /b 1
    )
    echo [INFO] FFmpeg installed. Please close this window and run start.bat again to refresh PATH.
    pause
    exit /b 0
)

:run
echo (%time%) Starting incom_tts...
node "%~dp0incom_tts.js"
echo (%time%) incom_tts stopped, restarting...
timeout /t 2 /nobreak >nul
goto run