Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  COMPILATION NOUVEAU APK (Edut Pro Mobile)" -ForegroundColor Yellow
Write-Host "===================================================" -ForegroundColor Cyan

Set-Location -Path "C:\Users\User\Desktop\Edut\mobile"

Write-Host "`n[1/3] Nettoyage du cache Flutter..." -ForegroundColor Green
flutter clean

Write-Host "`n[2/3] Installation des packages..." -ForegroundColor Green
flutter pub get

Write-Host "`n[3/3] Bâtissage du fichier app-release.apk..." -ForegroundColor Green
flutter build apk --release

Write-Host "`n===================================================" -ForegroundColor Cyan
Write-Host "  COMPILATION TERMINÉE AVEC SUCCÈS !" -ForegroundColor Green
Write-Host "  Fichier APK disponible ici :" -ForegroundColor Yellow
Write-Host "  C:\Users\User\Desktop\Edut\mobile\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor White
Write-Host "===================================================" -ForegroundColor Cyan
