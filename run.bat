@echo off
chcp 65001 >nul

where py >nul 2>&1
if %errorlevel%==0 (
    py "%~dp0copy_tool.py"
    if %errorlevel% neq 0 (
        echo.
        echo [Error] Program encountered an error. Error code: %errorlevel%
        echo Please check if Python is installed correctly.
        pause
    )
    goto :eof
)

where python >nul 2>&1
if %errorlevel%==0 (
    python "%~dp0copy_tool.py"
    if %errorlevel% neq 0 (
        echo.
        echo [Error] Program encountered an error. Error code: %errorlevel%
        pause
    )
    goto :eof
)

echo ======================================
echo  Python is not installed!
echo ======================================
echo.
echo Please install Python first:
echo https://www.python.org/downloads/
echo.
echo During installation, check "Add Python to PATH"
echo.
pause
