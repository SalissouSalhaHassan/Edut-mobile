@echo off
title Edut Mobile APK Builder

echo ===================================================
echo   COMPILATION NOUVEAU APK (Edut Pro Mobile)
echo ===================================================
echo.

cd /d C:\Users\User\Desktop\Edut\mobile

set FLUTTER_EXE=flutter
if exist "C:\src\flutter\bin\flutter.bat" (
    set FLUTTER_EXE=C:\src\flutter\bin\flutter.bat
)

echo [1/3] Installation des packages...
call %FLUTTER_EXE% pub get
if errorlevel 1 (
    echo Erreur lors de flutter pub get.
    pause
    exit /b 1
)

echo.
echo [2/3] Verification Gradle...
cd android
call gradlew.bat --stop >nul 2>&1
cd ..

echo.
echo [3/3] Compilation du fichier APK Release...
call %FLUTTER_EXE% build apk --release --no-tree-shake-icons
if errorlevel 1 (
    echo.
    echo ===================================================
    echo   ECHEC DE LA COMPILATION !
    echo   Veuillez verifier les messages d'erreur ci-dessus.
    echo ===================================================
    pause
    exit /b 1
)

echo.
echo ===================================================
echo   COMPILATION TERMINEE AVEC SUCCES !
echo   Fichier APK genere a :
echo   C:\Users\User\Desktop\Edut\mobile\build\app\outputs\flutter-apk\app-release.apk
echo ===================================================
echo.
pause
