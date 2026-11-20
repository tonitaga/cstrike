@echo off
cls
title StartUp

cd /d "%~dp0"
if /i "%~1"=="--check" goto check

call :fastdl
if errorlevel 1 exit /b 1

cd /d "%~dp0cstrike\tts"
echo (%time%) Starting TTS...
start "TTS" cmd /c run_tts.bat
cd /d "%~dp0"

:hlds
echo (%time%) HLDS Starting...
reg add "HKCU\Software\Valve\Steam\ActiveProcess" /v SteamClientDll /t REG_SZ /d "" /f
start /wait /high hlds.exe -autoupdate -console -game cstrike -secure -master -noipx +maxplayers 32 +port 27015
echo (%time%) HLDS Crashed, restarting...
goto hlds
:check
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0tools\start_fastdl.ps1" -CheckOnly
exit /b %errorlevel%

:fastdl
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0tools\start_fastdl.ps1"
exit /b %errorlevel%
