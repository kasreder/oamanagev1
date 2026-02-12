import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user.dart' as app;

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // 사번 + 비밀번호 로그인
  // ---------------------------------------------------------------------------

  /// 사번을 이메일 형태('{employeeId}@oamanager.internal')로 변환하여 로그인
  Future<AuthResponse> signInWithPassword({
    required String employeeId,
    required String password,
  }) async {
    final email = '$employeeId@oamanager.internal';
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // ---------------------------------------------------------------------------
  // OAuth 로그인
  // ---------------------------------------------------------------------------

  /// Google OAuth 로그인
  Future<bool> signInWithGoogle() async {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.oamanager://login-callback/',
    );
  }

  /// 카카오 로그인 (Edge Function 호출)
  Future<AuthResponse> signInWithKakao(String kakaoAccessToken) async {
    final response = await _client.functions.invoke(
      'auth-kakao',
      body: {'access_token': kakaoAccessToken},
    );

    final data = response.data as Map<String, dynamic>;
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;

    // Edge Function에서 받은 토큰으로 세션 설정
    return _client.auth.setSession(
      '$accessToken|$refreshToken',
    );
  }

  // ---------------------------------------------------------------------------
  // 로그아웃
  // ---------------------------------------------------------------------------

  /// 로그아웃
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Auth 상태 변경 리스너
  // ---------------------------------------------------------------------------

  /// Auth 상태 변경 스트림
  Stream<AuthState> onAuthStateChange() {
    return _client.auth.onAuthStateChange;
  }

  // ---------------------------------------------------------------------------
  // 현재 사용자 정보
  // ---------------------------------------------------------------------------

  /// 현재 로그인된 Supabase Auth 사용자
  User? get currentAuthUser => _client.auth.currentUser;

  /// 현재 세션
  Session? get currentSession => _client.auth.currentSession;

  /// Auth 로그인 후 users 테이블에서 employee_id로 사용자 정보 조회
  Future<app.User?> fetchCurrentUser() async {
    final authUser = currentAuthUser;
    if (authUser == null) return null;

    // 이메일에서 사번 추출
    final email = authUser.email;
    if (email == null) return null;

    final employeeId = email.split('@').first;

    final response = await _client
        .from('users')
        .select()
        .eq('employee_id', employeeId)
        .maybeSingle();

    if (response == null) return null;
    return app.User.fromJson(response);
  }

  /// auth_uid로 사용자 조회 (OAuth 로그인 시)
  Future<app.User?> fetchUserByAuthUid(String authUid) async {
    final response = await _client
        .from('users')
        .select()
        .eq('auth_uid', authUid)
        .maybeSingle();

    if (response == null) return null;
    return app.User.fromJson(response);
  }
}
