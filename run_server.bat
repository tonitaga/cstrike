@echo off
cls
title StartUp

:: Переход в папку cstrike/hfs и запуск hfs.exe
cd /d "cstrike\hfs"
echo (%time%) Starting HFS...
start "HFS Server" hfs.exe
cd /d ../..

:: Ожидание немного для запуска HFS
timeout /t 1 /nobreak >nul

:hlds
echo (%time%) HLDS Starting...
reg add "HKCU\Software\Valve\Steam\ActiveProcess" /v SteamClientDll /t REG_SZ /d "" /f
start /wait /high hlds.exe -autoupdate -console -game cstrike -secure -master -noipx +maxplayers 32 +port 27015
echo (%time%) HLDS Crashed, restarting...
goto hlds