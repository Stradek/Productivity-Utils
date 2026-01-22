@echo off
python "%~dp0UnrealProductivityUtils.py" --generate-project-files
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Script failed. Press any key to exit...
    pause >nul
)
