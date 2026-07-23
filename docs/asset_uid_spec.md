# 자산번호(`asset_uid`) 규격

이 문서는 `assets.asset_uid` 컬럼의 형식/검증 규칙을 정리한다.
DB 검증 로직은 `OA_backend/supabase/migrations/` 하위의 `*_asset_uid_*.sql`
마이그레이션이 소스 오브 트루스(SoT)이며, 이 문서는 요약과 폐기된 규격 보존이 목적이다.

---

## 1. 현재기준 (2026-06 이후 유일하게 유효)

- 정규식: `^[A-Z]{1,2}[0-9]{4,5}$`
- 규칙: **영문 대문자 1~2자리 + 숫자 4~5자리** (총 5~7자리)
- 예시: `D00001`, `N00042`, `TP0012`, `EH0003`

### 코드 표

| 코드 | 설명 | 예시 |
|---|---|---|
| D | 데스크탑 | D00001 |
| N | 노트북 | N00001 |
| T | 태블릿 | T00001 |
| M | 모니터 | M00001 |
| S | 스캐너 | S00001 |
| P | 프린터 | P00001 |
| C | IP전화기 | C00001 |
| TP | 테스트폰 | TP0001 |
| EH | 법인폰 | EH0001 |
| ET | 현장업무 태블릿 | ET0001 |

앱 내 안내는 `OA_frontend/oa_app/lib/widgets/common/asset_uid_guide_dialog.dart`
에서 사용자에게 노출된다.

---

## 2. 변경후 (계획됐다 폐기됨 — 2026-06-14 이후 저장 불가)

한때 두 형식을 병기하는 마이그레이션이 있었으나
`20260614000003_drop_new_uid_format.sql`에서 DB 전수 조사 결과 0건이라
**"변경후" 규격을 정규식에서 제거**했다. 여기 남기는 것은 향후 재도입 검토를
할 때 규칙을 다시 만들지 않기 위함이다.

- 정규식(폐기): `(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|TP|ET|EH)[0-9]{5}`
- 규칙: **등록경로(1) + 장비코드(2) + 일련번호(5)** = 총 8자리

### 등록경로 (1자리)

| 코드 | 의미 |
|---|---|
| B | 구매(Buy) |
| R | 임대(Rental) |
| C | 도급(Contract) |
| L | 대여(Lease) |
| S | 지원(Support) |

### 장비코드 (2자리)

| 코드 | 장비 |
|---|---|
| DT | 데스크탑 |
| NB | 노트북 |
| MN | 모니터 |
| PR | 프린터 |
| TB | 태블릿 |
| SC | 스캐너 |
| IP | IP전화기 |
| NW | 네트워크 장비 |
| SV | 서버 |
| WR | 무선 라우터 |
| SD | 스토리지 |
| TP | 테스트폰 |
| ET | 현장업무 태블릿 |
| EH | 법인폰 |

### 예시

- `BDT00001` — 구매·데스크탑 1호
- `STP22222` — 지원·테스트폰 22222호
- `RNB00042` — 임대·노트북 42호

---

## 관련 마이그레이션

| 파일 | 내용 |
|---|---|
| `20260211000001_asset_uid_format_alignment.sql` | 옛 형식 + 변경후 규격 병기 시작 |
| `20260614000003_drop_new_uid_format.sql` | 변경후 규격 폐기, 옛 형식만 유효 |

## 관련 코드

- 클라이언트 검증: `OA_frontend/oa_app/lib/constants.dart` `assetUidRegex`
- 사용자 안내 다이얼로그: `OA_frontend/oa_app/lib/widgets/common/asset_uid_guide_dialog.dart`
- DB 트리거: `public.validate_asset_uid()` (assets 테이블 BEFORE INSERT/UPDATE)
