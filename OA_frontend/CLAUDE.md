# OA_frontend — Claude Code 가이드

상세 명세: `OA_frontend/README.md` · 문서 인덱스: 루트 `CLAUDE.md`

앱 루트는 `oa_app/` (Flutter 3.41.2 / Dart 3.11). 검사: `cd oa_app && flutter analyze` (오류 0 유지, 기존 경고는 미사용 코드).

## 작업 규칙

- 데이터 접근은 `lib/services/api_service.dart` 경유. 권한은 서버 RLS가 최종 판단하므로 UI 숨김만으로 보안을 대신하지 않는다.
- 관리자 그룹 판별은 `User.isAdminGroup`, admin은 `role == 'admin'`, 마스터는 `isMasterAdmin`.
- Storage 업로드 경로는 `'$authUid/$round/…'` — 첫 폴더가 Auth UUID가 아니면 RLS가 거부한다.
- 파일 URL은 `createSignedUrl` (모든 버킷 private, `getPublicUrl` 금지).
- Realtime 채널은 `RealtimeChannelConfig(private: true)`. 프론트가 쓰는 토픽은 `assets-realtime`, `inspections-realtime`, `agent-presence:global`, `agent-alerts:global`, `agent-commands:{uid}`만 허용된다.
- 자산번호 정규식은 `lib/constants.dart` `assetUidRegex` 한 곳 (QR 스캔·자산 등록 공용). 바꾸면 DB와 `docs/asset_uid_spec.md`도 같이.
- 메뉴 노출은 `menu_permissions`(`menu_visibility_provider.dart`)로 추가 제한된다.
- 배포 후에만 반영됨 — 코드 변경은 `oa-frontend` 재빌드 전까지 운영에 없다.
