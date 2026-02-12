import 'user.dart';

class AuthState {
  final bool isAuthenticated;
  final String? accessToken;
  final String? refreshToken;
  final User? user;

  const AuthState({
    this.isAuthenticated = false,
    this.accessToken,
    this.refreshToken,
    this.user,
  });

  const AuthState.unauthenticated()
      : isAuthenticated = false,
        accessToken = null,
        refreshToken = null,
        user = null;

  AuthState copyWith({
    bool? isAuthenticated,
    String? accessToken,
    String? refreshToken,
    User? user,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
    );
  }
}
