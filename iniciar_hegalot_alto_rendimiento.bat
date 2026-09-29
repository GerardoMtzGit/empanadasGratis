@echo off
title HegalOT - Modo Alto Rendimiento (High Priority)
echo ====================================================
echo  Iniciando HegalOT con Maxima Prioridad de CPU y Recursos
echo ====================================================
cd /d "%~dp0"
start "" /high "client.exe"
exit
