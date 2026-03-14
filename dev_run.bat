@echo off
echo Starting Scraps App Development...
echo.

echo Available options:
echo 1. Run on Web (Chrome) - Fastest
echo 2. Run on Android Device - Slower but full features
echo 3. Run on Windows Desktop
echo 4. Hot Restart (if already running)
echo.

set /p choice="Enter your choice (1-4): "

if "%choice%"=="1" (
    echo Starting on Chrome...
    flutter run -d chrome --web-port=8080
) else if "%choice%"=="2" (
    echo Starting on Android device...
    flutter run -d 12386254BK102836
) else if "%choice%"=="3" (
    echo Starting on Windows...
    flutter run -d windows
) else if "%choice%"=="4" (
    echo Hot restarting...
    flutter run --hot
) else (
    echo Invalid choice. Starting on Chrome by default...
    flutter run -d chrome --web-port=8080
)

pause
