PySwitcher Mobile (Flutter)

This is a minimal Flutter app to control PySwitcherIO devices from Android.

Features implemented (matching your desktop `gui.py`):
- Store MAC address, device type (1 or 2), and invert setting using SharedPreferences
- Find devices: Scans for BLE devices whose name contains "SWITCHER_M" and shows a list with Copy/Use buttons
- Switch controls: Separate ON/OFF buttons for Switch1 and Switch2 (Switch2 hidden in 1-gang mode)
- Retry logic on write: attempts up to 5 times with 1s delay (status updated during retries)
- Status label and simple failure dialog on final failure

How to run
1. Install Flutter SDK: https://flutter.dev
2. From this folder, run:
   flutter pub get
   flutter run -d <android-device>

Android permissions
- Add the following permissions to `android/app/src/main/AndroidManifest.xml` inside `<manifest>`:

  <!-- Bluetooth runtime permissions -->
  <uses-permission android:name="android.permission.BLUETOOTH"/>
  <uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
  <uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
  <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>

- On Android 12+ you must request BLUETOOTH_SCAN and BLUETOOTH_CONNECT at runtime. The app requests permissions using `permission_handler` plugin.

Notes
- The app uses the same service UUID and characteristic UUID as the desktop library (from PySwitcherIO):
  - Service: 0000150b-0000-1000-8000-00805f9b34fb
  - Characteristic: 000015ba-0000-1000-8000-00805f9b34fb
- BLE behavior may vary by device and Android version. Test on a real Android device.

CI (GitHub Actions)
- I added a GitHub Actions workflow at `.github/workflows/build_apk.yml` that builds debug and release APKs and uploads them as workflow artifacts.
- To run it: push this repository to GitHub (main branch) and either push a commit or use the "Run workflow" button in Actions -> Workflows -> Build Flutter APK.
- Artifacts will be available in the workflow run summary.

Local build notes
- If you prefer to build locally, install Flutter and Android SDK on your machine and ensure `flutter` is in PATH and Android licenses accepted.
- Then from `android/flutter_app` run `build_local.bat` (Windows) or `flutter build apk --debug` / `flutter build apk --release`.

Signing release APK
- For a proper signed release APK, create a `key.properties` in `android/flutter_app/android/` with your keystore credentials (see `key.properties.sample`).
- Then follow Flutter docs to configure `android/app/build.gradle` signingConfigs, or run `flutter build apk --release` after configuring.

Let me know if you want me to:
- Add automated signing using GitHub Secrets (upload your keystore securely to repository secrets and configure the workflow to sign the APK), or
- Generate a debug-signed test APK in CI and attach it to a GitHub release automatically.
