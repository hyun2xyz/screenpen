@echo off
title ScreenPen for Windows
echo Starting ScreenPen Overlay...
python "%~dp0screenpen_windows.py"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Python execution failed. Make sure Python 3 is installed.
    pause
)
