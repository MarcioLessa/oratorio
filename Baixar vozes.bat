@echo off
rem Baixa as vozes de leitura do Oratorio para a pasta voz.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0baixar-vozes.ps1"
