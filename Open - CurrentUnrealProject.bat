@echo off
python "%~dp0UnrealProductivityUtils.py"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Script failed. Press any key to exit...
    pause >nul
)
