# OA Manager v1 - 에이전트 명세서

## ⚠️ 중요 사항
> **본 문서는 OA 자산관리 시스템의 에이전트(기기 모니터링) 개발 명세서입니다.**
> **백엔드 명세서(`OA_backend/README.md`)의 DB 스키마 및 RPC 함수와 반드시 동기화하여 관리합니다.**
> **프론트엔드 명세서(`OA_frontend/README.md`)의 접속현황 인디케이터 로직을 참조합니다.**
> **Heartbeat 프로토콜 및 시스템 정보 수집 항목 변경 시 모든 플랫폼 에이전트에 동시 반영이 필요합니다.**

> ⛔ **현재 운영 상태 (2026-08 보안 강화 이후)**
> `OA_backend/SECURITY_HARDENING_RUNBOOK.md`에 따라 공용 에이전트 계정(`employee_id='agent'`)은 차단되었고, `update_heartbeat`·`verify_user`·`confirm_assignment` RPC는 `authenticated` 실행 권한이 회수된 상태입니다. **기기별 신원·자산 매핑(§15 재도입 설계)이 검증되기 전까지 기존 APK와 에이전트의 Heartbeat·사용자 확인·수령 확인은 실패하는 것이 정상입니다.** 서버 권한을 완화해서 우회하지 않습니다.

### 예제 코드 정책 (Example Code Policy)

| 구분 | 구속력 | 설명 |
|------|--------|------|
| Heartbeat 프로토콜 (페이로드 구조, RPC 시그니처) | **고정** | 모든 플랫폼이 동일한 페이로드 구조와 RPC 호출 방식을 준수 |
| 시스템 정보 수집 항목 | **고정** | 수집 항목 목록과 데이터 타입은 반드시 준수 |
| API 엔드포인트 / 인증 방식 | **고정** | Supabase URL, 인증 플로우, 토큰 관리 방식은 반드시 준수 |
| 플랫폼별 내부 구현 | **구현자 재량** | 동일한 입출력을 보장하는 범위 내에서 자유롭게 구현 가능 |

> **원칙**: 각 플랫폼 에이전트는 동일한 Heartbeat 페이로드를 동일한 RPC 함수로 전송해야 합니다.
> 내부 스케줄링, 시스템 정보 수집 API, 보안 저장소 등은 플랫폼 특성에 맞게 구현합니다.

---

## 1. 프로젝트 개요

### 1.1 목적
OA 자산(PC, 노트북, 태블릿, 서버 등)에 설치되어 **실시간 접속 상태** 및 **시스템 모니터링 정보**를 Supabase 백엔드로 주기적 전송하는 경량 에이전트 프로그램 개발

### 1.2 주요 기능
| 기능 | 설명 |
|------|------|
| Heartbeat 전송 | 사용자 설정 주기(5분/15분/30분)로 `last_active_at` 갱신하여 접속 상태 실시간 반영 (⛔ 현재 서버 차단) |
| 시스템 모니터링 | CPU, 메모리, 스토리지, 배터리, 네트워크, 제조사, 모델명, MAC, 보안 패치 등 26개 항목 수집 |
| 서버 알림 수신 | `notifications` INSERT를 Realtime(postgres_changes)으로 수신해 시스템 알림 표시 (FCM 미사용) |
| 사용자 확인 | 서버 설정 주기(기본 30일)마다 사용자 이름+사번 입력 → DB 대조 검증 |
| 자산 수령 확인 | 자산 배정 후 사용자가 이름 입력하여 수령 확인 완료 |
| 에이전트 버전 관리 | 서버에서 최신 버전 비교 → 구버전 시 업데이트 알림 |
| 자동 재시작 | 기기 재부팅, 앱 종료 후에도 자동으로 Heartbeat 재개 |
| 보안 저장 | 인증 토큰, 자산 식별자를 플랫폼별 보안 저장소에 암호화 저장 (비밀번호 미저장) |
| Realtime 연동 | Supabase Realtime private 채널 — Presence 상태 공유, 관리자 명령 수신, 서버 알림 수신 (전역 알림 발신 없음) |
| 오프라인 대응 | 네트워크 단절 시 대기, 복구 시 자동 재전송 |

### 1.3 기술 스택
| 구분 | 기술 |
|------|------|
| 아키텍처 | **Kotlin Multiplatform (KMP)** |
| 공유 모듈 | shared (commonMain + 플랫폼별 actual) |
| HTTP 클라이언트 | **Ktor Client** (OkHttp 엔진 for Android) |
| JSON 직렬화 | **kotlinx.serialization** |
| 비동기 처리 | **Kotlin Coroutines** |
| Android 스케줄링 | **WorkManager** (Jetpack) |
| Android 보안 저장 | **EncryptedSharedPreferences** (AndroidX Security) |
| 백엔드 | **Supabase** (PostgreSQL 17 + PostgREST) |
| 인증 | **Supabase Auth** (JWT, 자산 담당자·관리자 개인 계정) |
| 실시간 통신 | **Supabase Realtime** (Phoenix Channels over WebSocket, private 채널) |
| 알림 | **Supabase Realtime** `notifications` postgres_changes (FCM/Firebase 의존성 없음) |
| Desktop 보안 저장 | Windows DPAPI (`CurrentUser`), macOS Keychain |

### 1.4 시스템 아키텍처
```
┌─────────────────────────────────────────────────────────┐
│              OA 자산 기기 (Agent 설치)                    │
│                                                         │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │ WorkManager  │  │ SystemInfo   │  │ Encrypted     │  │
│  │ (15분 주기)  │→ │ Collector    │  │ Preferences   │  │
│  └──────┬──────┘  └──────┬───────┘  └───────────────┘  │
│         │                │                               │
│         ▼                ▼                               │
│  ┌──────────────────────────────┐  ┌────────────────┐  │
│  │     HeartbeatWorker          │  │ RealtimeManager│  │
│  │  (asset_uid + SystemInfo)    │  │  (WebSocket)   │  │
│  └──────────────┬───────────────┘  └───────┬────────┘  │
└─────────────────┼──────────────────────────┼────────────┘
                  │ HTTPS                    │ WSS
                  ▼                          ▼
┌─────────────────────────────────────────────────────────┐
│              Supabase Backend                            │
│                                                         │
│  ┌──────────┐  ┌──────────────────────┐  ┌──────────┐  │
│  │ Auth     │  │ PostgREST            │  │ Realtime │  │
│  │ (JWT)    │  │ RPC/update_heartbeat │  │(WebSocket│  │
│  └──────────┘  └──────────┬───────────┘  └────┬─────┘  │
│                           │                    │         │
│                           ▼                    │         │
│  ┌──────────────────────────────────────┐     │         │
│  │ PostgreSQL                            │     │         │
│  │ assets.last_active_at = now()         │─────┘         │
│  │ assets.specifications->'device_status'│  PG Changes   │
│  └──────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────┘
                  │                          │
                  │ PostgREST 조회           │ WebSocket
                  ▼                          ▼
┌─────────────────────────────────────────────────────────┐
│              OA Manager 프론트엔드 (Flutter)              │
│  접속현황 인디케이터: 🔵 실시간 / 🟢 접속중 / 🔴 만료   │
│  Realtime: Presence 추적, Broadcast 명령/알림            │
└─────────────────────────────────────────────────────────┘
```

### 1.5 지원 플랫폼
| 플랫폼 | 상태 | 대상 기기 | 비고 |
|--------|------|----------|------|
| **Android** | ✅ 구현 | 태블릿, 테스트폰 | WorkManager 기반 |
| **Windows** | ✅ 구현 | 데스크탑, 노트북 | System Tray + Task Scheduler (Win10/11) |
| **macOS** | ✅ 구현 | 데스크탑, 노트북 | 메뉴바 트레이 + launchd (`--service`), Keychain 저장 |
| iOS | 향후 | iPhone, iPad | Background App Refresh |
| Linux | 향후 | 서버, 데스크탑 | systemd service |

---

## 2. 폴더 구조

### 2.1 전체 디렉토리 트리
```
Agent/
├── README.md                                  ← 본 문서 (공통 명세)
├── BUILDING.md                                ← 빌드 입력값(OA_AGENT_SUPABASE_URL / ANON_KEY) 규칙
├── build.gradle.kts / settings.gradle.kts     ← 모듈: shared, android:app, windows, macos
├── gradle.properties / gradle/wrapper/
├── shared/                                    ← KMP 공유 모듈
│   └── src/
│       ├── commonMain/kotlin/com/oamanager/agent/
│       │   ├── AgentConfig.kt                 ← URL·키(빌드 시 생성값), 주기, 재연결 설정
│       │   ├── model/HeartbeatPayload.kt      ← 3.1
│       │   ├── model/SystemInfo.kt            ← 3.2 (26개 필드)
│       │   ├── network/SupabaseClient.kt      ← Ktor HTTP 클라이언트
│       │   ├── network/AuthManager.kt         ← 개인 계정 토큰 관리
│       │   ├── network/RealtimeManager.kt     ← 14.7 Realtime (Presence/명령/알림)
│       │   └── platform/SystemInfoCollector.kt← expect 선언
│       ├── androidMain/.../platform/SystemInfoCollector.kt
│       └── desktopMain/.../platform/SystemInfoCollector.kt  ← Windows + macOS 공용
├── android/app/src/main/
│   ├── AndroidManifest.xml                    ← 6.2
│   └── java/com/oamanager/agent/android/
│       ├── OAAgentApp.kt                      ← WorkManager/ForegroundService 분기
│       ├── data/AgentPreferences.kt           ← EncryptedSharedPreferences
│       ├── ui/SetupActivity.kt / SetupViewModel.kt / TestActivity.kt
│       ├── worker/HeartbeatWorker.kt
│       ├── service/HeartbeatForegroundService.kt ← Realtime 연결 + admin_alert_channel
│       ├── service/AdminCommandEvents.kt
│       └── receiver/BootReceiver.kt
├── windows/                                   ← Windows 에이전트 (JVM)
│   ├── src/main/kotlin/com/oamanager/agent/windows/
│   │   ├── Main.kt / WindowsAgentApp.kt
│   │   ├── ui/TrayIconManager.kt / SetupDialog.kt / VerificationDialog.kt
│   │   ├── service/HeartbeatScheduler.kt / WindowsServiceInstaller.kt
│   │   └── data/WindowsPreferences.kt         ← DPAPI(CurrentUser) 저장소
│   └── install/install.bat / uninstall.bat
└── macos/                                     ← macOS 에이전트 (JVM)
    ├── src/main/kotlin/com/oamanager/agent/macos/
    │   ├── Main.kt / MacAgentApp.kt           ← 트레이 모드 / `--service`(launchd)
    │   ├── ui/TrayIconManager.kt
    │   ├── service/HeartbeatScheduler.kt
    │   └── data/MacPreferences.kt             ← Keychain generic-password
    └── install/install.sh / uninstall.sh
```

> FCM 관련 코드(`fcm/OAFirebaseMessagingService.kt`, `google-services.json`, Firebase 의존성)는 제거되었습니다.

---

## 3. 공통 데이터 모델

### 3.1 HeartbeatPayload

에이전트가 서버로 전송하는 Heartbeat 페이로드 구조입니다.

```json
{
  "p_asset_uid": "D00001",
  "p_system_info": {
    "cpu_usage": 45.2,
    "memory_total_mb": 8192,
    "memory_used_mb": 5120,
    "storage_total_gb": 128.0,
    "storage_used_gb": 89.3,
    "battery_level": 72,
    "battery_charging": true,
    "network_type": "WIFI",
    "ip_address": "192.168.1.100",
    "os_version": "Android 14 (API 34)",
    "uptime_hours": 48.5,
    "os_detail_version": "TP1A.220624.014 / 2024-01-05",
    "device_manufacturer": "Samsung",
    "device_model": "SM-G998B",
    "device_user": "user@gmail.com",
    "asset_user_name": "김개발",
    "employee_id": "EMP20001",
    "agent_version": "1.0.0"
  }
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `p_asset_uid` | text | **필수** | OA 자산 고유 식별자 (서버 형식: 현재기준 `D00001` 또는 변경후 `BDT00001`, `docs/asset_uid_spec.md`) |
| `p_system_info` | jsonb | **필수** | 시스템 모니터링 정보 (26개 필드) |

### 3.2 SystemInfo

시스템 모니터링 수집 항목입니다. 모든 플랫폼이 동일한 **26개 필드** 구조로 전송합니다 (19~26번은 기본값 `""`, 플랫폼별로 해당 항목만 채움).

| # | 필드 | 타입 | 단위 | 설명 |
|---|------|------|------|------|
| 1 | `cpu_usage` | float | % (0~100) | CPU 사용률 |
| 2 | `memory_total_mb` | int | MB | 전체 물리 메모리 |
| 3 | `memory_used_mb` | int | MB | 사용 중 메모리 |
| 4 | `storage_total_gb` | float | GB | 전체 저장공간 |
| 5 | `storage_used_gb` | float | GB | 사용 중 저장공간 |
| 6 | `battery_level` | int | % (0~100) | 배터리 잔량 (데스크탑은 `-1`) |
| 7 | `battery_charging` | boolean | - | 충전 중 여부 (데스크탑은 `true`) |
| 8 | `network_type` | text | - | `WIFI` / `CELLULAR` / `ETHERNET` / `UNKNOWN` |
| 9 | `ip_address` | text | - | 기기 IP 주소 (로컬 네트워크) |
| 10 | `os_version` | text | - | OS 이름 + 버전 (예: `Android 14 (API 34)`) |
| 11 | `uptime_hours` | float | 시간 | 기기 부팅 후 경과 시간 |
| 12 | `os_detail_version` | text | - | 보안 패치 레벨 + 빌드 번호 (예: `TP1A.220624.014 / 2024-01-05`) |
| 13 | `device_manufacturer` | text | - | 제품 제조사 (예: `Samsung`, `LG`, `Google`) |
| 14 | `device_model` | text | - | 모델명 (예: `SM-G998B`, `Pixel 7`) |
| 15 | `device_user` | text | - | 기기 로그인 계정명 (Google 계정 등) |
| 16 | `asset_user_name` | text | - | OA 자산 사용자명 (서버 조회: `assets.user_name`) |
| 17 | `employee_id` | text | - | 사용자 사번 (서버 조회: `users.employee_id`) |
| 18 | `agent_version` | text | - | 에이전트 앱 버전 (예: `1.0.0`) |
| 19 | `mac_address` | text | - | MAC 주소 — 서버가 `assets.mac_address`로 동기화 |
| 20 | `serial_number` | text | - | 기기 시리얼 번호 |
| 21 | `phone_number` | text | - | 전화번호 (Android, `READ_PHONE_STATE`) |
| 22 | `os_security_patch` | text | - | Android `ro.build.version.security_patch` (예: `2025-12-05`) |
| 23 | `os_vendor_security_patch` | text | - | Android `ro.vendor.build.security_patch` |
| 24 | `os_build_number` | text | - | Windows OS Build (예: `19045`), macOS 시스템 빌드 (예: `24A348`) |
| 25 | `os_ubr` | text | - | Windows Update Build Revision (예: `5247`) |
| 26 | `os_kb_list` | text | - | Windows 적용 KB 목록 (HotFixID 콤마 구분) |

```kotlin
// shared/src/commonMain/kotlin/com/oamanager/agent/model/SystemInfo.kt
@Serializable
data class SystemInfo(
    @SerialName("cpu_usage")            val cpuUsage: Float,
    @SerialName("memory_total_mb")      val memoryTotalMb: Int,
    @SerialName("memory_used_mb")       val memoryUsedMb: Int,
    @SerialName("storage_total_gb")     val storageTotalGb: Float,
    @SerialName("storage_used_gb")      val storageUsedGb: Float,
    @SerialName("battery_level")        val batteryLevel: Int,
    @SerialName("battery_charging")     val batteryCharging: Boolean,
    @SerialName("network_type")         val networkType: String,
    @SerialName("ip_address")           val ipAddress: String,
    @SerialName("os_version")           val osVersion: String,
    @SerialName("uptime_hours")         val uptimeHours: Float,
    @SerialName("os_detail_version")    val osDetailVersion: String,
    @SerialName("device_manufacturer")  val deviceManufacturer: String,
    @SerialName("device_model")         val deviceModel: String,
    @SerialName("device_user")          val deviceUser: String,
    @SerialName("asset_user_name")      val assetUserName: String,
    @SerialName("employee_id")          val employeeId: String,
    @SerialName("agent_version")        val agentVersion: String,
    @SerialName("mac_address")          val macAddress: String = "",
    @SerialName("serial_number")        val serialNumber: String = "",
    @SerialName("phone_number")         val phoneNumber: String = "",
    @SerialName("os_security_patch")        val osSecurityPatch: String = "",
    @SerialName("os_vendor_security_patch") val osVendorSecurityPatch: String = "",
    @SerialName("os_build_number")          val osBuildNumber: String = "",
    @SerialName("os_ubr")                   val osUbr: String = "",
    @SerialName("os_kb_list")               val osKbList: String = "",
)
```

---

## 4. 네트워크 프로토콜

### 4.1 엔드포인트 목록
| 순서 | 엔드포인트 | 메서드 | 용도 | 인증 |
|------|-----------|--------|------|------|
| 1 | `/auth/v1/token?grant_type=password` | POST | 로그인 (email/password) | anon key |
| 2 | `/auth/v1/token?grant_type=refresh_token` | POST | 토큰 갱신 | anon key |
| 3 | `/rest/v1/rpc/update_heartbeat` | POST | Heartbeat 전송 (⛔ 현재 실행 권한 없음) | Bearer token |
| 4 | `/rest/v1/rpc/verify_user` | POST | 사용자 확인 (⛔ 현재 실행 권한 없음) | Bearer token |
| 5 | `/rest/v1/rpc/confirm_assignment` | POST | 자산 수령 확인 (⛔ 현재 실행 권한 없음) | Bearer token |
| 6 | ~~`/rest/v1/device_tokens`~~ | — | FCM 토큰 등록 — **폐지** (FCM 미사용) | — |
| 7 | `/rest/v1/agent_settings?setting_key=in.(latest_agent_version,min_agent_version)` | GET | Heartbeat 성공 후 에이전트 버전 확인 (11.3절 참조) | Bearer token |
| 8 | `wss://apioa.terraforming.info/realtime/v1/websocket` | WebSocket | Supabase Realtime 연결 (private 채널: Presence + Broadcast + **postgres_changes**) | Bearer token |
| 9 | Realtime postgres_changes (notifications) | WebSocket | `notifications` 테이블 INSERT 구독 (filter: `asset_uid=eq.<자기 자산>`) — 관리자 재확인 요청 등 서버 발생 알림 수신 | Bearer token |

### 4.2 인증 방식

공용 에이전트 서비스 계정은 사용하지 않습니다. 각 설치본은 자산 담당자 또는
관리자 개인 OA 계정으로 명시적으로 로그인해야 합니다.

| 항목 | 값 |
|------|-----|
| 계정 | 자산 담당자 또는 관리자 개인 OA 계정 |
| 역할 | `authenticated` (Supabase Auth) |
| 권한 | 서버 RPC가 해당 자산의 담당자 또는 관리자인지 별도로 검증 |
| 토큰 저장 | 플랫폼별 보안 저장소 (8.1 참조) |
| 토큰 만료 | 3600초 (1시간), refresh token으로 갱신 |

> **보안**: APK에 이메일·비밀번호를 포함하거나 갱신 실패 시 자동 로그인하지 않습니다. 개인 세션이 없거나 갱신에 실패하면 사용자가 다시 로그인해야 합니다.

> **전환 범위**: Android·Windows·macOS 설정 화면은 모두 개인 계정 로그인을
> 지원합니다. Windows/macOS는 이전 공용 계정 토큰이 남아 있더라도 개인 로그인
> 전환 표시가 없는 세션으로 자동 Heartbeat를 재개하지 않습니다. 서버 권한을
> 완화해서는 안 됩니다.

**인증 플로우:**
```
1. 앱 최초 실행 또는 구버전에서 업데이트 → 이전 공용 세션을 사용하지 않음
2. 사용자가 자산 담당자 또는 관리자 개인 OA 계정으로 명시적 로그인
3. access_token + refresh_token을 보안 저장소에 저장
4. Heartbeat 전송 시 Authorization: Bearer <access_token> 헤더 사용
5. access_token 만료 → refresh_token으로 갱신 → 4번 반복
6. refresh token 갱신 실패 → Heartbeat를 중단하고 사용자 재로그인 요청
```

### 4.3 Heartbeat 요청/응답 예시

**요청:**
```http
POST /rest/v1/rpc/update_heartbeat HTTP/1.1
Host: apioa.terraforming.info
Authorization: Bearer <access_token>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json

{
  "p_asset_uid": "D00001",
  "p_system_info": {
    "cpu_usage": 45.2,
    "memory_total_mb": 8192,
    "memory_used_mb": 5120,
    "storage_total_gb": 128.0,
    "storage_used_gb": 89.3,
    "battery_level": 72,
    "battery_charging": true,
    "network_type": "WIFI",
    "ip_address": "192.168.1.100",
    "os_version": "Android 14 (API 34)",
    "uptime_hours": 48.5,
    "os_detail_version": "TP1A.220624.014 / 2024-01-05",
    "device_manufacturer": "Samsung",
    "device_model": "SM-G998B",
    "device_user": "user@gmail.com",
    "asset_user_name": "김개발",
    "employee_id": "EMP20001",
    "agent_version": "1.0.0"
  }
}
```

**응답 (성공):**
```http
HTTP/1.1 200 OK
Content-Type: application/json

null
```

**응답 (자산 없음):**
```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "code": "P0001",
  "message": "asset not found: D99999"
}
```

---

## 5. 백엔드 연동

### 5.1 RPC 함수 `update_heartbeat`

> 최종 정의: `OA_backend/supabase/migrations/20260816000000_security_hardening.sql` (백엔드 README 9.6)

```sql
CREATE OR REPLACE FUNCTION public.update_heartbeat(
  p_asset_uid text,
  p_system_info jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_mac text;
BEGIN
  IF NOT (
    public.is_admin_group()
    OR public.is_current_asset_assignee(p_asset_uid)
  ) THEN
    RAISE EXCEPTION 'forbidden: asset assignee or administrator required';
  END IF;

  v_mac := NULLIF(btrim(p_system_info->>'mac_address'), '');
  UPDATE public.assets
  SET last_active_at = now(),
      specifications = CASE
        WHEN p_system_info IS NOT NULL
        THEN jsonb_set(COALESCE(specifications, '{}'::jsonb), '{device_status}', p_system_info)
        ELSE specifications
      END,
      mac_address = COALESCE(v_mac, mac_address)
  WHERE asset_uid = p_asset_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'asset not found: %', p_asset_uid;
  END IF;
END;
$$;

-- 현재: PUBLIC/anon/authenticated/service_role 모두 EXECUTE 회수 (의도된 차단)
REVOKE EXECUTE ON FUNCTION public.update_heartbeat(text, jsonb)
  FROM PUBLIC, anon, authenticated, service_role;
```

| 항목 | 설명 |
|------|------|
| 함수명 | `update_heartbeat` |
| 파라미터 | `p_asset_uid` (text, 필수), `p_system_info` (jsonb, 선택) |
| 반환 | void |
| 내부 권한 검사 | 관리자 그룹 또는 해당 자산 담당자(`assets.user_id`가 호출자) |
| 실행 권한 | **현재 없음** — 기기별 신원 재도입(§15) 후에만 부여 |
| 동작 | `last_active_at = now()` + `specifications.device_status` 저장 + `mac_address` 동기화 |
| 에러 | 권한 없음 → `forbidden`, 존재하지 않는 `asset_uid` → `asset not found` |

### 5.2 데이터 저장 구조

Heartbeat 데이터는 기존 `assets` 테이블의 두 컬럼에 저장됩니다. 별도 테이블 생성 없음.

| 저장 위치 | 타입 | 용도 |
|----------|------|------|
| `assets.last_active_at` | TIMESTAMPTZ | 최종 접속 시각 (RPC 내부에서 `now()` 설정) |
| `assets.specifications->'device_status'` | JSONB | 시스템 모니터링 정보 (3.2 SystemInfo 구조) |

> **참고**: `specifications` 컬럼은 기존에 자산 사양 정보(화면 크기, 프로세서 등)를 저장하는 JSONB 필드입니다. `device_status` 키 아래에 모니터링 데이터를 저장하므로 기존 사양 데이터와 충돌하지 않습니다.

**저장 후 데이터 예시:**
```json
// assets.specifications
{
  "screen_size": "15.6",
  "processor": "i7-13700",
  "device_status": {
    "cpu_usage": 45.2,
    "memory_total_mb": 8192,
    "memory_used_mb": 5120,
    "storage_total_gb": 128.0,
    "storage_used_gb": 89.3,
    "battery_level": 72,
    "battery_charging": true,
    "network_type": "WIFI",
    "ip_address": "192.168.1.100",
    "os_version": "Android 14 (API 34)",
    "uptime_hours": 48.5,
    "os_detail_version": "TP1A.220624.014 / 2024-01-05",
    "device_manufacturer": "Samsung",
    "device_model": "SM-G998B",
    "device_user": "user@gmail.com",
    "asset_user_name": "김개발",
    "employee_id": "EMP20001",
    "agent_version": "1.0.0"
  }
}
```

### 5.3 접속현황 인디케이터 참조

> 프론트엔드 명세서(`OA_frontend/README.md`) 6.4절 참조

에이전트가 전송한 `last_active_at` 값을 기반으로 프론트엔드에서 접속현황 인디케이터를 표시합니다.

| 조건 | 표시 | 색상 |
|------|------|------|
| `last_active_at` IS NULL | 회색 동그라미 (미접속) | Grey |
| now() − `last_active_at` ≤ `active_threshold_minutes` (기본 60분) | 초록색 동그라미 (접속중) | Green |
| 경과일 1 ~ `warning_threshold_days` (기본 31일) | 연두색 동그라미 + 경과일 숫자 | Light Green |
| 경과일 > `warning_threshold_days` | 빨간색 동그라미 (장기미접속) | Red |

> - 임계값은 `access_settings` 테이블에서 관리 (백엔드 명세서 4.7절 참조)
> - 에이전트가 15분 주기로 Heartbeat를 전송하면, 정상 가동 기기는 항상 **초록색(접속중)** 표시
> - 에이전트 중단 시 60분 후 **연두색**, 31일 초과 시 **빨간색**으로 자동 전환

---

## 6. Android 구현

### 6.1 기술 스택 & 의존성

| 항목 | 값 |
|------|-----|
| 언어 | Kotlin 1.9.22 |
| Min SDK | 26 (Android 8.0) |
| Target SDK | 34 (Android 14) |
| Compile SDK | 34 |  
| Gradle | 8.3 |
| AGP | 8.1.0 |

**의존성 목록 (app/build.gradle.kts):**

| 그룹 | 아티팩트 | 버전 | 용도 |
|------|---------|------|------|
| `project` | `:shared` | - | KMP 공유 모듈 |
| `androidx.work` | `work-runtime-ktx` | 2.9.0 | 백그라운드 스케줄링 |
| `androidx.security` | `security-crypto` | 1.1.0-alpha06 | EncryptedSharedPreferences |
| `androidx.lifecycle` | `lifecycle-viewmodel-ktx` | 2.7.0 | ViewModel |
| `androidx.activity` | `activity-ktx` | 1.8.2 | Activity KTX |
| `com.google.android.material` | `material` | 1.11.0 | Material Design UI |

**공유 모듈 의존성 (shared/build.gradle.kts):**

| 그룹 | 아티팩트 | 버전 | 용도 | 타겟 |
|------|---------|------|------|------|
| `io.ktor` | `ktor-client-core` | 2.3.8 | HTTP 클라이언트 | commonMain |
| `io.ktor` | `ktor-client-content-negotiation` | 2.3.8 | JSON 변환 | commonMain |
| `io.ktor` | `ktor-serialization-kotlinx-json` | 2.3.8 | JSON 직렬화 | commonMain |
| `org.jetbrains.kotlinx` | `kotlinx-serialization-json` | 1.6.3 | JSON 모델 | commonMain |
| `org.jetbrains.kotlinx` | `kotlinx-coroutines-core` | 1.8.0 | 비동기 처리 | commonMain |
| `io.ktor` | `ktor-client-websockets` | 2.3.8 | WebSocket 클라이언트 (Realtime) | commonMain |
| `io.ktor` | `ktor-client-okhttp` | 2.3.8 | OkHttp 엔진 | androidMain |

### 6.2 AndroidManifest.xml

**필요 권한:**

| 권한 | 용도 | 필수 |
|------|------|------|
| `INTERNET` | Supabase API 통신 | **필수** |
| `RECEIVE_BOOT_COMPLETED` | 기기 재부팅 후 WorkManager 재등록 | **필수** |
| `ACCESS_NETWORK_STATE` | 네트워크 타입, 연결 상태 확인 | **필수** |
| `FOREGROUND_SERVICE` | 5분 주기 Heartbeat용 포그라운드 서비스 | **필수** |
| `FOREGROUND_SERVICE_DATA_SYNC` | Android 14+ 포그라운드 서비스 타입 지정 | **필수** |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | OEM 배터리 최적화 예외 요청 | 권장 |
| `POST_NOTIFICATIONS` | Android 13+ 알림 권한 (관리자 알림 + 포그라운드 서비스) | **필수** |
| `READ_PHONE_STATE` | 전화번호(`phone_number`) 수집 | 선택 |

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.READ_PHONE_STATE" />

    <application
        android:name="com.oamanager.agent.android.OAAgentApp"
        android:allowBackup="false"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:theme="@style/Theme.OAAgent">

        <!-- WorkManager 기본 초기화 제거 (OAAgentApp에서 Configuration.Provider로 초기화) -->
        <provider
            android:name="androidx.startup.InitializationProvider"
            android:authorities="${applicationId}.androidx-startup"
            tools:node="remove">
            <meta-data
                android:name="androidx.work.WorkManagerInitializer"
                android:value="androidx.startup"
                tools:node="remove" />
        </provider>

        <activity
            android:name="com.oamanager.agent.android.ui.SetupActivity"
            android:exported="true"
            android:label="@string/app_name">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <!-- 5분 주기 Heartbeat + Realtime 연결용 포그라운드 서비스 -->
        <service
            android:name="com.oamanager.agent.android.service.HeartbeatForegroundService"
            android:exported="false"
            android:foregroundServiceType="dataSync" />

        <receiver
            android:name="com.oamanager.agent.android.receiver.BootReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
            </intent-filter>
        </receiver>
    </application>
</manifest>
```

> FCM 서비스(`OAFirebaseMessagingService`)는 제거되었습니다.

### 6.3 앱 컴포넌트 구조

#### 6.3.1 OAAgentApp.kt
`Application` 클래스. WorkManager 초기화 및 Heartbeat 작업 등록을 담당합니다.

```kotlin
class OAAgentApp : Application(), Configuration.Provider {

    override fun getWorkManagerConfiguration(): Configuration {
        return Configuration.Builder()
            .setMinimumLoggingLevel(Log.INFO)
            .build()
    }

    /**
     * 사용자 설정 주기에 따라 Heartbeat 스케줄링 방식을 결정합니다.
     * - 5분: ForegroundService (WorkManager 최소 주기 15분 미만)
     * - 15분/30분: WorkManager PeriodicWorkRequest
     */
    fun enqueueHeartbeat(intervalMinutes: Int = 15) {
        // 기존 작업/서비스 정리
        WorkManager.getInstance(this).cancelUniqueWork("heartbeat")
        HeartbeatForegroundService.stop(this)

        if (intervalMinutes < 15) {
            // 5분 주기: ForegroundService 사용
            HeartbeatForegroundService.start(this, intervalMinutes)
        } else {
            // 15분/30분 주기: WorkManager 사용
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val heartbeatWork = PeriodicWorkRequestBuilder<HeartbeatWorker>(
                intervalMinutes.toLong(), TimeUnit.MINUTES
            )
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    WorkRequest.MIN_BACKOFF_MILLIS,
                    TimeUnit.MILLISECONDS
                )
                .build()

            WorkManager.getInstance(this).enqueueUniquePeriodicWork(
                "heartbeat",
                ExistingPeriodicWorkPolicy.REPLACE,
                heartbeatWork
            )
        }
    }
}
```

| 항목 | 설명 |
|------|------|
| WorkManager 초기화 | `Configuration.Provider` 구현으로 커스텀 설정 |
| 주기 분기 | `intervalMinutes < 15` → ForegroundService, `≥ 15` → WorkManager |
| 작업 등록 | `enqueueUniquePeriodicWork`로 중복 방지 (`REPLACE` 정책으로 주기 변경 반영) |
| 네트워크 제약 | `NetworkType.CONNECTED` → 오프라인 시 자동 대기 |
| 백오프 | 실패 시 지수 백오프 (최소 10초 → 20초 → 40초...) |

#### 6.3.2 HeartbeatWorker.kt
WorkManager `CoroutineWorker` 구현. 핵심 Heartbeat 전송 로직입니다.

```kotlin
class HeartbeatWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        // 1. 설정 로드
        val prefs = AgentPreferences(applicationContext)
        val assetUid = prefs.assetUid ?: return Result.failure()

        // 2. 시스템 정보 수집
        val systemInfo = SystemInfoCollector(applicationContext).collect()

        // 3. 인증 확인/갱신
        val client = SupabaseClient(AgentConfig.SUPABASE_URL, AgentConfig.SUPABASE_ANON_KEY)
        val token = AuthManager(client, prefs).getValidToken()
            ?: return Result.retry()

        // 4. Heartbeat 전송
        return try {
            client.updateHeartbeat(token, assetUid, systemInfo)
            prefs.lastHeartbeatTime = System.currentTimeMillis()
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}
```

**실행 플로우:**
```
doWork() 호출 (WorkManager, 15분 주기)
  ├→ 1. AgentPreferences에서 asset_uid 로드
  │     └→ asset_uid 없음 → Result.failure() (설정 미완료)
  ├→ 2. SystemInfoCollector.collect() 호출
  │     └→ CPU, 메모리, 스토리지, 배터리, 네트워크 수집
  ├→ 3. AuthManager.getValidToken() 호출
  │     ├→ access_token 유효 → 그대로 사용
  │     ├→ access_token 만료 → refresh_token으로 갱신
  │     └→ 둘 다 실패 → Result.retry()
  └→ 4. SupabaseClient.updateHeartbeat() 호출
        ├→ 200 OK → Result.success()
        ├→ 401 Unauthorized → 토큰 갱신 후 재시도
        └→ 네트워크 오류 → Result.retry()
```

#### 6.3.3 SetupActivity.kt
초기 설정 화면. `asset_uid` 입력 및 에이전트 상태 확인을 담당합니다. (6.7 UI 명세 참조)

```kotlin
class SetupActivity : AppCompatActivity() {
    private val viewModel: SetupViewModel by viewModels()

    // - asset_uid 입력 (EditText + 정규식 검증)
    // - "시작" 버튼 → asset_uid 저장 + WorkManager 등록
    // - "즉시 전송" 버튼 → OneTimeWorkRequest로 즉시 Heartbeat 테스트
    // - 상태 표시: 마지막 전송 시각, 연결 상태, asset_uid
}
```

#### 6.3.4 AgentPreferences.kt
`EncryptedSharedPreferences`를 래핑하여 민감 데이터를 안전하게 저장합니다.

```kotlin
class AgentPreferences(context: Context) {
    private val prefs: SharedPreferences = EncryptedSharedPreferences.create(
        "oa_agent_prefs",
        MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC),
        context,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    var assetUid: String?           // 자산 고유 식별자
    var accessToken: String?        // Supabase access_token
    var refreshToken: String?       // Supabase refresh_token
    var lastHeartbeatTime: Long     // 마지막 성공 시각 (epoch ms)
    var intervalMinutes: Int        // Heartbeat 전송 주기 (5/15/30, 기본 15)
    var assetUserName: String?      // OA 자산 사용자명 (서버 조회)
    var employeeId: String?         // 사용자 사번 (서버 조회)
    var lastVerifiedAt: Long        // 마지막 사용자 확인 시각 (epoch ms)
}
```

| 저장 항목 | 암호화 | 설명 |
|----------|--------|------|
| `asset_uid` | AES-256 | 자산 식별자 |
| `access_token` | AES-256 | JWT 액세스 토큰 |
| `refresh_token` | AES-256 | JWT 갱신 토큰 |
| `last_heartbeat_time` | AES-256 | 마지막 Heartbeat 성공 시각 |
| `interval_minutes` | AES-256 | 전송 주기 (5/15/30분, 기본 15) |
| `asset_user_name` | AES-256 | OA 자산 사용자명 |
| `employee_id` | AES-256 | 사용자 사번 |
| `last_verified_at` | AES-256 | 마지막 사용자 확인 시각 |
| `personal_account_auth_migrated_v1` | AES-256 | 개인 계정 로그인 전환 표시 (없으면 이전 공용 세션을 쓰지 않음) |

> 이전 평문 저장소(`oa_agent_prefs_plain`)는 이관하지 않고 비웁니다(재로그인 필요). Android Keystore를 쓸 수 없으면 평문 저장으로 대체하지 않고 실패합니다.

#### 6.3.5 SupabaseClient.kt
Ktor 기반 경량 HTTP 클라이언트입니다. KMP `shared` 모듈의 `commonMain`에 위치합니다.

```kotlin
// shared/src/commonMain/kotlin/com/oamanager/agent/network/SupabaseClient.kt
class SupabaseClient(
    private val supabaseUrl: String,
    private val anonKey: String
) {
    private val client = HttpClient {
        install(ContentNegotiation) { json() }
    }

    // 로그인
    suspend fun signIn(email: String, password: String): AuthResponse

    // 토큰 갱신
    suspend fun refreshToken(refreshToken: String): AuthResponse

    // Heartbeat 전송
    suspend fun updateHeartbeat(
        accessToken: String,
        assetUid: String,
        systemInfo: SystemInfo
    )
}
```

#### 6.3.6 SystemInfoCollector.kt
Android API를 사용하여 시스템 정보를 수집합니다. KMP `expect/actual` 패턴으로 구현됩니다.

```kotlin
// shared/src/commonMain - expect 선언
expect class SystemInfoCollector {
    suspend fun collect(): SystemInfo
}

// shared/src/androidMain - actual 구현
actual class SystemInfoCollector(private val context: Context) {
    actual suspend fun collect(): SystemInfo {
        val prefs = AgentPreferences(context)
        return SystemInfo(
            cpuUsage          = readCpuUsage(),             // /proc/stat 파싱
            memoryTotalMb     = getMemoryTotal(),            // ActivityManager.MemoryInfo
            memoryUsedMb      = getMemoryUsed(),             // ActivityManager.MemoryInfo
            storageTotalGb    = getStorageTotal(),           // StatFs
            storageUsedGb     = getStorageUsed(),            // StatFs
            batteryLevel      = getBatteryLevel(),           // BatteryManager
            batteryCharging   = isBatteryCharging(),         // BatteryManager
            networkType       = getNetworkType(),            // ConnectivityManager
            ipAddress         = getIpAddress(),              // NetworkInterface
            osVersion         = getOsVersion(),              // Build.VERSION
            uptimeHours       = getUptimeHours(),            // SystemClock
            osDetailVersion   = getOsDetailVersion(),        // Build.DISPLAY + SECURITY_PATCH
            deviceManufacturer = Build.MANUFACTURER,         // 제조사
            deviceModel       = Build.MODEL,                 // 모델명
            deviceUser        = getDeviceUser(),             // Google 계정 또는 Build.USER
            assetUserName     = prefs.assetUserName ?: "",   // 저장된 사용자명
            employeeId        = prefs.employeeId ?: "",      // 저장된 사번
            agentVersion      = BuildConfig.VERSION_NAME,    // 앱 버전
        )
    }
}
```

#### 6.3.7 BootReceiver.kt
기기 재부팅 시 WorkManager 작업을 재등록합니다. (WorkManager는 자체적으로 재부팅 후 복구하지만, OEM 특성에 따른 안전장치입니다.)

```kotlin
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            (context.applicationContext as OAAgentApp).enqueueHeartbeat()
        }
    }
}
```

### 6.4 Heartbeat 스케줄링 설정

#### 사용자 설정 가능 주기

| 주기 | 스케줄링 방식 | 설명 |
|------|-------------|------|
| **5분** | `ForegroundService` + 상태바 알림 | WorkManager 최소 주기(15분) 미만이므로 포그라운드 서비스 사용 |
| **15분** (기본값) | `WorkManager PeriodicWorkRequest` | WorkManager 최소 주기, 배터리 효율적 |
| **30분** | `WorkManager PeriodicWorkRequest` | 저전력 환경 권장 |

#### WorkManager 설정 (15분/30분 주기)

| 설정 | 값 | 설명 |
|------|-----|------|
| 작업 유형 | `PeriodicWorkRequest` | 주기적 반복 |
| 주기 | 15분 또는 30분 (사용자 설정) | SetupActivity에서 선택 |
| 네트워크 제약 | `NetworkType.CONNECTED` | 오프라인 시 대기 |
| 중복 정책 | `ExistingPeriodicWorkPolicy.REPLACE` | 주기 변경 시 재등록 |
| 백오프 | `BackoffPolicy.EXPONENTIAL`, 10초 시작 | 실패 시 지수 증가 |
| 작업 ID | `"heartbeat"` | 고유 식별자 |

#### ForegroundService 설정 (5분 주기)

| 설정 | 값 | 설명 |
|------|-----|------|
| 서비스 타입 | `foregroundServiceType="dataSync"` | Android 14+ 필수 지정 |
| 알림 채널 | `heartbeat_channel` | 상태바 지속 알림 표시 |
| 알림 내용 | "OA Agent 실행 중 (5분 주기)" | 사용자에게 서비스 동작 알림 |
| 타이머 | `Handler.postDelayed` / `Timer` | 5분 간격 반복 실행 |
| 네트워크 확인 | `ConnectivityManager` | 전송 전 네트워크 상태 확인 |

> **주기 근거**: `access_settings.active_threshold_minutes`의 기본값이 60분이므로, 15분 주기면 임계값 내에 최소 4회 Heartbeat 전송 보장. 5분 주기는 12회 보장. 정상 가동 기기는 항상 **초록색(접속중)** 표시.

### 6.5 시스템 정보 수집 API 매핑

| # | 수집 항목 | Android API | 비고 |
|---|----------|------------|------|
| 1 | CPU 사용률 | `/proc/stat` 파일 파싱 | idle/total 비율 계산 |
| 2 | 전체 메모리 | `ActivityManager.MemoryInfo.totalMem` | API 16+ |
| 3 | 사용 메모리 | `totalMem - availMem` | `ActivityManager.getMemoryInfo()` |
| 4 | 전체 스토리지 | `StatFs(Environment.getDataDirectory()).totalBytes` | API 18+ |
| 5 | 사용 스토리지 | `totalBytes - availableBytes` | `StatFs` |
| 6 | 배터리 잔량 | `BatteryManager.getIntProperty(BATTERY_PROPERTY_CAPACITY)` | API 21+ |
| 7 | 충전 여부 | `BatteryManager.isCharging()` | API 23+ |
| 8 | 네트워크 타입 | `ConnectivityManager.getActiveNetwork()` + `NetworkCapabilities` | API 23+ |
| 9 | IP 주소 | `NetworkInterface.getInetAddresses()` | IPv4 우선 |
| 10 | OS 버전 | `"Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})"` | 문자열 조합 |
| 11 | 업타임 | `SystemClock.elapsedRealtime() / 3600000f` | 밀리초 → 시간 변환 |
| 12 | OS 상세 버전 | `"${Build.DISPLAY} / ${Build.VERSION.SECURITY_PATCH}"` | 보안패치 레벨 + 빌드 번호 |
| 13 | 제조사 | `Build.MANUFACTURER` | 예: Samsung, LG, Google |
| 14 | 모델명 | `Build.MODEL` | 예: SM-G998B, Pixel 7 |
| 15 | 기기 사용자 | `AccountManager.getAccounts()` 또는 `Build.USER` | Google 계정 우선 |
| 16 | 자산 사용자명 | `AgentPreferences.assetUserName` | 초기 설정 시 서버 조회하여 저장 |
| 17 | 사용자 사번 | `AgentPreferences.employeeId` | 초기 설정 시 서버 조회하여 저장 |
| 18 | 에이전트 버전 | `BuildConfig.VERSION_NAME` | app/build.gradle.kts에서 관리 |

### 6.6 배터리 최적화 대응

> Android OEM들은 자체 배터리 최적화로 백그라운드 작업을 제한합니다. 에이전트 안정성을 위해 아래 대응이 필요합니다.

| 제조사 | 이슈 | 대응 방법 |
|--------|------|----------|
| **공통** | Android Doze 모드 | `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` 권한 요청 |
| **Samsung** | 자동 절전, 사용하지 않는 앱 절전 | 설정 → 배터리 → 백그라운드 사용 제한 → "제한 없음" |
| **Xiaomi** | MIUI 자동 시작 관리, 배터리 세이버 | 보안 → 자동 시작 관리 → 허용, 배터리 → 앱 절전 → "제한 없음" |
| **Huawei** | EMUI 앱 시작 관리 | 설정 → 배터리 → 앱 시작 → 수동 관리 (자동 시작, 백그라운드 활동 허용) |
| **OPPO/OnePlus** | ColorOS 배터리 최적화 | 설정 → 배터리 → 더 보기 → 앱 최적화 해제 |

> **SetupActivity에서 배터리 최적화 예외 요청 다이얼로그를 자동 표시합니다.**
> ```kotlin
> val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
>     data = Uri.parse("package:${packageName}")
> }
> startActivity(intent)
> ```

### 6.7 SetupActivity UI 명세

**레이아웃 와이어프레임:**
```
┌──────────────────────────────┐
│       OA Agent 설정           │  ← AppBar
├──────────────────────────────┤
│                              │
│  자산 번호 (asset_uid)        │  ← 라벨
│  ┌────────────────────────┐  │
│  │ D00001               │  │  ← EditText (정규식 실시간 검증)
│  └────────────────────────┘  │
│  ⚠ 형식: D00001 또는 BDT00001 │  ← 도움말 텍스트
│     (두 형식 모두 허용)       │
│                              │
│  전송 주기                    │  ← 라벨
│  ┌────────────────────────┐  │
│  │ ▼  15분 (기본값)        │  │  ← Spinner (5분/15분/30분)
│  └────────────────────────┘  │
│  ⚠ 5분: 상태바 알림 표시됨    │  ← 5분 선택 시 안내
│                              │
│  ┌──────────┐ ┌──────────┐  │
│  │  시 작    │ │ 즉시 전송 │  │  ← 버튼 2개
│  └──────────┘ └──────────┘  │
│                              │
│  ── 상태 정보 ────────────── │  ← 구분선
│                              │
│  연결 상태: ● 연결됨          │  ← 초록/빨강 인디케이터
│  자산 번호: D00001         │
│  전송 주기: 15분              │
│  마지막 전송: 2026-03-11      │
│              14:30:22        │
│  전송 결과: ✓ 성공            │  ← 성공/실패 표시
│  에이전트 버전: 1.0.0         │
│  최신 버전: 1.0.0 ✓          │  ← 또는 "1.1.0 업데이트 필요"
│                              │
│  ── 사용자 확인 ───────────── │  ← 구분선
│                              │
│  마지막 확인: 2026-02-15      │
│  상태: ✓ 확인 완료            │  ← 또는 "⚠ 확인 필요"
│  ┌──────────────────────┐   │
│  │  사용자 확인하기       │   │  ← 버튼 (확인 필요 시 강조)
│  └──────────────────────┘   │
│                              │
└──────────────────────────────┘
```

**asset_uid 입력 검증:**

| 항목 | 규칙 |
|------|------|
| 정규식 | `AgentConfig.ASSET_UID_REGEX` = `^[A-Za-z0-9_-]+$` (문자 검사만). 최종 형식(현재기준 + 변경후 두 형식)은 서버가 검증 |
| 실시간 검증 | 입력 중 `TextWatcher`로 형식 검증, 오류 시 빨간색 테두리 |
| "시작" 버튼 | 정규식 통과 시에만 활성화 |
| "즉시 전송" 버튼 | asset_uid 저장 완료 후에만 활성화 |

**상태 표시 항목:**

| 항목 | 소스 | 갱신 주기 |
|------|------|----------|
| 연결 상태 | `ConnectivityManager` | 실시간 (NetworkCallback) |
| 자산 번호 | `AgentPreferences.assetUid` | 설정 시 |
| 마지막 전송 | `AgentPreferences.lastHeartbeatTime` | Heartbeat 성공 시 |
| 전송 결과 | WorkManager `WorkInfo.state` | WorkManager 콜백 |

---

## 7. 플랫폼별 구현 및 향후 계획

### 7.1 iOS (향후)
| 항목 | 계획 |
|------|------|
| 기술 | KMP shared 모듈 + Swift UI |
| 스케줄링 | `BGAppRefreshTask` (Background App Refresh) |
| HTTP | Ktor Client (Darwin 엔진) |
| 보안 저장 | Keychain Services |
| 최소 버전 | iOS 15.0 |

### 7.2 Linux (향후)
| 항목 | 계획 |
|------|------|
| 기술 | KMP shared 모듈 + JVM/Native |
| 스케줄링 | `systemd timer` 또는 `cron` (15분) |
| HTTP | Ktor Client (CIO 엔진) |
| 보안 저장 | `libsecret` (GNOME Keyring) 또는 암호화 파일 |
| 시스템 정보 | `/proc/stat`, `/proc/meminfo`, `df`, `uname` |

### 7.3 Windows (✅ 구현)

| 항목 | 값 |
|------|-----|
| 기술 | KMP shared 모듈 (desktop 타겟) + Kotlin/JVM |
| 최소 요구 | Windows 10 이상, Java 17+ |
| 스케줄링 | 내부 Timer (트레이 모드) / Windows Task Scheduler (서비스 모드) |
| HTTP | Ktor Client (CIO 엔진) |
| UI | Java Swing — 시스템 트레이 아이콘 + 설정/확인 다이얼로그 |
| 보안 저장 | Windows DPAPI (CurrentUser) — `%APPDATA%\OAAgent\agent.dpapi` |
| 시스템 정보 | WMI (PowerShell `Get-CimInstance`) + Java Management API |
| Realtime | WebSocket (Ktor CIO) — Presence, 명령 수신, 알림 발신 |

#### 실행 모드

| 모드 | 명령 | 설명 |
|------|------|------|
| **트레이 모드** (기본) | `javaw -jar oaagent.jar` | 시스템 트레이 아이콘 + 내부 Timer Heartbeat + WebSocket |
| **서비스 모드** | `java -jar oaagent.jar --service` | UI 없이 백그라운드 Heartbeat + WebSocket |
| **즉시 전송** | `java -jar oaagent.jar --send-now` | 1회 전송 후 종료 (Task Scheduler용) |

#### 설치/제거
- `install\install.bat` — Program Files에 복사 + 로그온 시 자동 시작 Task 등록
- `install\uninstall.bat` — Task 해제 + 파일 삭제 + 설정 삭제 옵션

#### 시스템 정보 수집 매핑

| # | 수집 항목 | Windows API | 비고 |
|---|----------|------------|------|
| 1 | CPU 사용률 | `com.sun.management.OperatingSystemMXBean.cpuLoad` / `Get-CimInstance Win32_Processor` | fallback 구조 |
| 2 | 전체 메모리 | `OperatingSystemMXBean.totalMemorySize` | Java Management API |
| 3 | 사용 메모리 | `totalMemorySize - freeMemorySize` | Java Management API |
| 4 | 전체 스토리지 | `File("C:\\").totalSpace` | C: 드라이브 기준 |
| 5 | 사용 스토리지 | `totalSpace - freeSpace` | C: 드라이브 기준 |
| 6 | 배터리 잔량 | `Get-CimInstance Win32_Battery` | 데스크탑은 -1 |
| 7 | 충전 여부 | `Win32_Battery.BatteryStatus` | 데스크탑은 true (AC) |
| 8 | 네트워크 타입 | `Get-NetAdapter` | WIFI / ETHERNET / UNKNOWN |
| 9 | IP 주소 | `NetworkInterface.getInetAddresses()` | IPv4 우선 |
| 10 | OS 버전 | `System.getProperty("os.name")` | 예: Windows 10 10.0 |
| 11 | 업타임 | `Get-CimInstance Win32_OperatingSystem` → `LastBootUpTime` | 시간 단위 |
| 12 | OS 상세 버전 | `Win32_OperatingSystem.Caption + BuildNumber` | 예: Windows 11 Pro (Build 26200) |
| 13 | 제조사 | `Get-CimInstance Win32_ComputerSystem` | 예: Dell, Lenovo |
| 14 | 모델명 | `Win32_ComputerSystem.Model` | 예: Latitude 5540 |
| 15 | 기기 사용자 | `System.getProperty("user.name")` | Windows 로그인 계정 |
| 16 | 자산 사용자명 | `WindowsPreferences.assetUserName` | 초기 설정 시 저장 |
| 17 | 사용자 사번 | `WindowsPreferences.employeeId` | 초기 설정 시 저장 |
| 18 | 에이전트 버전 | 코드 상수 `1.0.0` | 빌드 시 설정 |

### 7.4 macOS (✅ 구현)

| 항목 | 값 |
|------|-----|
| 기술 | KMP shared 모듈 (desktop 타겟) + Kotlin/JVM |
| 실행 모드 | 트레이 모드(기본) / `--service`(UI 없이 Heartbeat, launchd용) |
| 보안 저장 | 로그인 Keychain generic-password 항목 (access/refresh token + 개인 로그인 전환 표시, 비밀번호 미저장) |
| 시스템 정보 | `desktopMain` `SystemInfoCollector` 공용 (예: `pmset`으로 배터리, 시스템 빌드 번호) |
| 설치/제거 | `macos/install/install.sh`, `uninstall.sh` |


---

## 8. 보안

### 8.1 인증 토큰 저장

| 플랫폼 | 보안 저장소 | 암호화 방식 |
|--------|-----------|-----------|
| **Android** | EncryptedSharedPreferences | AES-256-GCM |
| **Windows** | `%APPDATA%\\OAAgent\\agent.dpapi` | Windows DPAPI `CurrentUser` 범위 (비밀번호 미저장) |
| **macOS** | 로그인 Keychain generic-password 항목 | macOS Keychain (비밀번호 미저장) |
| iOS (향후) | Keychain Services | Apple Secure Enclave |
| Linux (향후) | libsecret / 암호화 파일 | AES-256 |

> Windows/macOS 설치본은 access/refresh token과 개인 로그인 전환 표시만 OS 보안
> 저장소에 보관하며 비밀번호를 저장하지 않습니다. 이전 `agent.enc`는 안전하게
> 이관할 수 없어 업데이트 후 재로그인이 필요할 수 있습니다.

### 8.2 asset_uid 검증
- 클라이언트: `AgentConfig.ASSET_UID_REGEX` = `^[A-Za-z0-9_-]+$` (느슨한 문자 검사만)
- 서버 형식: `^([A-Z]{1,2}[0-9]{4,5}|(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|TP|ET|EH)[0-9]{5})$` (DB CHECK + `validate_asset_uid` 트리거, 두 형식 병행 — `docs/asset_uid_spec.md`)
- 서버: RPC 함수 내부에서 `WHERE asset_uid = p_asset_uid` → 존재하지 않으면 `RAISE EXCEPTION`

### 8.3 통신 암호화
- 모든 통신은 **HTTPS Only** (Supabase 기본 제공)
- Supabase anon key는 클라이언트에 포함됨 (공개값). URL·anon key는 `BUILDING.md`에 따라 빌드 시 CI 비밀 저장소에서 주입하며 저장소·`AgentConfig.kt`·설치본에 넣지 않음
- 익명 키만으로는 어떤 테이블·RPC·Storage에도 접근할 수 없음 (백엔드 README 5.0)
- access_token은 보안 저장소에만 저장, 로그 출력 금지

### 8.4 RPC 함수 권한
- 스키마 전체 `EXECUTE`를 회수한 뒤 필요한 RPC만 개별 GRANT
- `update_heartbeat`·`verify_user`·`confirm_assignment`: **현재 `authenticated` 실행 권한 없음** (§15 재도입 전까지 의도된 차단)
- `SECURITY DEFINER` + 고정 `search_path`, 내부에서 관리자 그룹 또는 해당 자산 담당자인지 재검증
- 공용 계정(`employee_id='agent'`)은 Auth 차단 + 모든 테이블 `legacy_agent_block` RESTRICTIVE 정책으로 차단

---

## 9. 검증 방법

### 9.1 백엔드 RPC 테스트
```sql
-- 현재 기대 결과: authenticated 역할로 호출 시 permission denied (의도된 차단)
SELECT update_heartbeat('D00001', '{"cpu_usage": 45.2, "memory_total_mb": 8192, "memory_used_mb": 5120}');

-- 재도입 후: 담당자/관리자 세션에서 호출 → 결과 확인
SELECT asset_uid, last_active_at, specifications->'device_status' AS device_status
FROM assets
WHERE asset_uid = 'D00001';
```

### 9.2 에이전트 수동 테스트 (재도입 후)
1. 자산 담당자 또는 관리자 개인 OA 계정으로 로그인
2. SetupActivity에서 `asset_uid` 입력 (예: `D00001`)
3. "즉시 전송" 버튼 클릭
4. DB에서 `last_active_at` 갱신, `specifications->'device_status'` 저장 확인

### 9.3 백그라운드 동작 테스트
1. "시작" 버튼으로 WorkManager 등록
2. 앱 종료 (최근 앱 목록에서 제거)
3. 15분 대기 후 DB에서 `last_active_at` 자동 갱신 확인
4. `adb shell dumpsys jobscheduler` 또는 WorkManager Inspector로 작업 상태 확인

### 9.4 프론트엔드 연동 테스트
1. 에이전트가 Heartbeat 전송 후 OA Manager 프론트엔드에서 해당 자산 조회
2. 접속현황 인디케이터가 **초록색(접속중)** 표시 확인
3. 에이전트 중단 → 60분 후 **연두색(1일전)** 전환 확인

### 9.5 장애 시나리오 테스트
| 시나리오 | 기대 동작 |
|----------|----------|
| 비행기 모드 ON | WorkManager 대기 (네트워크 제약) |
| 비행기 모드 OFF | 네트워크 복구 즉시 Heartbeat 전송 |
| 기기 재부팅 | BootReceiver → WorkManager 재등록 → 15분 내 전송 재개 |
| 잘못된 asset_uid | RPC 에러 → `Result.failure()` → 재시도 없음 |
| Supabase 서버 다운 | `Result.retry()` → 지수 백오프로 재시도 |
| 토큰 만료 | `AuthManager` 자동 갱신 → 갱신 실패 시 재로그인 |
| 공용 계정 세션 | 이전 공용 세션 토큰이 남아 있어도 자동 Heartbeat 재개하지 않음 → 개인 계정 재로그인 요청 |
| 사용자 확인 만료 | 확인 주기 도래 → 다음 앱 실행 시 확인 다이얼로그 표시 |
| 자산 배정 미확인 | `assignment_status = 'pending'` → 앱 실행 시 수령 확인 다이얼로그 표시 |

---

## 10. 서버 알림 (Realtime)

> 2026-06-04부터 FCM/Firebase를 사용하지 않습니다. 관리자·시스템 알림은 `notifications` 테이블 INSERT → Supabase Realtime `postgres_changes`로 에이전트에 전달됩니다 (구독 방식은 §14.5).

### 10.1 흐름
```
관리자 [자산 상세] "관리자 재확인 요청"  ─┐
마스터 관리자 user_name 변경 (트리거)     ├─→ notifications INSERT
재실사 요청 / 관리자 그룹의 직접 INSERT    ─┘        │
                                                 ▼ Realtime (private 채널 notifications:{asset_uid})
                                   에이전트 RealtimeManager → 시스템 알림 표시
```

### 10.2 DB 테이블 `notifications`

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | BIGINT (PK, auto) | 고유 식별자 |
| `asset_uid` | TEXT | 대상 자산 (NULL이면 전체) |
| `type` | TEXT | `os_update`, `security_alert`, `general`, `agent_update`, `recheck_request` |
| `title` | TEXT | 알림 제목 |
| `body` | TEXT | 알림 내용 |
| `sent_at` | TIMESTAMPTZ | 발송 시각 |
| `read_at` | TIMESTAMPTZ | 읽은 시각 (NULL이면 미읽음) |

- 조회: 관리자 그룹 또는 해당 자산 담당자만 (RLS)
- 생성: 관리자 그룹 (또는 서버 RPC/트리거)

### 10.3 알림 유형

| 유형 | 코드 | 발송 주체 |
|------|------|----------|
| OS 업데이트 | `os_update` | 관리자 |
| 보안 경고 | `security_alert` | 관리자 |
| 일반 공지 / 재확인 요청 | `general` | 관리자, `admin_force_verify`, 마스터 user_name 변경 트리거 |
| 버전 업데이트 | `agent_update` | 서버 |
| 재실사 요청 | `recheck_request` | `request_inspection_recheck` RPC |

> `device_tokens` 테이블은 레거시로 남아 있으나 에이전트는 더 이상 사용하지 않습니다.

---

## 11. 에이전트 버전 관리

### 11.1 개요

서버에서 최신 에이전트 버전을 관리하고, Heartbeat 응답 또는 별도 조회를 통해 에이전트가 자신의 버전과 비교하여 업데이트 필요 시 알림을 표시합니다.

### 11.2 DB 테이블

#### agent_settings

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `setting_key` | TEXT (PK) | 설정 키 |
| `setting_value` | TEXT | 설정 값 |
| `updated_at` | TIMESTAMPTZ | 갱신 시각 |

**초기 데이터:**

| setting_key | setting_value | 설명 |
|-------------|---------------|------|
| `latest_agent_version` | `1.0.0` | 최신 에이전트 버전 |
| `min_agent_version` | `1.0.0` | 최소 지원 버전 (미만 시 강제 업데이트) |
| `agent_download_url` | `https://...` | APK 다운로드 URL |

### 11.3 버전 확인 플로우

```
1. Heartbeat 전송 시 agent_version 포함 (p_system_info.agent_version)
2. Heartbeat 성공 후 → agent_settings 테이블에서 latest_agent_version 조회
   GET /rest/v1/agent_settings?setting_key=in.(latest_agent_version,min_agent_version)
3. 비교:
   - agent_version == latest_agent_version → 최신 (UI에 ✓ 표시)
   - agent_version < latest_agent_version → 업데이트 알림 표시
   - agent_version < min_agent_version → 강제 업데이트 (Heartbeat 전송은 계속)
4. 업데이트 알림 → 사용자가 다운로드 URL로 이동하여 수동 업데이트
```

### 11.4 Android 구현

```kotlin
// HeartbeatWorker.doWork() 내부 (Heartbeat 성공 후)
suspend fun checkVersion() {
    val currentVersion = BuildConfig.VERSION_NAME
    val settings = client.getAgentSettings(token) // agent_settings 조회
    val latestVersion = settings["latest_agent_version"]
    val minVersion = settings["min_agent_version"]

    if (compareVersions(currentVersion, latestVersion) < 0) {
        // 업데이트 필요 → 알림 표시
        showUpdateNotification(latestVersion, settings["agent_download_url"])
    }
    if (compareVersions(currentVersion, minVersion) < 0) {
        // 강제 업데이트 필요 → 경고 알림
        showForceUpdateNotification(minVersion, settings["agent_download_url"])
    }
}
```

---

## 12. 사용자 확인

### 12.1 개요

서버에서 설정한 주기(기본 30일)마다 에이전트 사용자가 본인의 이름과 사번을 입력하여 DB에 등록된 정보와 일치하는지 확인합니다.

### 12.2 확인 주기 설정

| 항목 | 값 |
|------|-----|
| 설정 위치 | `access_settings` 테이블 |
| 설정 키 | `verification_interval_days` |
| 기본값 | `30` (일) |
| 변경 | 관리자가 프론트엔드에서 변경 가능 |

### 12.3 확인 플로우

```
1. 앱 실행 시 확인 필요 여부 판단
   - last_verified_at + verification_interval_days ≤ now() → 확인 필요
   - last_verified_at IS NULL → 최초 확인 필요

2. 확인 다이얼로그 표시
   ┌──────────────────────────────┐
   │      사용자 확인               │
   ├──────────────────────────────┤
   │                              │
   │  현재 사용자 정보를 확인합니다.  │
   │                              │
   │  이름                         │
   │  ┌────────────────────────┐  │
   │  │ 김개발                  │  │
   │  └────────────────────────┘  │
   │                              │
   │  사번                         │
   │  ┌────────────────────────┐  │
   │  │ EMP20001               │  │
   │  └────────────────────────┘  │
   │                              │
   │       ┌──────────┐          │
   │       │   확 인    │          │
   │       └──────────┘          │
   └──────────────────────────────┘

3. 서버 검증 (RPC: verify_user)
   POST /rest/v1/rpc/verify_user
   { "p_asset_uid": "D00001", "p_user_name": "김개발", "p_employee_id": "EMP20001" }

4. 응답 처리
   - 일치 → "확인 완료" 메시지, last_verified_at 갱신, verification_status = 'verified'
   - 불일치 → 경고 표시
```

### 12.4 RPC 함수 `verify_user`

> 정의·권한: 백엔드 README 9.6 (`20260816000000_security_hardening.sql`). ⛔ 현재 `authenticated` 실행 권한 없음.

| 항목 | 내용 |
|------|------|
| 파라미터 | `p_asset_uid`, `p_user_name`, `p_employee_id` |
| 내부 권한 검사 | 관리자 그룹 또는 해당 자산 담당자 |
| 비교 기준 | `assets.user_name` + `assets.user_employee_id` (2026-06-05부터 users 테이블 우회 조회 제거). NULL은 불일치 |
| 결과 | `verification_status` = `verified` / `mismatch`, `last_verified_at = now()` |
| 반환 | `{ matched, message, verified_at }` |

### 12.5 불일치 시 경고 UI

```
┌──────────────────────────────┐
│      ⚠ 사용자 불일치          │
├──────────────────────────────┤
│                              │
│  기존 사용자와 다른 사용자입니다. │
│  OA관리부서에 문의하세요.       │
│                              │
│  확인 일시: 2026-03-14 10:30  │
│                              │
│         ┌──────────┐        │
│         │   확 인    │        │
│         └──────────┘        │
└──────────────────────────────┘
```

> **에이전트 동작**: 불일치 시에도 Heartbeat 전송은 계속됩니다. DB의 `verification_status`가 `'mismatch'`로 저장되어 프론트엔드 관리 화면에서 경고 표시됩니다.

### 12.6 assets 테이블 추가 컬럼

| 컬럼 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `last_verified_at` | TIMESTAMPTZ | NULL | 마지막 사용자 확인 시각 |
| `verification_status` | TEXT | NULL | 확인 상태 (`verified`, `mismatch`, NULL=미확인) |

---

## 13. 자산 배정 수령 확인

### 13.1 개요

관리자가 프론트엔드에서 자산을 사용자에게 배정한 후, 에이전트 앱에서 실제 사용자가 본인 이름을 입력하여 수령을 확인합니다.

### 13.2 배정 플로우

```
1. 관리자: 프론트엔드에서 자산 배정 (assets.user_name 변경)
   → assets.assignment_status = 'pending'
   → assets.assignment_confirmed_at = NULL

2. 에이전트: 앱 실행 또는 Heartbeat 시 assignment_status 확인
   GET /rest/v1/assets?asset_uid=eq.D00001&select=assignment_status,user_name

3. assignment_status = 'pending' → 수령 확인 다이얼로그 표시
   ┌──────────────────────────────┐
   │      자산 수령 확인            │
   ├──────────────────────────────┤
   │                              │
   │  이 자산이 배정되었습니다.      │
   │  수령을 확인하려면             │
   │  본인 이름을 입력하세요.        │
   │                              │
   │  배정 사용자: 김개발           │  ← DB의 user_name 표시
   │                              │
   │  이름 입력                    │
   │  ┌────────────────────────┐  │
   │  │ 김개발                  │  │
   │  └────────────────────────┘  │
   │                              │
   │       ┌──────────┐          │
   │       │  수령 확인 │          │
   │       └──────────┘          │
   └──────────────────────────────┘

4. 서버 검증 (RPC: confirm_assignment)
   POST /rest/v1/rpc/confirm_assignment
   { "p_asset_uid": "D00001", "p_user_name": "김개발" }

5. 응답 처리
   - 이름 일치 → assignment_status = 'confirmed', assignment_confirmed_at = now()
   - 이름 불일치 → 에러 메시지 "배정된 사용자 이름과 일치하지 않습니다."
```

### 13.3 RPC 함수 `confirm_assignment`

> 정의·권한: 백엔드 README 9.6. ⛔ 현재 `authenticated` 실행 권한 없음.

| 항목 | 내용 |
|------|------|
| 파라미터 | `p_asset_uid`, `p_user_name` |
| 내부 권한 검사 | 관리자 그룹 또는 해당 자산 담당자 |
| 동작 | `assignment_status = 'pending'`이고 `assets.user_name`과 이름이 같으면 `confirmed` + `assignment_confirmed_at = now()` |
| 반환 | `{ success, message, confirmed_at? }` |

### 13.4 assets 테이블 추가 컬럼

| 컬럼 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `assignment_status` | TEXT | NULL | 배정 상태 (`pending`, `confirmed`, NULL=배정 없음) |
| `assignment_confirmed_at` | TIMESTAMPTZ | NULL | 수령 확인 시각 |

> **관리자 프론트엔드**: 자산 배정 시 `assignment_status = 'pending'`으로 설정. 프론트엔드 자산 목록에서 수령 미확인(`pending`) 자산을 필터링하여 관리 가능.

---

## 14. Supabase Realtime 연동

### 14.1 개요

에이전트는 Supabase Realtime (Phoenix Channels over WebSocket)을 통해 프론트엔드와 **실시간 양방향 통신**을 수행합니다.
기존 Heartbeat (주기적 HTTP POST)와 독립적으로 동작하며, 상시 WebSocket 연결을 유지합니다.

| 기능 | 유형 | 방향 | 설명 |
|------|------|------|------|
| Presence | Presence | 에이전트 → 프론트엔드 | 에이전트 실시간 접속 상태 공유 |
| 관리자 명령 수신 | Broadcast | 프론트엔드 → 에이전트 | 즉시 Heartbeat, 시스템 정보 갱신 등 |

> 모든 Realtime 채널은 인증된 **private** 채널입니다. 에이전트는 자신에게
> 배정된 자산의 명령·알림만 구독하며, 전역 알림 Broadcast를 발신하거나 구독하지
> 않습니다.

> **Heartbeat와의 관계**: WebSocket은 상시 연결, Heartbeat는 주기적 HTTP POST. 두 채널은 독립 동작합니다.
> `request_heartbeat` 명령 수신 시 기존 `update_heartbeat` RPC를 즉시 호출합니다.

### 14.2 채널 구성

| 채널명 | 유형 | 방향 | 용도 |
|--------|------|------|------|
| `agent-presence:global` | Presence | 에이전트 → 관리자/운영자 | 최소 접속 상태(`asset_uid`만) 공유 |
| `agent-commands:{asset_uid}` | Broadcast | 프론트엔드 → 에이전트 | 관리자 → 특정 기기 명령 전송 |
| `notifications:{asset_uid}` | **postgres_changes** | 서버(DB INSERT) → 에이전트 | `notifications` 테이블 INSERT 수신 (관리자 재확인 요청 등) |

### 14.3 Presence 상태 등록

에이전트 시작 시 `agent-presence:global` 채널에 참여하여 접속 상태를 공유합니다.

**Presence 상태 데이터:**
```json
{
  "asset_uid": "D00001"
}
```

- private Presence join 권한은 해당 자산이 배정된 개인 계정 또는 관리자/운영자만
  가집니다. 전역 채널 특성상 추가 사용자·기기 정보를 넣지 않습니다.
- 채널 참여 → Supabase Realtime이 자동으로 `join` 이벤트 발생 → 프론트엔드에서 감지
- 연결 해제 (앱 종료, 네트워크 끊김) → 자동 `leave` 이벤트 발생
- 프론트엔드는 `sync` 이벤트로 전체 접속 목록을 갱신

### 14.4 명령 수신 (Broadcast)

에이전트는 자신의 `asset_uid`에 해당하는 `agent-commands:{asset_uid}` 채널을 구독합니다.

**명령 메시지 포맷:**
```json
{
  "command": "request_heartbeat",
  "requested_by": "admin@oamanager.internal",
  "requested_at": "2026-03-14T09:05:00Z",
  "params": {}
}
```

| command | 처리 |
|---------|------|
| `request_heartbeat` | 즉시 `update_heartbeat` RPC 호출 (기존 HeartbeatWorker와 동일 로직) |
| `refresh_system_info` | 시스템 정보 즉시 수집 후 `update_heartbeat` RPC 호출 |

### 14.5 서버 발생 알림 수신 (Postgres Changes) — 2026-06-04 추가

`notifications` 테이블이 Supabase Realtime publication에 등록되어 있어, INSERT 이벤트를 에이전트가 즉시 수신합니다 (Firebase/FCM 미사용).

**구독 (Phoenix `phx_join` payload):**
```json
{
  "config": {
    "postgres_changes": [
      {
        "event": "INSERT",
        "schema": "public",
        "table": "notifications",
        "filter": "asset_uid=eq.<자기 자산>"
      }
    ]
  }
}
```

**수신 이벤트 본문:**
```json
{
  "data": {
    "type": "INSERT",
    "table": "notifications",
    "record": {
      "id": 12, "asset_uid": "D00001",
      "type": "general",
      "title": "사용자 재확인 요청",
      "body": "관리자 요청으로 사용자 확인이 초기화되었습니다. 에이전트 앱에서 다시 확인을 진행해주세요.",
      "sent_at": "2026-06-04T09:38:59Z"
    }
  }
}
```

**Android 측 처리** ([HeartbeatForegroundService.kt](android/app/src/main/java/com/oamanager/agent/android/service/HeartbeatForegroundService.kt))
- 알림 채널 `admin_alert_channel` (IMPORTANCE_HIGH) 추가
- `showAdminAlert(title, body)` → `NotificationManager.notify(...)` 로 시스템 트레이 알림 표시 (BigTextStyle, AutoCancel)
- 탭하면 `SetupActivity`로 이동

**발생 경로**
- 관리자 [자산 상세] → "관리자 재확인 요청" 버튼 (`admin_force_verify` RPC)
- 마스터 관리자가 자산의 `user_name` 변경 → BEFORE UPDATE 트리거 자동 발생
- 백엔드 README §4.10, §9.9.1, §9.9.2 참조

### 14.6 연결 관리

#### WebSocket 연결
- **URL**: `wss://apioa.terraforming.info/realtime/v1/websocket?apikey=<ANON_KEY>`
- **인증**: 연결 시 `access_token` 전달 (Phoenix Channel `join` 메시지 payload)
- **프로토콜**: Phoenix Channels v1 (JSON 인코딩)

#### Phoenix Heartbeat
- 30초 간격으로 Phoenix heartbeat 메시지 전송 (WebSocket keepalive)
- Supabase Realtime 서버가 응답하지 않으면 연결 끊김 감지

#### 자동 재연결
- WebSocket 끊김 → 지수 백오프로 재연결 시도 (5초 → 10초 → 20초 → max 60초)
- 재연결 성공 → 모든 채널 자동 재참여 + Presence 상태 재등록
- 토큰 만료 시 → `AuthManager`로 토큰 갱신 후 재연결

#### 네트워크 복구
- `ConnectivityManager` 콜백으로 네트워크 상태 감시
- 네트워크 복구 시 → WebSocket 즉시 재연결 시도

### 14.7 RealtimeManager 구현 (`shared/commonMain`)

```kotlin
// shared/src/commonMain/kotlin/com/oamanager/agent/network/RealtimeManager.kt

class RealtimeManager(
    private val config: AgentConfig,
    private val authManager: AuthManager
) {
    private var webSocket: WebSocketSession? = null
    private var heartbeatJob: Job? = null
    private var reconnectAttempt = 0

    // 연결 상태
    enum class ConnectionState { DISCONNECTED, CONNECTING, CONNECTED }
    val connectionState: StateFlow<ConnectionState>

    // WebSocket 연결
    suspend fun connect()

    // 채널 참여
    suspend fun joinPresence(assetUid: String)               // payload는 asset_uid만 (최소 정보)
    suspend fun joinNotificationsChannel(assetUid: String)  // 2026-06-04 추가
    // joinAlertChannel() / sendAlert() 는 제거됨 — 전역 알림 발신 없음
    suspend fun joinCommandChannel(assetUid: String)

    // 명령 수신 콜백
    fun onCommand(handler: (command: String, params: JsonObject) -> Unit)

    // 연결 종료
    suspend fun disconnect()

    // Phoenix heartbeat (30초 간격)
    private suspend fun startPhoenixHeartbeat()

    // 자동 재연결 (지수 백오프)
    private suspend fun reconnectWithBackoff()
}
```

### 14.8 Android 세부 구현

#### ForegroundService 통합
- 기존 `HeartbeatForegroundService` (5분 주기) 내에서 `RealtimeManager` 초기화
- 서비스 시작 → `realtimeManager.connect()` + 채널 참여
- 서비스 종료 → `realtimeManager.disconnect()`

#### 15분/30분 주기 모드
- WorkManager 기반 Heartbeat에서는 WebSocket 상시 연결이 어려움
- 별도 `RealtimeService` (Foreground Service) 추가 검토 또는 ForegroundService 통합 운영

#### 명령 처리 플로우
```
WebSocket 명령 수신
  → onCommand 콜백 실행
  → command == "request_heartbeat"
    → SystemInfoCollector.collect()
    → SupabaseClient.updateHeartbeat(payload)
    → (기존 HeartbeatWorker와 동일한 로직)
```

#### 상태 변화 전달
- 배터리·네트워크 등 자산 상태는 기존 인증된 Heartbeat RPC에 포함해 전송합니다.
- 에이전트가 전역 Broadcast로 상태나 개인정보를 발신하지 않습니다.

#### 서버 알림 수신 트리거 (2026-06-04 추가)
```
realtimeManager.joinNotificationsChannel(assetUid)
  → postgres_changes(INSERT, public.notifications, asset_uid=eq.X)
    → handleMessage() → notificationHandler(record)
      → HeartbeatForegroundService.showAdminAlert(title, body)
        → NotificationManager.notify (admin_alert_channel, IMPORTANCE_HIGH)
```

---

## 15. 에이전트 재도입 설계 (보안 실행서 §4)

공용 계정 방식은 폐기되었으며, 다음 조건을 모두 갖춘 뒤에만 에이전트 RPC 실행 권한을 다시 부여합니다.

1. 자산마다 고유한 `auth.users` 신원 또는 일회용 등록 토큰을 발급한다.
2. 등록 시 서버가 해당 신원과 **정확히 하나의 `asset_uid`**를 매핑한다. 에이전트가 임의 자산번호를 주장하는 방식은 허용하지 않는다.
3. 기기 비밀은 Android Keystore·Windows DPAPI·macOS Keychain 등 플랫폼 보안 저장소에 보관하고, APK·저장소·배포 스크립트에 공용 비밀번호를 넣지 않는다.
4. heartbeat/사용자 확인/수령 확인은 이 매핑을 서버에서 검증하는 전용 RPC 또는 Edge Function으로 다시 구현한다. 성공 전에는 해당 RPC의 `authenticated` 실행 권한을 부여하지 않는다.
5. 기기별 알림 구독도 매핑된 자산의 알림만 읽도록 RLS를 분리한다.
6. 새 keystore로 앱 서명 키를 교체하고 CI 비밀 저장소로 이관한다 (아래 "Android 릴리스 서명"). 기존 공용 APK 계정과 서명 키는 폐기한다.

> 그 전까지 현재 구현(개인 계정 로그인)은 Realtime 명령·알림 수신 경로만 의미가 있으며, 데이터 갱신 RPC는 서버에서 거부됩니다.

---

## Android 릴리스 서명

릴리스 APK/AAB는 저장소에 없는 서명 정보를 주입한 환경에서만 생성합니다. 다음 네 개의 값을 CI 비밀 저장소 또는 배포 담당자의 `~/.gradle/gradle.properties`에 보관하고, `-P` Gradle 속성 또는 동일한 이름의 환경 변수로 제공합니다.

- `OA_AGENT_SIGNING_STORE_FILE`
- `OA_AGENT_SIGNING_STORE_PASSWORD`
- `OA_AGENT_SIGNING_KEY_ALIAS`
- `OA_AGENT_SIGNING_KEY_PASSWORD`

값 중 하나라도 없으면 릴리스 산출물 작업은 시작 전에 실패합니다. 키스토어, 비밀번호, 별칭은 저장소·문서·빌드 로그에 넣지 않습니다.

---

## 변경 이력 (에이전트)

- `2026-10-11` : 명세를 실제 코드·보안 실행서 기준으로 정비 — FCM 섹션 제거(Realtime 알림으로 대체), macOS 에이전트 추가, SystemInfo 26개 필드, AndroidManifest 실제값, 에이전트 RPC 현재 차단 상태와 재도입 설계(§15), asset_uid 현재 형식
- `2026-08` : 공용 에이전트 계정 폐기 → 개인 OA 계정 로그인, 보안 저장소(Android Keystore/DPAPI/Keychain)로 토큰만 저장, 빌드 시 URL·anon key 주입(`BUILDING.md`), 전역 알림 Broadcast 발신 제거, Presence 최소 정보(`asset_uid`)
- `2026-06-14` : SystemInfo에 MAC·시리얼·전화번호·보안 패치 필드 추가 (서버가 MAC을 자산 마스터로 동기화)
- `2026-06-04` :
  - `RealtimeManager.kt`
    - `joinNotificationsChannel(assetUid)` — postgres_changes 구독
    - `onNotification(handler)` — INSERT 콜백 등록
    - `handleMessage()`에 `postgres_changes` 이벤트 분기 추가
  - `HeartbeatForegroundService.kt`
    - Realtime 연결 setup에 `joinNotificationsChannel` 호출 추가
    - `ALERT_CHANNEL_ID = "admin_alert_channel"` 신규 채널 + `showAdminAlert()` 헬퍼
  - `AgentConfig.SUPABASE_URL` → `https://apioa.terraforming.info` (이전 `https://api.oa.terraforming.info`)
  - APK 재빌드 (Android, Release, 3.2 MB, versionCode=1, versionName=1.0.0)
  - README placeholder URL 일괄 치환 (`<project-id>.supabase.co` → `apioa.terraforming.info`)
- `2026-03-21` 이전 : 초기 구현 (Heartbeat, verify_user, confirm_assignment, Realtime Presence/Broadcast)

---

## 문의
프로젝트 관련 문의사항은 개발팀에 문의해주세요.
