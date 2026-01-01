# I/O 스위처 로컬 (Flutter)

Android용 PySwitcherIO 기기 제어 앱입니다.

## 주요 기능

### 앱 기능
- MAC 주소, 기기 유형(1구/2구), 반전 설정을 SharedPreferences에 저장
- 기기 찾기: "SWITCHER_M" 이름을 가진 BLE 기기 검색 및 목록 표시 (복사/사용 버튼)
- 스위치 제어: Switch1 및 Switch2 각각 독립적인 ON/OFF 버튼 (1구 모드에서는 Switch2 숨김)
- 재시도 로직: 최대 5회 재시도 (1초 간격), 재시도 중 상태 업데이트
- 세련된 Material 3 UI: Card 기반 레이아웃, 색상별 버튼, 상태 표시

### 홈 스크린 위젯 ✨ NEW
- **2x1 소형 위젯**: 1구 스위처용 (Switch1 ON/OFF)
- **4x1 대형 위젯**: 2구 스위처용 (Switch1/2 ON/OFF 전체 버튼)
- 위젯에서 직접 제어 가능 (앱이 백그라운드에서 BLE 명령 전송)
- 현재 앱 설정(MAC, 기기 유형, 반전 옵션) 자동 적용

## 빌드 방법

### 로컬 빌드
1. Flutter SDK 설치: https://flutter.dev
2. 이 폴더에서 실행:
   ```bash
   flutter pub get
   flutter build apk --debug
   ```

### CI/CD (GitHub Actions)
- `.github/workflows/build_apk.yml` 워크플로우가 debug/release APK 자동 빌드
- GitHub에 푸시하면 자동으로 빌드되어 Artifacts에 업로드됨

## 위젯 사용 방법

1. 앱 설치 후 먼저 앱을 실행하여 MAC 주소와 설정을 저장하세요
2. 홈 화면 길게 누르기 → 위젯 추가
3. "I/O 스위처 로컬" 위젯 선택
   - **소형 (2x1)**: 1구 스위처에 적합
   - **대형 (4x1)**: 2구 스위처에 적합
4. 위젯 버튼을 눌러 즉시 스위치 제어

## Android 권한

AndroidManifest.xml에 다음 권한이 자동으로 포함됩니다:
- `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` (Android 12+)
- `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`
- 앱 실행 시 `permission_handler` 플러그인이 런타임 권한 요청

## 기술 스펙

- **BLE 프로토콜** (PySwitcherIO 호환):
  - Service UUID: `0000150b-0000-1000-8000-00805f9b34fb`
  - Characteristic UUID: `000015ba-0000-1000-8000-00805f9b34fb`
- **패키지**:
  - `flutter_reactive_ble`: BLE 통신
  - `shared_preferences`: 설정 저장
  - `permission_handler`: 권한 관리
  - `home_widget`: 홈 스크린 위젯 (네이티브 Android 위젯)

## 주의사항

- 실제 Android 기기에서 테스트 필요 (에뮬레이터는 BLE 미지원)
- Android 버전 및 기기에 따라 BLE 동작이 다를 수 있음
- 위젯 사용 전 반드시 앱에서 먼저 MAC 주소 설정 필요

## 릴리즈 APK 서명

`android/key.properties` 파일 생성 (key.properties.sample 참조):
```properties
storePassword=your-password
keyPassword=your-password
keyAlias=your-key-alias
storeFile=path/to/keystore.jks
```

그 후:
```bash
flutter build apk --release
```
- Add automated signing using GitHub Secrets (upload your keystore securely to repository secrets and configure the workflow to sign the APK), or
- Generate a debug-signed test APK in CI and attach it to a GitHub release automatically.
