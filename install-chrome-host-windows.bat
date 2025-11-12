@echo off
setlocal enabledelayedexpansion

echo ================================
echo Installing Native Messaging Host (Windows)
echo ================================
echo.

REM Get absolute path to binary
set SCRIPT_DIR=%~dp0
set BINARY_PATH=%SCRIPT_DIR%build-windows\DesktopCapture.exe

if not exist "%BINARY_PATH%" (
    echo Error: Binary not found at %BINARY_PATH%
    echo Please run build-windows.bat first
    pause
    exit /b 1
)

echo Binary path: %BINARY_PATH%
echo.

REM Prompt for Chrome extension ID
echo To get your Chrome extension ID:
echo 1. Open Chrome and go to chrome://extensions/
echo 2. Enable 'Developer mode' (toggle in top-right)
echo 3. Click 'Load unpacked' and select the chrome-extension folder
echo 4. Copy the Extension ID shown in the extension card
echo.

set /p EXTENSION_ID="Enter Chrome Extension ID: "

if "%EXTENSION_ID%"=="" (
    echo Error: Extension ID is required
    pause
    exit /b 1
)

echo.
echo Extension ID: %EXTENSION_ID%

REM Create Native Messaging host manifest
set MANIFEST_DIR=%LOCALAPPDATA%\Google\Chrome\NativeMessagingHosts
if not exist "%MANIFEST_DIR%" mkdir "%MANIFEST_DIR%"

set MANIFEST_PATH=%MANIFEST_DIR%\com.desktopcapture.host.json

REM Escape backslashes for JSON
set BINARY_PATH_JSON=%BINARY_PATH:\=\\%

REM Write manifest file
(
echo {
echo   "name": "com.desktopcapture.host",
echo   "description": "Desktop Capture Native Messaging Host",
echo   "path": "%BINARY_PATH_JSON%",
echo   "type": "stdio",
echo   "allowed_origins": [
echo     "chrome-extension://%EXTENSION_ID%/"
echo   ]
echo }
) > "%MANIFEST_PATH%"

echo.
echo Native Messaging host manifest created:
echo %MANIFEST_PATH%
echo.
echo ================================
echo Installation Complete!
echo ================================
echo.
echo The Chrome extension can now communicate with the native app.
echo.
echo Next steps:
echo 1. Make sure the extension is loaded in Chrome
echo 2. Run as Administrator: %BINARY_PATH%
echo.

pause
