# OA Manager v1 - 에이전트 명세서

## ⚠️ 중요 사항
> **본 문서는 OA 자산관리 시스템의 에이전트(기기 모니터링) 개발 명세서입니다.**
> **백엔드 명세서(`OA_backend/README.md`)의 DB 스키마 및 RPC 함수와 반드시 동기화하여 관리합니다.**
> **프론트엔드 명세서(`OA_frontend/README.md`)의 접속현황 인디케이터 로직을 참조합니다.**
> **Heartbeat 프로토콜 및 시스템 정보 수집 항목 변경 시 모든 플랫폼 에이전트에 동시 반영이 필요합니다.**

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
| Heartbeat 전송 | 사용자 설정 주기(5분/15분/30분)로 `last_active_at` 갱신하여 접속 상태 실시간 반영 |
| 시스템 모니터링 | CPU, 메모리, 스토리지, 배터리, 네트워크, 제조사, 모델명 등 18개 항목 수집 |
| FCM 푸시 알림 | 관리자가 프론트엔드에서 발송한 알림(OS 업데이트 등)을 기기에서 수신/표시 |
| 사용자 확인 | 서버 설정 주기(기본 30일)마다 사용자 이름+사번 입력 → DB 대조 검증 |
| 자산 수령 확인 | 자산 배정 후 사용자가 이름 입력하여 수령 확인 완료 |
| 에이전트 버전 관리 | 서버에서 최신 버전 비교 → 구버전 시 업데이트 알림 |
| 자동 재시작 | 기기 재부팅, 앱 종료 후에도 자동으로 Heartbeat 재개 |
| 보안 저장 | 인증 토큰, 자산 식별자를 플랫폼별 보안 저장소에 암호화 저장 |
| Realtime 연동 | Supabase Realtime (WebSocket) 기반 실시간 양방향 통신 — Presence 상태 공유, 관리자 명령 수신, 알림 발신 |
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
| 인증 | **Supabase Auth** (JWT, email/password) |
| 실시간 통신 | **Supabase Realtime** (Phoenix Channels over WebSocket) |
| 푸시 알림 | **Firebase Cloud Messaging (FCM)** |

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
| iOS | 향후 | iPhone, iPad | Background App Refresh |
| Linux | 향후 | 서버, 데스크탑 | systemd service |
| Windows | 향후 | 데스크탑, 노트북 | Windows Service |

---

## 2. 폴더 구조

### 2.1 전체 디렉토리 트리
```
Agent/
├── README.md                                  ← 본 문서 (공통 명세)
├── build.gradle.kts                           ← 루트 빌드 파일
├── settings.gradle.kts                        ← 모듈 설정 (shared, android)
├── gradle.properties                          ← Gradle 속성
├── gradle/
│   └── wrapper/
│       └── gradle-wrapper.properties
├── shared/                                    ← KMP 공유 모듈
│   ├── build.gradle.kts
│   └── src/
│       ├── commonMain/kotlin/com/oamanager/agent/
│       │   ├── model/
│       │   │   ├── HeartbeatPayload.kt        ← 3.1 Heartbeat 페이로드 모델
│       │   │   └── SystemInfo.kt              ← 3.2 시스템 정보 모델
│       │   ├── network/
│       │   │   ├── SupabaseClient.kt          ← 4.1 Ktor 기반 HTTP 클라이언트
│       │   │   ├── AuthManager.kt             ← 4.2 토큰 관리
│       │   │   └── RealtimeManager.kt         ← 14.7 Supabase Realtime WebSocket 연결
│       │   └── AgentConfig.kt                 ← 공통 설정 (URL, 주기 등)
│       └── androidMain/kotlin/com/oamanager/agent/
│           └── platform/
│               └── SystemInfoCollector.kt     ← 6.5 Android 시스템 정보 수집
├── android/                                   ← Android 에이전트 앱
│   ├── README.md                              ← Android 전용 참고사항
│   ├── app/
│   │   ├── build.gradle.kts
│   │   └── src/main/
│   │       ├── AndroidManifest.xml            ← 6.2 권한 및 컴포넌트 선언
│   │       ├── java/com/oamanager/agent/android/
│   │       │   ├── OAAgentApp.kt              ← 6.3.1 Application 클래스
│   │       │   ├── ui/
│   │       │   │   ├── SetupActivity.kt       ← 6.3.3 초기 설정 화면
│   │       │   │   └── SetupViewModel.kt      ← 6.3.3 ViewModel
│   │       │   ├── worker/
│   │       │   │   └── HeartbeatWorker.kt     ← 6.3.2 WorkManager Worker
│   │       │   ├── data/
│   │       │   │   └── AgentPreferences.kt    ← 6.3.4 보안 저장소
│   │       │   └── receiver/
│   │       │       └── BootReceiver.kt        ← 6.3.7 부팅 시 재등록
│   │       └── res/
│   │           ├── layout/
│   │           │   └── activity_setup.xml     ← 6.7 설정 화면 레이아웃
│   │           ├── values/
│   │           │   └── strings.xml
│   │           └── drawable/
│   │               └── ic_notification.xml    ← 알림 아이콘
│   └── build.gradle.kts
├── ios/                                       ← (향후)
├── linux/                                     ← (향후)
└── windows/                                   ← (향후)
```

---

## 3. 공통 데이터 모델

### 3.1 HeartbeatPayload

에이전트가 서버로 전송하는 Heartbeat 페이로드 구조입니다.

```json
{
  "p_asset_uid": "BDT00001",
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
| `p_asset_uid` | text | **필수** | OA 자산 고유 식별자 (정규식: `^(B\|R\|C\|L\|S)(DT\|NB\|MN\|PR\|TB\|SC\|IP\|NW\|SV\|WR\|SD)[0-9]{5}$`) |
| `p_system_info` | jsonb | **필수** | 시스템 모니터링 정보 (18개 필드) |

### 3.2 SystemInfo

시스템 모니터링 수집 항목입니다. 모든 플랫폼에서 동일한 **18개 필드**를 수집합니다.

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
)
```

---

## 4. 네트워크 프로토콜

### 4.1 엔드포인트 목록
| 순서 | 엔드포인트 | 메서드 | 용도 | 인증 |
|------|-----------|--------|------|------|
| 1 | `/auth/v1/token?grant_type=password` | POST | 로그인 (email/password) | anon key |
| 2 | `/auth/v1/token?grant_type=refresh_token` | POST | 토큰 갱신 | anon key |
| 3 | `/rest/v1/rpc/update_heartbeat` | POST | Heartbeat 전송 | Bearer token |
| 4 | `/rest/v1/rpc/verify_user` | POST | 사용자 확인 (이름+사번 검증) | Bearer token |
| 5 | `/rest/v1/rpc/confirm_assignment` | POST | 자산 수령 확인 | Bearer token |
| 6 | `/rest/v1/device_tokens` | POST/PATCH | FCM 토큰 등록/갱신 | Bearer token |
| 7 | `/rest/v1/agent_settings?setting_key=in.(latest_agent_version,min_agent_version)` | GET | Heartbeat 성공 후 에이전트 버전 확인 (11.3절 참조) | Bearer token |
| 8 | `wss://<project-id>.supabase.co/realtime/v1/websocket` | WebSocket | Supabase Realtime 연결 (Presence, Broadcast) | Bearer token |

### 4.2 인증 방식

에이전트 전용 서비스 계정을 사용합니다.

| 항목 | 값 |
|------|-----|
| 계정 | `agent@oamanager.internal` |
| 역할 | `authenticated` (Supabase Auth) |
| 권한 | `update_heartbeat` RPC 호출만 가능 |
| 토큰 저장 | 플랫폼별 보안 저장소 (8.1 참조) |
| 토큰 만료 | 3600초 (1시간), 자동 갱신 |

> **보안**: 에이전트 계정은 `is_admin = false`이며, RPC 함수를 통해 `last_active_at`과 `specifications.device_status`만 변경 가능합니다. 다른 테이블/컬럼 접근 불가.

**인증 플로우:**
```
1. 앱 시작 → 저장된 refresh_token 확인
2. refresh_token 있음 → /auth/v1/token?grant_type=refresh_token 호출
3. refresh_token 없음/만료 → /auth/v1/token?grant_type=password 호출
4. access_token + refresh_token 보안 저장소에 저장
5. Heartbeat 전송 시 Authorization: Bearer <access_token> 헤더 사용
6. 401 응답 → refresh_token으로 자동 갱신 후 재시도
```

### 4.3 Heartbeat 요청/응답 예시

**요청:**
```http
POST /rest/v1/rpc/update_heartbeat HTTP/1.1
Host: <project-id>.supabase.co
Authorization: Bearer <access_token>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json

{
  "p_asset_uid": "BDT00001",
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
  "message": "asset not found: BDT99999"
}
```

---

## 5. 백엔드 연동

### 5.1 RPC 함수 `update_heartbeat`

> 마이그레이션 파일: `OA_backend/supabase/migrations/20260314000002_add_agent_rpc_and_columns.sql`

```sql
CREATE OR REPLACE FUNCTION public.update_heartbeat(
  p_asset_uid text,
  p_system_info jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.assets
  SET
    last_active_at = now(),
    specifications = CASE
      WHEN p_system_info IS NOT NULL
      THEN jsonb_set(COALESCE(specifications, '{}'), '{device_status}', p_system_info)
      ELSE specifications
    END
  WHERE asset_uid = p_asset_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'asset not found: %', p_asset_uid;
  END IF;
END;
$$;

-- 권한: authenticated 역할만 호출 가능
REVOKE ALL ON FUNCTION public.update_heartbeat(text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_heartbeat(text, jsonb) TO authenticated;
```

| 항목 | 설명 |
|------|------|
| 함수명 | `update_heartbeat` |
| 파라미터 | `p_asset_uid` (text, 필수), `p_system_info` (jsonb, 선택) |
| 반환 | void |
| 보안 | `SECURITY DEFINER` (RLS 우회하여 직접 UPDATE) |
| 권한 | `authenticated` 역할만 `EXECUTE` 가능 |
| 동작 | `last_active_at = now()` 갱신 + `specifications.device_status` JSONB 병합 |
| 에러 | 존재하지 않는 `asset_uid` → `RAISE EXCEPTION` |

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
| `POST_NOTIFICATIONS` | Android 13+ 알림 권한 (FCM + 포그라운드 서비스) | **필수** |

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.oamanager.agent">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application
        android:name=".OAAgentApp"
        android:label="OA Agent"
        android:icon="@mipmap/ic_launcher"
        android:allowBackup="false">

        <activity
            android:name=".ui.SetupActivity"
            android:exported="true"
            android:label="OA Agent 설정">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <!-- FCM 메시징 서비스 -->
        <service
            android:name=".fcm.OAFirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>

        <!-- 5분 주기 Heartbeat용 포그라운드 서비스 -->
        <service
            android:name=".service.HeartbeatForegroundService"
            android:exported="false"
            android:foregroundServiceType="dataSync" />

        <receiver
            android:name=".receiver.BootReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
            </intent-filter>
        </receiver>

    </application>
</manifest>
```

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
    var fcmToken: String?           // FCM 디바이스 토큰
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
| `fcm_token` | AES-256 | FCM 디바이스 토큰 |

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
│  │ BDT00001               │  │  ← EditText (정규식 실시간 검증)
│  └────────────────────────┘  │
│  ⚠ 형식: [B|R|C|L|S][유형코드]  │  ← 도움말 텍스트
│     [5자리 숫자]              │
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
│  자산 번호: BDT00001         │
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
| 정규식 | `^(B\|R\|C\|L\|S)(DT\|NB\|MN\|PR\|TB\|SC\|IP\|NW\|SV\|WR\|SD)[0-9]{5}$` |
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

## 7. 향후 플랫폼

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

### 7.3 Windows (향후)
| 항목 | 계획 |
|------|------|
| 기술 | KMP shared 모듈 + JVM/Native |
| 스케줄링 | Windows Task Scheduler 또는 Windows Service |
| HTTP | Ktor Client (WinHttp 엔진) |
| 보안 저장 | Windows Credential Manager (DPAPI) |
| 시스템 정보 | WMI (Windows Management Instrumentation) |

---

## 8. 보안

### 8.1 인증 토큰 저장

| 플랫폼 | 보안 저장소 | 암호화 방식 |
|--------|-----------|-----------|
| **Android** | EncryptedSharedPreferences | AES-256-GCM |
| iOS (향후) | Keychain Services | Apple Secure Enclave |
| Linux (향후) | libsecret / 암호화 파일 | AES-256 |
| Windows (향후) | Credential Manager | DPAPI |

### 8.2 asset_uid 검증
- 클라이언트: 정규식 `^(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD)[0-9]{5}$`로 형식 검증
- 서버: RPC 함수 내부에서 `WHERE asset_uid = p_asset_uid` → 존재하지 않으면 `RAISE EXCEPTION`

### 8.3 통신 암호화
- 모든 통신은 **HTTPS Only** (Supabase 기본 제공)
- Supabase anon key는 APK에 포함 (RLS로 보호되므로 공개 가능)
- access_token은 보안 저장소에만 저장, 로그 출력 금지

### 8.4 RPC 함수 권한
- `REVOKE ALL FROM PUBLIC` → 기본 접근 차단
- `GRANT EXECUTE TO authenticated` → 인증된 사용자만 호출 가능
- `SECURITY DEFINER` → RPC 내부에서만 assets 테이블 직접 UPDATE
- 에이전트 계정은 `is_admin = false` → 관리자 기능 접근 불가

---

## 9. 검증 방법

### 9.1 백엔드 RPC 테스트
```sql
-- Supabase SQL Editor에서 실행
SELECT update_heartbeat('BDT00001', '{"cpu_usage": 45.2, "memory_total_mb": 8192, "memory_used_mb": 5120}');

-- 결과 확인
SELECT asset_uid, last_active_at, specifications->'device_status' AS device_status
FROM assets
WHERE asset_uid = 'BDT00001';
```

### 9.2 에이전트 수동 테스트
1. SetupActivity에서 `asset_uid` 입력 (예: `BDT00001`)
2. "즉시 전송" 버튼 클릭
3. DB에서 `last_active_at` 갱신 확인
4. `specifications->'device_status'`에 시스템 정보 저장 확인

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
| FCM 토큰 갱신 | 새 토큰 발급 → `device_tokens` 테이블 자동 업데이트 |
| 사용자 확인 만료 | 확인 주기 도래 → 다음 앱 실행 시 확인 다이얼로그 표시 |
| 자산 배정 미확인 | `assignment_status = 'pending'` → 앱 실행 시 수령 확인 다이얼로그 표시 |

---

## 10. FCM 푸시 알림

### 10.1 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│  OA Manager 프론트엔드 (관리자)                                   │
│  "OS 업데이트 알림 발송" 버튼 클릭                                 │
└──────────────────┬──────────────────────────────────────────────┘
                   │ POST /functions/v1/send-notification
                   ▼
┌─────────────────────────────────────────────────────────────────┐
│  Supabase Edge Function (send-notification)                      │
│  1. device_tokens 테이블에서 대상 기기 FCM 토큰 조회               │
│  2. Firebase Admin SDK로 FCM 메시지 발송                          │
│  3. notifications 테이블에 발송 이력 저장                          │
└──────────────────┬──────────────────────────────────────────────┘
                   │ FCM (Firebase Cloud Messaging)
                   ▼
┌─────────────────────────────────────────────────────────────────┐
│  에이전트 기기 (OAFirebaseMessagingService)                       │
│  1. 푸시 알림 수신                                               │
│  2. NotificationManager로 알림 표시                              │
│  3. 알림 클릭 → SetupActivity에서 상세 내용 확인                   │
└─────────────────────────────────────────────────────────────────┘
```

### 10.2 Firebase 프로젝트 설정

| 항목 | 값 |
|------|-----|
| Firebase 프로젝트 | OA Manager 프로젝트에 Android 앱 등록 |
| 패키지명 | `com.oamanager.agent` |
| `google-services.json` | `android/app/` 디렉토리에 배치 |
| FCM API | Firebase Cloud Messaging API (V1) 활성화 |
| 서버 키 | Supabase Edge Function 환경변수로 설정 (`FIREBASE_SERVICE_ACCOUNT_KEY`) |

**의존성 추가 (app/build.gradle.kts):**

| 그룹 | 아티팩트 | 버전 | 용도 |
|------|---------|------|------|
| `com.google.firebase` | `firebase-messaging-ktx` | 23.4.1 | FCM 수신 |
| `com.google.firebase` | `firebase-bom` | 32.7.1 | Firebase BoM |

### 10.3 FCM 토큰 등록

에이전트가 시작될 때 FCM 토큰을 서버에 등록합니다.

```kotlin
// android/app/src/main/java/com/oamanager/agent/android/fcm/OAFirebaseMessagingService.kt
class OAFirebaseMessagingService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        // FCM 토큰이 갱신될 때마다 서버에 업데이트
        val prefs = AgentPreferences(this)
        prefs.fcmToken = token
        CoroutineScope(Dispatchers.IO).launch {
            registerTokenToServer(prefs.assetUid, token)
        }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        // 푸시 알림 수신 처리
        val title = message.data["title"] ?: message.notification?.title ?: "OA Manager"
        val body = message.data["body"] ?: message.notification?.body ?: ""
        val type = message.data["type"] ?: "general"
        showNotification(title, body, type)
    }

    private fun showNotification(title: String, body: String, type: String) {
        val channelId = "oa_push_channel"
        val notificationManager = getSystemService(NotificationManager::class.java)

        // Android 8.0+ 알림 채널 생성
        val channel = NotificationChannel(channelId, "OA 알림", NotificationManager.IMPORTANCE_HIGH)
        notificationManager.createNotificationChannel(channel)

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }

    private suspend fun registerTokenToServer(assetUid: String?, token: String) {
        if (assetUid == null) return
        // POST /rest/v1/device_tokens (upsert)
        // { "asset_uid": "BDT00001", "fcm_token": "...", "platform": "android" }
    }
}
```

### 10.4 DB 테이블

#### device_tokens

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | BIGINT (PK, auto) | 고유 식별자 |
| `asset_uid` | TEXT (UNIQUE) | 자산 고유 식별자 (FK → assets.asset_uid) |
| `fcm_token` | TEXT | FCM 디바이스 토큰 |
| `platform` | TEXT | 플랫폼 (`android`, `ios`, `linux`, `windows`) |
| `updated_at` | TIMESTAMPTZ | 토큰 갱신 시각 |

#### notifications

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | BIGINT (PK, auto) | 고유 식별자 |
| `asset_uid` | TEXT | 대상 자산 (NULL이면 전체 발송) |
| `type` | TEXT | 알림 유형 (`os_update`, `security_alert`, `general`, `agent_update`) |
| `title` | TEXT | 알림 제목 |
| `body` | TEXT | 알림 내용 |
| `sent_at` | TIMESTAMPTZ | 발송 시각 |
| `read_at` | TIMESTAMPTZ | 읽은 시각 (NULL이면 미읽음) |

### 10.5 알림 유형

| 유형 | 코드 | 발송 주체 | 설명 |
|------|------|----------|------|
| OS 업데이트 | `os_update` | 관리자 (프론트엔드) | OS 업데이트 필요 알림 |
| 보안 경고 | `security_alert` | 관리자 (프론트엔드) | 보안 패치, 위험 알림 |
| 일반 공지 | `general` | 관리자 (프론트엔드) | 일반 공지사항 |
| 버전 업데이트 | `agent_update` | 서버 (자동) | 에이전트 업데이트 알림 |

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
   { "p_asset_uid": "BDT00001", "p_user_name": "김개발", "p_employee_id": "EMP20001" }

4. 응답 처리
   - 일치 → "확인 완료" 메시지, last_verified_at 갱신, verification_status = 'verified'
   - 불일치 → 경고 표시
```

### 12.4 RPC 함수 `verify_user`

```sql
CREATE OR REPLACE FUNCTION public.verify_user(
  p_asset_uid text,
  p_user_name text,
  p_employee_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_db_user_name text;
  v_db_employee_id text;
  v_matched boolean;
BEGIN
  -- assets 테이블에서 사용자명 조회
  SELECT user_name INTO v_db_user_name
  FROM public.assets
  WHERE asset_uid = p_asset_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'asset not found: %', p_asset_uid;
  END IF;

  -- users 테이블에서 사번 조회 (user_name으로 매칭)
  SELECT employee_id INTO v_db_employee_id
  FROM public.users
  WHERE employee_name = v_db_user_name;

  -- 일치 여부 확인
  v_matched := (v_db_user_name = p_user_name AND v_db_employee_id = p_employee_id);

  -- 결과 업데이트
  UPDATE public.assets
  SET
    last_verified_at = now(),
    verification_status = CASE WHEN v_matched THEN 'verified' ELSE 'mismatch' END
  WHERE asset_uid = p_asset_uid;

  RETURN jsonb_build_object(
    'matched', v_matched,
    'message', CASE
      WHEN v_matched THEN '사용자 확인 완료'
      ELSE '기존 사용자와 다른 사용자입니다. OA관리부서에 문의하세요.'
    END,
    'verified_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.verify_user(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_user(text, text, text) TO authenticated;
```

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
   GET /rest/v1/assets?asset_uid=eq.BDT00001&select=assignment_status,user_name

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
   { "p_asset_uid": "BDT00001", "p_user_name": "김개발" }

5. 응답 처리
   - 이름 일치 → assignment_status = 'confirmed', assignment_confirmed_at = now()
   - 이름 불일치 → 에러 메시지 "배정된 사용자 이름과 일치하지 않습니다."
```

### 13.3 RPC 함수 `confirm_assignment`

```sql
CREATE OR REPLACE FUNCTION public.confirm_assignment(
  p_asset_uid text,
  p_user_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_db_user_name text;
  v_assignment_status text;
BEGIN
  SELECT user_name, assignment_status
  INTO v_db_user_name, v_assignment_status
  FROM public.assets
  WHERE asset_uid = p_asset_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'asset not found: %', p_asset_uid;
  END IF;

  IF v_assignment_status != 'pending' THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', '수령 대기 중인 배정이 없습니다.'
    );
  END IF;

  IF v_db_user_name != p_user_name THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', '배정된 사용자 이름과 일치하지 않습니다.'
    );
  END IF;

  -- 수령 확인 완료
  UPDATE public.assets
  SET
    assignment_status = 'confirmed',
    assignment_confirmed_at = now()
  WHERE asset_uid = p_asset_uid;

  RETURN jsonb_build_object(
    'success', true,
    'message', '자산 수령이 확인되었습니다.',
    'confirmed_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.confirm_assignment(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.confirm_assignment(text, text) TO authenticated;
```

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
| 알림 발신 | Broadcast | 에이전트 → 프론트엔드 | 배터리 부족, 네트워크 변경 등 긴급 알림 |

> **Heartbeat와의 관계**: WebSocket은 상시 연결, Heartbeat는 주기적 HTTP POST. 두 채널은 독립 동작합니다.
> `request_heartbeat` 명령 수신 시 기존 `update_heartbeat` RPC를 즉시 호출합니다.

### 14.2 채널 구성

| 채널명 | 유형 | 방향 | 용도 |
|--------|------|------|------|
| `agent-presence:global` | Presence | 에이전트 → 프론트엔드 | 에이전트 실시간 접속 상태 추적 |
| `agent-commands:{asset_uid}` | Broadcast | 프론트엔드 → 에이전트 | 관리자 → 특정 기기 명령 전송 |
| `agent-alerts:global` | Broadcast | 에이전트 → 프론트엔드 | 에이전트 → 관리자 실시간 알림 |

### 14.3 Presence 상태 등록

에이전트 시작 시 `agent-presence:global` 채널에 참여하여 접속 상태를 공유합니다.

**Presence 상태 데이터:**
```json
{
  "asset_uid": "BDT00001",
  "platform": "android",
  "agent_version": "1.0.0",
  "connected_at": "2026-03-14T09:00:00Z"
}
```

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

### 14.5 알림 발신 (Broadcast)

에이전트가 특정 조건 감지 시 `agent-alerts:global` 채널로 알림을 전송합니다.

**알림 메시지 포맷:**
```json
{
  "asset_uid": "BDT00001",
  "alert_type": "battery_low",
  "message": "배터리 15% 이하",
  "data": { "battery_level": 12, "battery_charging": false },
  "timestamp": "2026-03-14T09:10:00Z"
}
```

| alert_type | 설명 | 트리거 조건 |
|------------|------|-----------|
| `battery_low` | 배터리 부족 | `battery_level` ≤ 15% |
| `network_changed` | 네트워크 변경 | WIFI ↔ CELLULAR 등 전환 |
| `agent_started` | 에이전트 시작 | 서비스 시작 시 |
| `agent_stopped` | 에이전트 종료 | 서비스 종료 시 (best-effort) |

### 14.6 연결 관리

#### WebSocket 연결
- **URL**: `wss://<project-id>.supabase.co/realtime/v1/websocket?apikey=<ANON_KEY>&vsn=1.0.0`
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
    suspend fun joinPresence(assetUid: String, platform: String, agentVersion: String)
    suspend fun joinCommandChannel(assetUid: String)
    suspend fun joinAlertChannel()

    // Broadcast 전송
    suspend fun sendAlert(alertType: String, message: String, data: JsonObject)

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

#### 알림 발신 트리거
```
BatteryManager 콜백 (배터리 레벨 변경)
  → battery_level ≤ 15%
    → realtimeManager.sendAlert("battery_low", ...)

ConnectivityManager 콜백 (네트워크 변경)
  → 네트워크 타입 변경
    → realtimeManager.sendAlert("network_changed", ...)
```
