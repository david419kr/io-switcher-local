@echo off
REM Build debug and release APKs locally. Requires Flutter in PATH and Android SDK configured.
cd /d "%~dp0"
flutter pub get
flutter build apk --debug
flutter build apk --release
if exist build\app\outputs\flutter-apk\app-debug.apk echo Debug APK: build\app\outputs\flutter-apk\app-debug.apk
if exist build\app\outputs\flutter-apk\app-release.apk echo Release APK: build\app\outputs\flutter-apk\app-release.apk
pause