# OA Manage v1

OA 자산 실사 관리 앱입니다. 에셋 JSON을 로드하여 실사 목록을 관리하고, QR 스캔으로 신규 실사를 생성합니다.

## 주요 기능
- 홈/스캔/실사 목록/미검증 자산 화면 제공
- 모바일/웹 카메라 권한 안내 및 QR 스캔 처리
- 실사 상세 편집, 삭제, 미동기화 필터링
- Material 3 및 반응형 NavigationBar/NavigationRail 적용

## 더미 데이터
에셋 JSON은 `assets/mock` 아래에 위치하며, `pubspec.yaml`에 등록되어 있습니다.
```
assets/mock/users.json
assets/mock/assets.json
assets/mock/asset_inspections.json
```

## 개발 환경
- Flutter 3.22.x 이상 (Dart 3.7)
- 주요 패키지: provider, go_router, mobile_scanner, permission_handler

## 실행 방법
1. 의존성 설치
   ```bash
   flutter pub get
   ```
2. 앱 실행 (예: Android 에뮬레이터 또는 Chrome)
   ```bash
   flutter run
   ```

## 권한 안내
- 모바일 기기에서 카메라 권한이 필요합니다. 권한을 거부하면 스캔 화면에서 설정으로 이동하는 버튼이 노출됩니다.
- 웹에서는 HTTPS 환경에서만 카메라 사용이 가능하며, 브라우저 권한 허용이 필요합니다.

## 테스트 플로우
1. 홈에서 "QR 코드 촬영" 버튼 또는 하단 버튼을 눌러 스캔 화면으로 이동합니다.
2. QR 코드를 스캔하면 신규 실사가 생성되고 상세 화면으로 이동합니다.
3. 상태/메모를 수정 후 저장합니다.
4. 실사 목록에서 미동기화 필터 토글을 확인합니다.

## 향후 작업(TODO)
- 동기화 API 연동 및 미동기화 전송 큐
- 로컬 영속화(Hive/Sqflite) 지원
- 카메라 라이트 토글/전면 카메라 전환
- 실사 검색(자산 UID/메모)
