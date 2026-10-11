# 자산별 설치 SW 인벤토리 명세 (계획)

> 상태: **미구현 — 계획 확정** (2026-10-11 개정)
> 결정됨: ① 대상 플랫폼 = **Windows · macOS · Linux · Android** (iOS/iPadOS 제외, §2.5) ② 1차 목표 = **자산 상세에서 자산별 설치 SW 조회**
> 결정 대기: 전사 집계 화면 착수 시점(§6 3단계)

자산마다 설치된 소프트웨어의 **이름 · 제조사 · 버전 · 설치일자**를 모아 자산 상세에서 보여 주는 기능.

---

## 1. 전제와 제약

| 항목 | 내용 |
|------|------|
| 에이전트 업로드 | 현재 서버가 에이전트 RPC 실행 권한을 회수한 상태(`Agent/README.md` §15, 보안 실행서 §4). **에이전트 자동 수집은 기기별 신원 재도입 이후에만 가능**하다. |
| 그래서 | 1단계는 에이전트 없이 **관리자가 수집 스크립트 결과 파일을 가져오는 방식**으로 시작하고, 에이전트 자동 수집은 2단계로 둔다. 두 경로 모두 같은 데이터 형식(§3)과 같은 테이블(§4)을 쓴다. |
| 보안 원칙 | 익명 접근 없음, 조회는 관리자 그룹 + 해당 자산 담당자, 쓰기는 RPC 경유만 (루트 `CLAUDE.md`, 백엔드 README §5) |
| 데이터 보존 | 자산·출처별 **최신 스냅샷만 보관**(수집할 때마다 교체). 이력이 필요해지면 별도 결정 |

---

## 2. 플랫폼별 수집 방법

| 플랫폼 | 수집 경로 | 이름 | 제조사 | 버전 | 설치일자 | 1단계(스크립트) | 2단계(에이전트) |
|---|---|---|---|---|---|---|---|
| Windows | 레지스트리 Uninstall 키 + Appx | ✅ | ✅ | ✅ | ✅ (대부분) | ✅ PowerShell | ✅ 기존 Windows 에이전트에 추가 |
| macOS | `system_profiler` + `pkgutil` (+ Homebrew) | ✅ | △ | ✅ | △ 앱은 근사값 | ✅ zsh/bash | ✅ 기존 macOS 에이전트에 추가 |
| Linux | `dpkg` / `rpm` + `snap` / `flatpak` | ✅ | △ | ✅ | ✅ rpm / △ dpkg | ✅ bash | ⏳ Linux 에이전트 신규 필요 |
| Android | `PackageManager` | ✅ | △ | ✅ | ✅ | △ adb 스크립트(선택) | ✅ 기존 Android 에이전트에 추가 |

✅ 정확 · △ 근사/대체값 · ✕ 불가

### 2.1 Windows

```powershell
$keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
Get-ItemProperty $keys -ErrorAction SilentlyContinue |
  Where-Object { $_.DisplayName -and -not $_.SystemComponent -and -not $_.ParentKeyName } |
  Select-Object DisplayName, Publisher, DisplayVersion, InstallDate, PSChildName
# Store/UWP 앱 (관리자 권한이면 -AllUsers)
Get-AppxPackage | Select-Object Name, Publisher, Version, InstallLocation
```

- 제어판 "프로그램 추가/제거"와 같은 목록. `SystemComponent=1`·`ParentKeyName`(업데이트 항목)은 제외.
- `InstallDate`는 `YYYYMMDD` 문자열, 없는 항목은 NULL.
- `Win32_Product`(WMI)는 느리고 MSI 재구성 부작용이 있어 **사용 금지**.
- `source`: 레지스트리 = `registry`, Appx = `appx`. `package_id`: 레지스트리 키 이름(`PSChildName`) / Appx `Name`.

### 2.2 macOS

```bash
system_profiler -json SPApplicationsDataType   # .app 번들: 이름·버전·출처·서명 주체·수정일
pkgutil --pkgs                                 # 설치 패키지(receipt) 목록
pkgutil --pkg-info <pkg-id>                    # version, install-time(epoch)
brew list --versions 2>/dev/null               # Homebrew 사용 기기만 (선택)
```

- 앱 번들은 설치일 대신 수정일만 있어 `install_date`는 근사값으로 표시. 정확한 설치일은 `pkgutil` receipt의 `install-time`.
- 제조사는 서명 주체(Developer ID)나 출처(App Store / 확인된 개발자) 문자열로 대체.
- ⚠️ `system_profiler` JSON 필드명은 macOS 버전마다 다를 수 있어 **실기기에서 확인 후 확정**(구현 1단계 작업 항목).
- `source`: `app_bundle` / `pkg` / `homebrew`. `package_id`: 번들 ID / pkg ID / formula 이름.

### 2.3 Linux (Debian/Ubuntu · RHEL/Fedora 계열)

```bash
# Debian 계열
dpkg-query -W -f='${Package}\t${Version}\t${Maintainer}\n'
#   설치일: /var/lib/dpkg/info/<패키지>.list 의 수정 시각(근사)
# RHEL 계열
rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\t%{VENDOR}\t%{INSTALLTIME}\n'   # 설치일 정확(epoch)
# 공통(있을 때만)
snap list
flatpak list --app --columns=application,version,origin
```

- 패키지 관리자는 실행 가능한 명령을 감지해 선택한다.
- 제조사: rpm `VENDOR` / dpkg `Maintainer`(관리자 정보라 제조사와 다를 수 있음).
- 서버급 기기는 패키지가 수천 개라 라이브러리 패키지가 섞인다 → 그대로 보관하고 화면에서 검색으로 찾는다.
- `source`: `dpkg` / `rpm` / `snap` / `flatpak`.
- 2단계를 하려면 Linux 에이전트를 새로 만들어야 한다(현재 Android·Windows·macOS만 있음). KMP `desktopMain` 수집기를 재사용하고 systemd 서비스로 실행.

### 2.4 Android

- `PackageManager.getInstalledPackages()` → 앱 라벨, `packageName`, `versionName`, `firstInstallTime`, `lastUpdateTime`, 설치 출처(`getInstallSourceInfo`, API 30+), `FLAG_SYSTEM`.
- Android 11(API 30)+ 은 패키지 가시성 제한으로 **`QUERY_ALL_PACKAGES` 권한이 필요**하다. Google Play 배포 앱은 이 권한 사용에 심사가 필요하지만, OA Agent는 사내 APK 배포라 매니페스트 선언으로 충분하다.
- 제조사: 별도 필드가 없어 패키지명·설치 출처(예: `com.android.vending`)로 대체.
- 1단계 대안(선택): IT 담당자가 adb로 `pm list packages --show-versioncode`와 `dumpsys package <패키지>`(설치 시각)를 수집하는 스크립트.
- `source`: `android_pm`. `is_system`: `FLAG_SYSTEM` — 화면에서 기본 숨김.

### 2.5 제외: iOS / iPadOS

- 범위에서 제외한다(2026-10-12 결정). iOS 앱은 샌드박스 때문에 다른 설치 앱 목록을 조회할 수 없어 MDM 없이는 수집 수단이 없다.
- iPhone·iPad 자산의 "설치 SW" 섹션은 비어 있게 두고, 필요해지면 별도로 검토한다.

---

## 3. 공통 데이터 형식 (스크립트 출력 = 에이전트 업로드)

```json
{
  "asset_uid": "D00001",
  "platform": "windows",
  "source": "registry",
  "collected_at": "2026-10-11T09:00:00Z",
  "collector": "oa-sw-script/1.0",
  "items": [
    {
      "name": "Google Chrome",
      "publisher": "Google LLC",
      "version": "130.0.6723.70",
      "install_date": "2026-09-30",
      "package_id": "Google Chrome",
      "is_system": false
    }
  ]
}
```

| 필드 | 규칙 |
|------|------|
| `platform` | `windows` · `macos` · `linux` · `android` |
| `source` | `registry` · `appx` · `app_bundle` · `pkg` · `homebrew` · `dpkg` · `rpm` · `snap` · `flatpak` · `android_pm` · `manual` |
| `install_date` | `YYYY-MM-DD` 또는 `null` (근사값이면 그대로 넣고 화면에서 출처로 구분) |
| `items` | 파일당 최대 5,000건, 문자열 필드 최대 500자 |

한 파일 = 한 자산 · 한 출처. 업로드하면 그 자산의 같은 출처 데이터를 통째로 교체한다.

---

## 4. DB 설계

```sql
CREATE TABLE public.asset_software (
  id            bigserial PRIMARY KEY,
  asset_id      bigint NOT NULL REFERENCES public.assets(id) ON DELETE CASCADE,
  platform      text NOT NULL CHECK (platform IN ('windows','macos','linux','android')),
  source        text NOT NULL CHECK (source IN ('registry','appx','app_bundle','pkg','homebrew',
                                                'dpkg','rpm','snap','flatpak','android_pm','manual')),
  name          text NOT NULL,
  publisher     text,
  version       text,
  install_date  date,
  package_id    text,
  is_system     boolean NOT NULL DEFAULT false,
  collected_at  timestamptz NOT NULL,
  collected_by  text NOT NULL CHECK (collected_by IN ('import','agent')),
  UNIQUE (asset_id, source, package_id, version)
);
CREATE INDEX ON public.asset_software (asset_id);
CREATE INDEX ON public.asset_software USING gin (name gin_trgm_ops);   -- 이름 검색 (pg_trgm 이미 사용 중)
```

- 자산 연결은 `asset_uid` 문자열이 아니라 `assets.id` FK — 자산 삭제 시 함께 삭제, 자산번호 변경에 안전.
- 수집 시각은 `max(collected_at)`으로 계산(별도 스냅샷 테이블 없음).

### 4.1 쓰기 RPC

```sql
public.replace_asset_software(p_payload jsonb) RETURNS jsonb   -- SECURITY DEFINER
```

1. 권한: **1단계 = 관리자 그룹만**. 2단계에 기기별 신원 검증을 추가(§15 매핑된 자산만).
2. `asset_uid`로 자산 확인, `platform`/`source`/건수·길이 검증.
3. 한 트랜잭션에서 `DELETE … WHERE asset_id = ? AND source = ?` 후 `INSERT`.
4. 반환: `{asset_uid, source, inserted, collected_at}`.

### 4.2 권한 (보안 실행서 기준)

- RLS 활성. SELECT = `is_admin_group()` OR 해당 자산 담당자(`assets.user_id = current_user_id()`).
- INSERT/UPDATE/DELETE 정책 없음 → 쓰기는 RPC만.
- `auth_banned_account_block` · `legacy_agent_block` RESTRICTIVE 정책 추가.
- 기본 ACL이 회수돼 있으므로 `GRANT SELECT ON asset_software TO authenticated`, `GRANT EXECUTE ON FUNCTION replace_asset_software(jsonb) TO authenticated`를 **명시**.
- 함수는 `SET search_path = pg_catalog, public, auth, pg_temp`.

---

## 5. 화면 (Flutter)

| 위치 | 내용 |
|------|------|
| 자산 상세 → **"설치 SW" 섹션** | 목록(이름 · 제조사 · 버전 · 설치일 · 출처), 이름/제조사 검색, 마지막 수집 시각, 시스템 앱 숨김 토글(Android 기본 숨김) |
| 자산 상세 → **"SW 목록 가져오기"** (관리자 그룹) | §3 JSON 파일 선택 → 미리보기(건수·출처) → `replace_asset_software` 호출 |
| (3단계, 선택) 전사 집계 | SW 이름별 설치 대수 · 버전 분포 — 라이선스 관리용 |

---

## 6. 구현 단계

| 단계 | 내용 | 선행 조건 |
|------|------|-----------|
| **1단계** (에이전트 불필요) | ① 마이그레이션(테이블·RPC·RLS·GRANT) ② 수집 스크립트 `tools/sw-inventory/` — Windows(PowerShell)·macOS·Linux(bash), Android adb(선택) ③ 자산 상세 "설치 SW" 섹션 + 가져오기 ④ macOS `system_profiler` 필드 실기기 확정 | 없음 |
| **2단계** (자동 수집) | Windows·macOS·Android 에이전트에 `SoftwareInventoryCollector`(KMP expect/actual) 추가, **하루 1회** 업로드(heartbeat와 분리), Linux 에이전트 신규 | 에이전트 기기별 신원 재도입(`Agent/README.md` §15) |
| **3단계** (선택) | 전사 집계 화면 | 1단계 데이터 축적 |

---

## 관련 문서/코드

- 에이전트 시스템 정보 수집: `Agent/shared/src/*/SystemInfoCollector.kt` (`desktopMain`이 Windows·macOS 공용, SystemInfo 26개 항목)
- 에이전트 재도입 설계: `Agent/README.md` §15 · 보안 기준: `OA_backend/SECURITY_HARDENING_RUNBOOK.md`
- 권한·마이그레이션 규칙: `OA_backend/CLAUDE.md`
- OS 업데이트 확인 기준: `/home/kminer/docker-workdir/OS_업데이트_확인방법.docx` (저장소 밖, 작업 폴더 루트)
