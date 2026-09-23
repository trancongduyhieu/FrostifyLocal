@echo off
chcp 65001 >nul
title Build Nutsty Windows Executable (.exe)
echo ====================================================
echo        Nutsty PyInstaller Windows Bundler
echo ====================================================
echo.

:: Detect working Python executable or fallback to standard install paths
python -c "import sys; exit(0)" >nul 2>nul
if %errorlevel% neq 0 (
    if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" (
        set "PATH=%LOCALAPPDATA%\Programs\Python\Python311;%LOCALAPPDATA%\Programs\Python\Python311\Scripts;%PATH%"
    ) else if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" (
        set "PATH=%LOCALAPPDATA%\Programs\Python\Python312;%LOCALAPPDATA%\Programs\Python\Python312\Scripts;%PATH%"
    ) else if exist "%LOCALAPPDATA%\Programs\Python\Python310\python.exe" (
        set "PATH=%LOCALAPPDATA%\Programs\Python\Python310;%LOCALAPPDATA%\Programs\Python\Python310\Scripts;%PATH%"
    ) else (
        for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do (
            set "PATH=%%b;%PATH%"
        )
    )
)

if exist "venv\Scripts\activate.bat" (
    call venv\Scripts\activate.bat
)

echo [1/2] Checking PyInstaller...
pip install pyinstaller -r requirements_win.txt

echo.
echo [2/2] Packaging Nutsty.exe using nutsty.spec...
pyinstaller --noconfirm --clean nutsty.spec

echo.
if exist "dist\Nutsty\Nutsty.exe" (
    echo ====================================================
    echo [SUCCESS] Standalone app created at: dist\Nutsty\Nutsty.exe
    echo You can distribute the entire dist\Nutsty\ folder as a zip package!
    echo ====================================================
) else (
    echo [ERROR] Build failed. Please inspect the trace above.
)
pause
