# 설치 SW 인벤토리 수집 명세 (계획)

> 상태: **미구현 — 설계 확정 대기** (2026-10-11 작성)
> 결정 대기: ① 대상 플랫폼 범위(Windows만 / 전부) ② 전사 집계 화면 포함 여부

에이전트가 설치된 디바이스의 **설치 소프트웨어 목록(이름·제조사·버전·설치일자)** 을
수집해 서버로 올리고, 자산 상세에서 조회하는 기능.

---

## 1. 플랫폼별 수집 방법

| 플랫폼 | 수집 방법 | 이름 | 제조사 | 버전 | 설치일자 |
|---|---|---|---|---|---|
| Windows | 레지스트리 Uninstall 키 (PowerShell) | ✅ DisplayName | ✅ Publisher | ✅ DisplayVersion | ✅ InstallDate |
| macOS | `system_profiler SPApplicationsDataType -json` | ✅ | △ 서명 주체/출처 | ✅ | △ 수정일로 대체 |
| Android | `PackageManager.getInstalledPackages()` | ✅ 앱 라벨 | △ 패키지명·설치 출처 | ✅ versionName | ✅ firstInstallTime / lastUpdateTime |

### Windows 수집 명령 (기준)

```powershell
Get-ItemProperty `
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' |
  Where-Object { $_.DisplayName } |
  Select-Object DisplayName, Publisher, DisplayVersion, InstallDate |
  ConvertTo-Json -Compress
```

- `Win32_Product`(WMI)는 느리고 MSI 재구성 부작용이 있어 **사용 금지**
- 제어판 "프로그램 추가/제거"와 동일한 목록. PC당 보통 100~300건

---

## 2. DB 설계

```sql
CREATE TABLE public.device_software (
  id           bigserial PRIMARY KEY,
  asset_uid    text NOT NULL,            -- assets.asset_uid 참조 (텍스트 — 에이전트 키)
  name         text NOT NULL,            -- SW 이름
  publisher    text,                     -- 제조사
  version      text,
  install_date date,                     -- 알 수 없으면 NULL
  collected_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (asset_uid, name, version)
);
CREATE INDEX ON public.device_software (asset_uid);
CREATE INDEX ON public.device_software (name);
```

- 업로드 방식: **전체 교체** — 에이전트가 수집할 때마다 해당 asset_uid 행 전부 삭제 후 삽입
  (SECURITY DEFINER RPC `upload_software_inventory(asset_uid, jsonb)` 안에서 트랜잭션 처리)
- RLS: SELECT는 admin_group, 쓰기는 RPC 경유만 (에이전트 토큰 검증)

## 3. 에이전트 (KMP)

- `shared/` 에 `SoftwareInventoryCollector` expect/actual 추가
  - desktopMain: PowerShell(위 명령) / macOS system_profiler
  - androidMain: PackageManager
- 수집 주기: **하루 1회** (heartbeat 와 분리 — 목록이 커서 매 heartbeat 전송 금지)
- 전송: Supabase RPC `upload_software_inventory`

## 4. 프론트 (Flutter)

- 자산 상세 → "설치 SW" 섹션: 목록(이름/제조사/버전/설치일) + 이름·제조사 검색, 수집 시각 표시
- (선택) 전사 집계 화면: SW 이름별 설치 대수 — 라이선스 관리용
  `SELECT name, count(DISTINCT asset_uid) FROM device_software GROUP BY name`

## 5. 구현 순서 (착수 시)

1. 마이그레이션 (device_software + RPC + RLS)
2. Agent desktopMain(Windows) 수집기 → RPC 업로드 → exe 재배포
3. 자산 상세 "설치 SW" 섹션
4. Android 수집기 → APK 재배포
5. (선택) 전사 집계 화면

## 관련 문서/코드

- 에이전트 시스템 정보 수집: `Agent/shared/src/*/SystemInfoCollector.kt`
- 에이전트 README: `Agent/README.md` (SystemInfo 26개 항목)
- OS 업데이트 확인 기준: 루트 `OS_업데이트_확인방법.docx` 참고
