import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../constants.dart' as defaults;

/// (scope, category) → 옵션 텍스트 리스트.
/// DB 실패/빈 결과 시 constants.dart의 const 리스트를 fallback 으로 사용.
class DropdownKey {
  final String scope;
  final String category;
  const DropdownKey(this.scope, this.category);

  @override
  bool operator ==(Object o) =>
      o is DropdownKey && o.scope == scope && o.category == category;

  @override
  int get hashCode => Object.hash(scope, category);
}

final dropdownOptionsProvider =
    FutureProvider.family<List<String>, DropdownKey>((ref, key) async {
  try {
    final rows = await Supabase.instance.client
        .from('dropdown_options')
        .select('value')
        .eq('scope', key.scope)
        .eq('category', key.category)
        .order('value');  // 가나다순(사전순)
    final list = (rows as List)
        .map((e) => (e as Map<String, dynamic>)['value'] as String)
        .toList();
    if (list.isNotEmpty) return list;
  } catch (_) {/* fall through to defaults */}
  return _fallback(key);
});

List<String> _fallback(DropdownKey key) {
  switch ('${key.scope}.${key.category}') {
    case 'asset_detail.category':
      return defaults.assetCategories;
    case 'asset_detail.supply_type':
      return defaults.supplyTypes;
    case 'asset_detail.network':
      return defaults.networkOptions;
    case 'asset_detail.building1':
      return defaults.building1Options;
    case 'asset_detail.admin_affiliation':
      return defaults.adminAffiliationOptions;
    case 'asset_detail.floor':
      return defaults.floorOptions;
    case 'inspection_detail.inspection_status':
      return defaults.inspectionStatusOptions;
    default:
      return const [];
  }
}
