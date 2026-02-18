@echo off
REM ============================================
REM  AuraRush - Local Web Export Script
REM  Exports the Godot project for Vercel deployment
REM ============================================

echo.
echo  ========================================
echo   AuraRush - Web Export for Vercel
echo  ========================================
echo.

REM Check if Godot is in PATH or set the path manually
where godot >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [!] Godot not found in PATH.
    echo     Please set GODOT_PATH below or add Godot to your PATH.
    echo     Example: set GODOT_PATH="C:\Godot\Godot_v4.6-stable_win64.exe"
    set /p GODOT_PATH="Enter full path to Godot executable: "
) else (
    set GODOT_PATH=godot
)

REM Clean previous build
echo [1/4] Cleaning previous build...
if exist "dist\index.html" del /q "dist\index.*"
if exist "dist\*.wasm" del /q "dist\*.wasm"
if exist "dist\*.pck" del /q "dist\*.pck"
if exist "dist\*.js" del /q "dist\*.js"
if exist "dist\*.png" del /q "dist\*.png"
if exist "dist\*.worker.js" del /q "dist\*.worker.js"

REM Create dist directory
echo [2/4] Preparing output directory...
if not exist "dist" mkdir dist

REM Import project resources
echo [3/4] Importing project resources...
%GODOT_PATH% --headless --import 2>nul

REM Export to Web
echo [4/4] Exporting to Web...
%GODOT_PATH% --headless --export-release "Web" dist/index.html

REM Verify
echo.
if exist "dist\index.html" (
    echo  [SUCCESS] Export completed!
    echo  Files exported to: dist\
    echo.
    dir /b dist\
    echo.
    echo  Next steps:
    echo    1. Test locally:  npx serve dist
    echo    2. Deploy:        vercel --prod
    echo    3. Or push to GitHub for automatic deployment
) else (
    echo  [FAILED] Export failed!
    echo  Make sure:
    echo    - Godot 4.6+ is installed
    echo    - Web export templates are installed
    echo    - export_presets.cfg is properly configured
)
echo.
pause
