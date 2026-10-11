import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'auth_notifier.dart';

/// 권한 관리 대상 메뉴 (key → 라벨). 설정/거래처는 admin 고정이라 제외.
const Map<String, String> managedMenus = {
  'home': '홈',
  'scan': '스캔',
  'assets': '자산목록',
  'inspections': '실사목록',
  'drawings': '도면관리',
  'receipts': '인수증',
};

/// 현재 로그인 사용자에게 보이는 메뉴 key 셋.
/// menu_permissions 행 평가: user > role > all > 기본(전부).
/// admin은 항상 전부 (메뉴권한 실수로 설정 접근을 잃는 것 방지).
final menuVisibilityProvider = FutureProvider<Set<String>>((ref) async {
  final all = managedMenus.keys.toSet();
  final user = ref.watch(authNotifierProvider).valueOrNull?.user;
  if (user == null || user.isAdmin) return all;

  try {
    final rows = List<Map<String, dynamic>>.from(
        await Supabase.instance.client.from('menu_permissions').select()
            as List);
    for (final (type, value) in [
      ('user', user.employeeId),
      ('role', user.role),
      ('all', ''),
    ]) {
      for (final r in rows) {
        if (r['target_type'] == type && r['target_value'] == value) {
          return Set<String>.from(r['menu_keys'] as List);
        }
      }
    }
  } catch (_) {
    // 조회 실패 시 기본 전부 — 메뉴가 사라져 잠기는 것보다 안전
  }
  return all;
});
