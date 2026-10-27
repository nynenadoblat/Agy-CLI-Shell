@echo off
:: Запуск графической оболочки Antigravity без отображения окна консоли
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0AntigravityGUI.ps1"
