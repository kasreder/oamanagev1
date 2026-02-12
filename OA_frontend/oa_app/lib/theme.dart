import 'package:flutter/material.dart';

/// Light Mode 색상
class AppColorsLight {
  static const primary = Color(0xFF1565C0);
  static const secondary = Color(0xFF2E7D32);
  static const error = Color(0xFFC62828);
  static const surface = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF1C1B1F);

  // 자산 상태 색상
  static const statusUsing = Color(0xFF4CAF50);     // 사용 (Green)
  static const statusAvailable = Color(0xFF2196F3); // 가용 (Blue)
  static const statusNeedCheck = Color(0xFFFF9800);  // 점검필요 (Orange)
  static const statusBroken = Color(0xFFF44336);    // 고장 (Red)
  static const statusMoving = Color(0xFF9C27B0);    // 이동 (Purple)

  // 리스트 스타일
  static const divider = Color(0xFFE0E0E0);
  static const rowDefault = Color(0xFFFFFFFF);
  static const rowHover = Color(0xFFF5F5F5);
  static const headerRow = Color(0xFFFAFAFA);
  static const headerText = Color(0xFF616161);
}

/// Dark Mode 색상
class AppColorsDark {
  static const primary = Color(0xFF90CAF9);
  static const secondary = Color(0xFFA5D6A7);
  static const error = Color(0xFFEF9A9A);
  static const surface = Color(0xFF1C1B1F);
  static const onSurface = Color(0xFFE6E1E5);

  // 자산 상태 색상 (Material 300 톤)
  static const statusUsing = Color(0xFF81C784);
  static const statusAvailable = Color(0xFF64B5F6);
  static const statusNeedCheck = Color(0xFFFFB74D);
  static const statusBroken = Color(0xFFE57373);
  static const statusMoving = Color(0xFFBA68C8);

  // 리스트 스타일
  static const divider = Color(0xFF424242);
  static const rowDefault = Color(0xFF1C1B1F);
  static const rowHover = Color(0xFF2C2B2F);
  static const headerRow = Color(0xFF252428);
  static const headerText = Color(0xFF9E9E9E);
}

/// 자산 상태별 색상 반환
Color getStatusColor(String status, Brightness brightness) {
  final isLight = brightness == Brightness.light;
  switch (status) {
    case '사용':
      return isLight ? AppColorsLight.statusUsing : AppColorsDark.statusUsing;
    case '가용':
      return isLight
          ? AppColorsLight.statusAvailable
          : AppColorsDark.statusAvailable;
    case '점검필요':
      return isLight
          ? AppColorsLight.statusNeedCheck
          : AppColorsDark.statusNeedCheck;
    case '고장':
      return isLight ? AppColorsLight.statusBroken : AppColorsDark.statusBroken;
    case '이동':
      return isLight ? AppColorsLight.statusMoving : AppColorsDark.statusMoving;
    default:
      return isLight ? AppColorsLight.onSurface : AppColorsDark.onSurface;
  }
}

/// Light Theme
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorSchemeSeed: AppColorsLight.primary,
  scaffoldBackgroundColor: AppColorsLight.surface,
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    elevation: 0,
  ),
  dividerTheme: const DividerThemeData(
    color: AppColorsLight.divider,
    thickness: 1,
  ),
  cardTheme: const CardTheme(
    elevation: 1,
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  ),
);

/// Dark Theme (기본값)
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorSchemeSeed: AppColorsDark.primary,
  scaffoldBackgroundColor: AppColorsDark.surface,
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    elevation: 0,
  ),
  dividerTheme: const DividerThemeData(
    color: AppColorsDark.divider,
    thickness: 1,
  ),
  cardTheme: const CardTheme(
    elevation: 1,
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  ),
);
