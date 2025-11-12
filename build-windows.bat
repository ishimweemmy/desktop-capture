@echo off
setlocal enabledelayedexpansion

echo ================================
echo Building Desktop Capture v0 (Windows)
echo ================================
echo.

REM Check if .NET SDK is installed
dotnet --version >nul 2>&1
if errorlevel 1 (
    echo Error: .NET SDK is not installed
    echo Please download and install from: https://dotnet.microsoft.com/download
    exit /b 1
)

echo Building native app...
cd native-app-windows

REM Build in release mode
dotnet build -c Release

if errorlevel 1 (
    echo.
    echo Build failed!
    exit /b 1
)

echo.
echo Build successful!
echo.

REM Copy binary to build folder
set BUILD_DIR=..\build-windows
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

set BINARY_PATH=bin\Release\net6.0-windows\DesktopCapture.exe

if exist "%BINARY_PATH%" (
    copy "%BINARY_PATH%" "%BUILD_DIR%\" >nul
    copy "bin\Release\net6.0-windows\*.dll" "%BUILD_DIR%\" >nul
    copy "bin\Release\net6.0-windows\*.json" "%BUILD_DIR%\" >nul
    echo Binary copied to: %BUILD_DIR%\DesktopCapture.exe
    echo.
) else (
    echo Error: Binary not found at %BINARY_PATH%
    exit /b 1
)

cd ..

echo ================================
echo Build Complete!
echo ================================
echo.
echo Next steps:
echo 1. Run install-chrome-host-windows.bat to set up Native Messaging
echo 2. Load chrome-extension\ as unpacked extension in Chrome
echo 3. Run as Administrator: %BUILD_DIR%\DesktopCapture.exe
echo.

pause
