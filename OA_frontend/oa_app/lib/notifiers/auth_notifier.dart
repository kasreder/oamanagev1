import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_state.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

/// 인증 상태 관리 Notifier
class AuthNotifier extends AsyncNotifier<AuthState> {
  late final AuthService _authService;

  @override
  Future<AuthState> build() async {
    _authService = AuthService();

    // 저장된 세션 확인
    final session = _authService.currentSession;
    if (session == null) {
      return const AuthState.unauthenticated();
    }

    // 세션이 있으면 사용자 정보 조회
    final user = await _authService.fetchCurrentUser();
    if (user == null) {
      return const AuthState.unauthenticated();
    }

    return AuthState(
      isAuthenticated: true,
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      user: user,
    );
  }

  /// 사번 + 비밀번호 로그인
  Future<void> login(String employeeId, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final authResponse = await _authService.signInWithPassword(
        employeeId: employeeId,
        password: password,
      );

      final session = authResponse.session;
      if (session == null) {
        throw Exception('로그인 실패: 세션을 생성할 수 없습니다.');
      }

      final user = await _authService.fetchCurrentUser();
      if (user == null) {
        throw Exception('로그인 실패: 사용자 정보를 찾을 수 없습니다.');
      }

      return AuthState(
        isAuthenticated: true,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        user: user,
      );
    });
  }

  /// Google OAuth 로그인
  Future<void> loginWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final success = await _authService.signInWithGoogle();
      if (!success) {
        throw Exception('Google 로그인 실패');
      }

      // OAuth 리다이렉트 후 세션이 설정될 때까지 대기
      // onAuthStateChange에서 처리됨
      return state.value ?? const AuthState.unauthenticated();
    });
  }

  /// 카카오 로그인 (Edge Function)
  Future<void> loginWithKakao(String kakaoAccessToken) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final authResponse =
          await _authService.signInWithKakao(kakaoAccessToken);

      final session = authResponse.session;
      if (session == null) {
        throw Exception('카카오 로그인 실패: 세션을 생성할 수 없습니다.');
      }

      // auth_uid로 사용자 조회
      final authUser = _authService.currentAuthUser;
      User? user;
      if (authUser != null) {
        user = await _authService.fetchUserByAuthUid(authUser.id);
      }
      user ??= await _authService.fetchCurrentUser();

      if (user == null) {
        throw Exception('카카오 로그인 실패: 사용자 정보를 찾을 수 없습니다.');
      }

      return AuthState(
        isAuthenticated: true,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        user: user,
      );
    });
  }

  /// 로그아웃
  Future<void> logout() async {
    await _authService.signOut();
    state = const AsyncData(AuthState.unauthenticated());
  }

  /// 현재 로그인된 사용자 정보
  User? get currentUser => state.value?.user;
}

/// 인증 상태 Provider
final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
