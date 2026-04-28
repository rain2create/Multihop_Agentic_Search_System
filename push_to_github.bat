@echo off
chcp 65001 >nul
echo ========================================
echo   AgenticRAG - GitHub 一键推送
echo ========================================
echo.

:: 检查 PowerShell
where powershell >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] 未找到 PowerShell
    pause
    exit /b 1
)

:: 以 Bypass 策略执行脚本（避免执行策略限制）
powershell -ExecutionPolicy Bypass -File "%~dp0push_to_github.ps1"

if %errorlevel% neq 0 (
    echo.
    echo 推送过程中出现错误。
    pause
    exit /b 1
)

echo.
pause
