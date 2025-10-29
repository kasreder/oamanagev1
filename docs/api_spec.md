# API 명세

> 향후 실 서버 연동을 위해 RESTful 인터페이스를 정의한다. 모든 응답은 `application/json`이며, 시간은 ISO-8601(UTC) 문자열을 사용한다.

## 인증
- **방식**: JWT Bearer 토큰
- **엔드포인트**: `POST /auth/token`
  - 요청: `{ "username": "...", "password": "..." }`
  - 응답: `{ "access_token": "jwt", "expires_in": 3600 }`
- 모든 보호된 엔드포인트는 `Authorization: Bearer <token>` 헤더 필요.

## 자산
### GET /assets
- **설명**: 자산 목록 조회.
- **쿼리**
  - `q`: 전체 텍스트 검색(UID/이름/모델 등)
  - `status`: 상태 필터(`사용`, `가용`, ...)
  - `team`: 조직/팀 필터
  - `page`, `pageSize`
- **응답**
```json
{
  "items": [
    {
      "uid": "OA-001",
      "name": "홍길동",
      "assetType": "노트북",
      "modelName": "Gram 15",
      "serialNumber": "SN123",
      "status": "사용",
      "location": "본사 A동 3F",
      "organization": "정보보안팀",
      "metadata": {
        "os": "Windows 11",
        "network": "내부",
        "memo": "교체 예정"
      },
      "owner": {
        "id": 101,
        "name": "홍길동"
      },
      "barcodePhotoUrl": "https://.../barcode/OA-001.jpg"
    }
  ],
  "page": 0,
  "pageSize": 20,
  "total": 240
}
```

### GET /assets/{uid}
- **설명**: 단일 자산 상세.
- **응답**: 위 항목과 동일 + `history` 배열(최근 실사 요약).

### POST /assets
- **설명**: 자산 등록/수정(UPSERT).
- **요청 본문**
```json
{
  "uid": "OA-001",
  "name": "홍길동",
  "assetType": "노트북",
  "status": "사용",
  "modelName": "Gram 15",
  "serialNumber": "SN123",
  "vendor": "LG",
  "location": "본사 A동 3F",
  "organization": "정보보안팀",
  "metadata": { "os": "Windows 11", "memo": "교체 예정" }
}
```
- **응답**: `{ "uid": "OA-001", "created": false }` (`created=true`일 경우 신규).

### DELETE /assets/{uid}
- **설명**: 자산 비활성화. 실제 삭제 대신 `status="폐기"`로 마킹.

## 실사(Inspections)
### GET /inspections
- **쿼리**: `assetUid`, `synced=false`, `from`, `to`, `page`, `pageSize`.
- **응답 항목**
```json
{
  "id": "ins_OA-001_1700000000",
  "assetUid": "OA-001",
  "status": "사용",
  "memo": "점검 완료",
  "scannedAt": "2024-02-01T09:12:00Z",
  "synced": false,
  "userTeam": "정보보안팀",
  "user": {
    "id": 101,
    "name": "홍길동"
  },
  "assetType": "노트북",
  "verified": true,
  "barcodePhotoUrl": "https://.../barcode/OA-001.jpg"
}
```

### POST /inspections
- **설명**: 실사 결과 업로드.
- **요청**: 위 응답과 동일 구조(필수: `assetUid`, `status`, `scannedAt`).
- **응답**: `{ "id": "...", "synced": true }`.

### PATCH /inspections/{id}
- **설명**: 실사 메모/상태 업데이트.
- **요청**: `{ "status": "가용(창고)", "memo": "이동 예정", "synced": false }`

### DELETE /inspections/{id}
- **설명**: 실사 기록 삭제. 감사 로그 남김.

## 인증 & 서명
### GET /verifications
- **설명**: 자산 인증 상태 목록. 자산/사용자/팀 필터 지원.
- **응답 항목**
```json
{
  "assetUid": "OA-001",
  "team": "정보보안팀",
  "user": { "id": 101, "name": "홍길동" },
  "assetType": "노트북",
  "barcodePhoto": true,
  "signature": true,
  "latestInspection": {
    "scannedAt": "2024-02-01T09:12:00Z",
    "status": "사용"
  }
}
```

### GET /verifications/{assetUid}
- **설명**: 단일 자산 인증 상세. 서명/사진 메타, 최근 실사, 자산 정보 포함.

### POST /verifications/{assetUid}/signatures
- **설명**: 서명 업로드.
- **요청**: `multipart/form-data`
  - `file`: PNG 이미지
  - `userId`, `userName`
- **응답**: `{ "signatureId": 303, "storageLocation": "https://.../signatures/303.png" }`

### GET /verifications/{assetUid}/signatures
- **설명**: 서명 이미지 다운로드(바이너리) 혹은 presigned URL 반환.

### POST /verifications/batch
- **설명**: 그룹 자산의 서명/사진 상태 일괄 갱신.
- **요청**
```json
{
  "assetUids": ["OA-001", "OA-002"],
  "signatureId": 303,
  "applyToAll": true
}
```

## 보조 서비스
### GET /references/users
- **설명**: 자동 완성을 위한 사용자 검색.
- **쿼리**: `q`, `team`

### GET /references/assets
- **설명**: UID 자동 완성. `q` 파라미터 사용.

### GET /health
- **설명**: 헬스 체크. `{ "status": "ok", "time": "..." }`

## 실 DB 전환 시 연동 흐름
- **초기 동기화**: 앱이 기동하면 `/auth/token`으로 인증 후 `/assets`, `/inspections`, `/references/users`를 호출하여 실제 DB에 저장된 데이터를 모두 내려받는다. 이때 API는 `updatedAt` 기준 증분 싱크를 지원해야 한다.
- **쓰기 경로**: `/assets`, `/inspections`, `/verifications` 계열 엔드포인트는 각각 `assets`, `inspections`, `signatures` 테이블에 직접 반영되며, 트랜잭션으로 감사 로그 테이블(예: `audit_logs`)에 기록한다.
- **오프라인 큐 처리**: 앱이 오프라인에서 생성한 요청은 네트워크 복구 시 순차적으로 API를 호출하여 처리하고, 서버는 `synced` 필드를 true로 업데이트하는 PATCH 응답을 반환한다.
- **테스트/스테이징**: 더미 JSON 제거 이후 QA 환경은 스테이징 DB를 사용하고, 초기화는 `/admin/seed` 같은 관리용 엔드포인트로 수행한다. 프로덕션에서는 해당 엔드포인트를 비활성화한다.
## 오류 응답 규약
- HTTP 400: `{"error": "INVALID_INPUT", "message": "..."}`
- HTTP 401: `{"error": "UNAUTHORIZED"}`
- HTTP 404: `{"error": "NOT_FOUND", "resource": "asset", "id": "OA-999"}`
- HTTP 409: `{"error": "CONFLICT", "message": "이미 등록된 UID"}`
- HTTP 500: `{"error": "INTERNAL_ERROR", "traceId": "..."}`

## 성능 및 보안 메모
- 응답에 `ETag` 헤더를 포함하여 캐싱 지원.
- `/verifications` 계열은 대량 조회가 많으므로 cursor 기반 페이지네이션 권장.
- 서명 업로드는 최대 5MB, 서버에서 PNG 재인코딩 후 저장.
- JWT 만료 1시간, refresh 토큰 별도(`POST /auth/refresh`).
- 모든 쓰기 요청은 감사 로그(`userId`, `ip`, `userAgent`) 기록.
