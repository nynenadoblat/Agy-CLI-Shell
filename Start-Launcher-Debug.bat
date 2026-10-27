@echo off
:: Запуск графической оболочки Antigravity с отображением консоли для диагностики
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AntigravityGUI.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Ошибка при запуске оболочки! Код возврата: %ERRORLEVEL%
    pause
)
