@echo off
title Edut Mobile APK Builder
echo ===================================================
echo   COMPILATION D'UN NOUVEAU APK (Edut Pro Mobile)
echo ===================================================
echo.
cd /d C:\Users\User\Desktop\Edut\mobile

echo [1/3] Nettoyage des anciens builds...
call flutter clean

echo [2/3] Récupération des dépendances...
call flutter pub get

echo [3/3] BDD & Compilation du fichier APK Release...
call flutter build apk --release

echo.
echo ===================================================
echo   COMPILATION TERMINÉE AVEC SUCCÈS !
echo   Fichier APK généré à :
echo   C:\Users\User\Desktop\Edut\mobile\build\app\outputs\flutter-apk\app-release.apk
echo ===================================================
pause
