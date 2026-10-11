# OA 보안 긴급 전환 실행서

이 문서는 `supabase/migrations/20260816000000_security_hardening.sql` 및
연관 웹/Edge Function 변경을 배포할 때 사용한다. 마이그레이션은 아직 운영
DB에 적용하지 않은 상태를 전제로 한다.

## 전환 원칙

- `functions/v1/main` 공개 경로와 공용 APK 계정은 전환 중 계속 차단한다.
- 공용 APK 자격증명은 한 자산에만 귀속될 수 없으므로, 재활성화하거나
  예외 허용하지 않는다.
- 서비스 역할 키, JWT 서명 키, 공용 APK 로그인 비밀번호는 이미 노출된
  것으로 보고 별도 비밀관리 절차에서 교체한다.

## 1. 배포 전 점검

1. 운영 DB의 백업과 복구 절차를 확인한다.
2. 현재 Edge Function 공개 경로가 차단된 상태인지 확인한다.
3. 공용 에이전트 `auth.users` 계정을 로그인 불가 상태로 전환하고 기존
   세션을 무효화한다. 이 계정은 일반 `user` RLS 읽기 권한으로 자산·실사
   정보를 읽을 수 있으므로, RPC 권한 회수만으로는 충분하지 않다.
4. 웹 프런트엔드와 Edge Function의 이번 변경본을 같은 유지보수 창에
   배포할 준비를 한다. 새 저장소 정책은 UUID 접두 경로를 요구한다.
5. 아래 읽기 전용 질의로 실제 DDL 실행 역할과 `postgres` 기본 ACL을
   기록한다. 비밀값은 조회하지 않는다.

   ```sql
   SELECT current_user, session_user;

   SELECT
     d.defaclrole::regrole AS owner_role,
     COALESCE(n.nspname, '<global>') AS schema_name,
     d.defaclobjtype AS object_kind,
     d.defaclacl AS acl
   FROM pg_default_acl AS d
   LEFT JOIN pg_namespace AS n ON n.oid = d.defaclnamespace
   WHERE d.defaclrole = 'postgres'::regrole
     AND (d.defaclnamespace = 0 OR n.nspname IN ('public', 'storage'))
   ORDER BY schema_name, object_kind;
   ```

## 2. 적용 순서

1. Edge Function 변경본을 배포한다. 알림 발송은 유효한 사용자 JWT와
   서버 측 관리자 그룹 역할을 모두 요구한다.
   `auth-kakao`만 로그인 경계로 공개할 수 있으며, Kong에서 별도 경로로
   IP 기준 rate-limit·요청 크기 제한을 적용한다. 이 경로는 카카오가 검증한
   토큰과 사전 연결된 OA 계정만 허용하고, 임의 사번·Auth UID·redirect URL을
   받지 않는다.
2. 웹 프런트엔드 변경본을 배포한다. 사진·서명 새 업로드 경로는
   `<auth_uid>/<round>/...` 형식이며, 사용자/권한 관리는 보안 RPC를 사용한다.
3. 운영 경로가 계속 차단된 것을 확인한 뒤
   `20260816000000_security_hardening.sql`을 한 번 적용한다.
4. 아래 기능을 관리자/일반 사용자 계정으로 각각 확인한다.

## 3. 적용 후 확인

- 익명 키만으로 `public` 테이블, Storage 객체, RPC를 읽거나 쓰지 못한다.
- 일반 사용자는 자신의 미완료·활성 회차 실사만 입력·수정할 수 있고,
  다른 사람의 실사, 잠긴 실사, 자산/회차 연결을 변경하지 못한다.
- 관리자 그룹만 자산·도면·라운드·알림 대상 토큰을 변경할 수 있다.
- 마스터 관리자만 계정 생성, 역할 변경, 마스터 지정, 비밀번호 초기화를
  수행할 수 있다. 임시 비밀번호가 예측 가능한 사번 규칙이 아닌지 확인한다.
- 새 사진·서명은 호출자 UUID 경로에만 업로드되며, 기존 파일은 읽을 수 있다.
- 공용 에이전트 계정과 기존 APK가 로그인·자산 조회·heartbeat·검증 RPC를
  수행하지 못한다. 이는 의도된 차단 상태다.
- `auth-kakao`는 미리 연결된 `sns_id`/`auth_uid` 조합만 세션을 발급하고,
  연결되지 않은 계정은 생성하거나 자동 연결하지 않는다.
- 마이그레이션의 기본 ACL probe가 통과했는지 확인한다. 이후 같은 조회에서
  `public`/`storage`의 테이블·시퀀스·함수 기본 ACL에 `PUBLIC`, `anon`,
  `authenticated`, `service_role` 권한이 남아 있으면 새 객체 권한을 별도
  수정 마이그레이션으로 바로 회수한다. 기존 객체에 대한 필요한 권한은 이번
  마이그레이션의 명시적 GRANT만 사용한다.

## 4. 에이전트 재도입 설계 (별도 작업)

1. 자산마다 고유한 `auth.users` 신원 또는 일회용 등록 토큰을 발급한다.
2. 등록 시 서버가 해당 신원과 정확히 하나의 `asset_uid`를 매핑한다.
   APK가 임의의 자산번호를 주장하는 방식은 허용하지 않는다.
3. 기기 비밀은 Android Keystore 등 플랫폼 보안 저장소에 보관하고,
   APK·저장소·배포 스크립트에 공용 비밀번호를 넣지 않는다.
4. heartbeat/사용자 검증/배정 확인은 이 매핑을 서버에서 검증하는 전용
   RPC 또는 Edge Function으로 다시 구현한다. 성공 전에는 해당 RPC의
   `authenticated` 실행 권한을 부여하지 않는다.
5. 기기별 알림 구독도 매핑된 자산의 토큰/알림만 읽도록 RLS를 분리한다.
6. 새 keystore로 앱 서명 키를 교체하고 CI 비밀 저장소로 이관한다. 기존
   공용 APK 계정과 서명 키는 폐기한다.

## 5. 되돌리기

데이터 마이그레이션 자체는 되돌릴 필요가 없도록 설계되었다. 호환성 문제가
생기면 공개 권한을 되살리지 말고, 영향을 받은 기능을 차단한 채 수정
마이그레이션을 추가한다. 공용 에이전트 계정/공개 Function 경로의 재활성화는
기기별 신원·권한 모델이 검증된 뒤에만 수행한다.
