@echo off
chcp 65001 >nul
title Build Nutsty Windows Executable (.exe)
echo ====================================================
echo        Nutsty PyInstaller Windows Bundler
echo ====================================================
echo.

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
