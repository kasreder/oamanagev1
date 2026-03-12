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
| Heartbeat 전송 | 주기적으로 `last_active_at` 갱신하여 접속 상태 실시간 반영 |
| 시스템 모니터링 | CPU, 메모리, 스토리지, 배터리, 네트워크 등 기기 상태 수집 |
| 자동 재시작 | 기기 재부팅, 앱 종료 후에도 자동으로 Heartbeat 재개 |
| 보안 저장 | 인증 토큰, 자산 식별자를 플랫폼별 보안 저장소에 암호화 저장 |
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
│  ┌──────────────────────────────┐                       │
│  │     HeartbeatWorker          │                       │
│  │  (asset_uid + SystemInfo)    │                       │
│  └──────────────┬───────────────┘                       │
└─────────────────┼───────────────────────────────────────┘
                  │ HTTPS
                  ▼
┌─────────────────────────────────────────────────────────┐
│              Supabase Backend                            │
│                                                         │
│  ┌──────────┐    ┌──────────────────────────────────┐  │
│  │ Auth     │    │ PostgREST                         │  │
│  │ (JWT)    │    │ POST /rest/v1/rpc/update_heartbeat│  │
│  └──────────┘    └──────────────┬────────────────────┘  │
│                                 │                        │
│                                 ▼                        │
│  ┌──────────────────────────────────────────────────┐   │
│  │ PostgreSQL                                        │   │
│  │ assets.last_active_at = now()                     │   │
│  │ assets.specifications->'device_status' = {...}    │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                  │
                  ▼ 프론트엔드 조회
┌─────────────────────────────────────────────────────────┐
│              OA Manager 프론트엔드 (Flutter)              │
│  접속현황 인디케이터: 🟢 접속중 / 🟡 N일전 / 🔴 만료    │
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
│       │   │   └── AuthManager.kt             ← 4.2 토큰 관리
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
    "uptime_hours": 48.5
  }
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `p_asset_uid` | text | **필수** | OA 자산 고유 식별자 (정규식: `^(B\|R\|C\|L\|S)(DT\|NB\|MN\|PR\|TB\|SC\|IP\|NW\|SV\|WR\|SD)[0-9]{5}$`) |
| `p_system_info` | jsonb | 선택 | 시스템 모니터링 정보. `null`이면 `last_active_at`만 갱신 |

### 3.2 SystemInfo

시스템 모니터링 수집 항목입니다. 모든 플랫폼에서 동일한 필드를 수집합니다.

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

```kotlin
// shared/src/commonMain/kotlin/com/oamanager/agent/model/SystemInfo.kt
@Serializable
data class SystemInfo(
    @SerialName("cpu_usage")       val cpuUsage: Float,
    @SerialName("memory_total_mb") val memoryTotalMb: Int,
    @SerialName("memory_used_mb")  val memoryUsedMb: Int,
    @SerialName("storage_total_gb") val storageTotalGb: Float,
    @SerialName("storage_used_gb") val storageUsedGb: Float,
    @SerialName("battery_level")   val batteryLevel: Int,
    @SerialName("battery_charging") val batteryCharging: Boolean,
    @SerialName("network_type")    val networkType: String,
    @SerialName("ip_address")      val ipAddress: String,
    @SerialName("os_version")      val osVersion: String,
    @SerialName("uptime_hours")    val uptimeHours: Float,
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
    "uptime_hours": 48.5
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

> 마이그레이션 파일: `OA_backend/supabase/migrations/20260311000000_add_heartbeat_rpc.sql`

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
    "uptime_hours": 48.5
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
| `io.ktor` | `ktor-client-okhttp` | 2.3.8 | OkHttp 엔진 | androidMain |

### 6.2 AndroidManifest.xml

**필요 권한:**

| 권한 | 용도 | 필수 |
|------|------|------|
| `INTERNET` | Supabase API 통신 | **필수** |
| `RECEIVE_BOOT_COMPLETED` | 기기 재부팅 후 WorkManager 재등록 | **필수** |
| `ACCESS_NETWORK_STATE` | 네트워크 타입, 연결 상태 확인 | **필수** |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | OEM 배터리 최적화 예외 요청 | 권장 |
| `POST_NOTIFICATIONS` | Android 13+ 알림 권한 | 권장 |

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.oamanager.agent">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
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

    fun enqueueHeartbeat() {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val heartbeatWork = PeriodicWorkRequestBuilder<HeartbeatWorker>(
            15, TimeUnit.MINUTES
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
            ExistingPeriodicWorkPolicy.KEEP,
            heartbeatWork
        )
    }
}
```

| 항목 | 설명 |
|------|------|
| WorkManager 초기화 | `Configuration.Provider` 구현으로 커스텀 설정 |
| 작업 등록 | `enqueueUniquePeriodicWork`로 중복 방지 |
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
}
```

| 저장 항목 | 암호화 | 설명 |
|----------|--------|------|
| `asset_uid` | AES-256 | 자산 식별자 |
| `access_token` | AES-256 | JWT 액세스 토큰 |
| `refresh_token` | AES-256 | JWT 갱신 토큰 |
| `last_heartbeat_time` | AES-256 | 마지막 Heartbeat 성공 시각 |

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
        return SystemInfo(
            cpuUsage       = readCpuUsage(),         // /proc/stat 파싱
            memoryTotalMb  = getMemoryTotal(),        // ActivityManager.MemoryInfo
            memoryUsedMb   = getMemoryUsed(),         // ActivityManager.MemoryInfo
            storageTotalGb = getStorageTotal(),       // StatFs
            storageUsedGb  = getStorageUsed(),        // StatFs
            batteryLevel   = getBatteryLevel(),       // BatteryManager
            batteryCharging = isBatteryCharging(),    // BatteryManager
            networkType    = getNetworkType(),        // ConnectivityManager
            ipAddress      = getIpAddress(),          // NetworkInterface
            osVersion      = getOsVersion(),          // Build.VERSION
            uptimeHours    = getUptimeHours(),        // SystemClock
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

### 6.4 WorkManager 설정

| 설정 | 값 | 설명 |
|------|-----|------|
| 작업 유형 | `PeriodicWorkRequest` | 주기적 반복 |
| 주기 | 15분 | WorkManager 최소 주기 |
| 네트워크 제약 | `NetworkType.CONNECTED` | 오프라인 시 대기 |
| 중복 정책 | `ExistingPeriodicWorkPolicy.KEEP` | 기존 작업 유지 |
| 백오프 | `BackoffPolicy.EXPONENTIAL`, 10초 시작 | 실패 시 지수 증가 |
| 작업 ID | `"heartbeat"` | 고유 식별자 |

> **주기 근거**: `access_settings.active_threshold_minutes`의 기본값이 60분이므로, 15분 주기면 임계값 내에 최소 4회 Heartbeat 전송 보장. 정상 가동 기기는 항상 **초록색(접속중)** 표시.

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
│  ┌──────────┐ ┌──────────┐  │
│  │  시 작    │ │ 즉시 전송 │  │  ← 버튼 2개
│  └──────────┘ └──────────┘  │
│                              │
│  ── 상태 정보 ────────────── │  ← 구분선
│                              │
│  연결 상태: ● 연결됨          │  ← 초록/빨강 인디케이터
│  자산 번호: BDT00001         │
│  마지막 전송: 2026-03-11      │
│              14:30:22        │
│  전송 결과: ✓ 성공            │  ← 성공/실패 표시
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
