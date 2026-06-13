import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/asset.dart';
import '../models/asset_inspection.dart';
import '../models/drawing.dart';
import '../models/inspection_round.dart';
import '../models/search_condition.dart';
import '../models/user.dart';
import '../constants.dart';

class ApiService {
  final SupabaseClient _client = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // 자산 목록 in-memory 캐시 (단순 stale-while-revalidate)
  // ---------------------------------------------------------------------------
  static final Map<String, _AssetCacheEntry> _assetsCache = {};
  static const Duration _assetsCacheTtl = Duration(seconds: 30);

  /// Realtime UPDATE/INSERT/DELETE 또는 명시적 변경 후 호출 → 다음 fetch는 fresh.
  static void invalidateAssetsCache() {
    _assetsCache.clear();
  }

  // ---------------------------------------------------------------------------
  // 자산 (Assets)
  // ---------------------------------------------------------------------------

  /// 자산 목록 조회 (페이지네이션 + 다중조건 검색 + 서버 정렬).
  ///
  /// - `conditions`가 비어있고 `search`가 주어지면 옛 단일 검색 호환 동작
  /// - `conditions`가 모두 AND이면 chain 적용, OR가 섞이면 `.or()` 평탄 문자열
  /// - `count`는 기본 [CountOption.planned] (정확도 ↓ 속도 ↑)
  Future<({List<Asset> data, int total})> fetchAssets({
    int page = 1,
    int pageSize = defaultPageSize,
    String? category,
    String? status,
    String? search,
    String? building,
    List<SearchCondition> conditions = const [],
    String orderBy = 'id',
    bool ascending = false,
    CountOption count = CountOption.planned,
  }) async {
    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;

    var query = _client.from('assets').select();

    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }
    if (status != null && status.isNotEmpty) {
      query = query.eq('assets_status', status);
    }
    if (building != null && building.isNotEmpty) {
      query = query.eq('building', building);
    }

    // 캐시 키 (필터 시그니처)
    final cacheKey = [
      'p$page', 's$pageSize',
      'c${category ?? ''}', 'st${status ?? ''}', 'b${building ?? ''}',
      'sr${search ?? ''}',
      ...conditions.map((c) => c.signature),
      'o$orderBy:${ascending ? 'a' : 'd'}',
      'cnt${count.name}',
    ].join('|');
    final cached = _assetsCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.at) < _assetsCacheTtl) {
      return (data: cached.data, total: cached.total);
    }

    if (conditions.isNotEmpty) {
      final hasOr = conditions.skip(1).any((c) => c.joiner == Joiner.or);
      if (!hasOr) {
        for (final c in conditions) {
          if (c.value.isEmpty) continue;
          query = c.op == SearchOp.eq
              ? query.eq(c.column.key, c.value)
              : query.ilike(c.column.key, '%${c.value}%');
        }
      } else {
        final filled = conditions.where((c) => c.value.isNotEmpty).toList();
        if (filled.isNotEmpty) {
          query = query.or(buildOrString(filled));
        }
      }
    } else if (search != null && search.isNotEmpty) {
      // 옛 단일 검색 호환
      query = query.or(
        'asset_uid.ilike.%$search%,'
        'name.ilike.%$search%,'
        'serial_number.ilike.%$search%,'
        'user_name.ilike.%$search%',
      );
    }

    final response = await query
        .order(orderBy, ascending: ascending)
        .range(from, to)
        .count(count);

    final total = response.count;
    final rows = response.data
        .map((e) => Asset.fromJson(e))
        .toList();

    _assetsCache[cacheKey] = _AssetCacheEntry(
      at: DateTime.now(), data: rows, total: total,
    );
    return (data: rows, total: total);
  }

  /// 자산 목록 조회 (전체 — 페이지네이션 없음)
  Future<List<Asset>> fetchAllAssets({
    String? category,
    String? status,
    String? search,
    String? building,
  }) async {
    var query = _client.from('assets').select();

    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }
    if (status != null && status.isNotEmpty) {
      query = query.eq('assets_status', status);
    }
    if (building != null && building.isNotEmpty) {
      query = query.eq('building', building);
    }
    if (search != null && search.isNotEmpty) {
      query = query.or(
        'asset_uid.ilike.%$search%,'
        'name.ilike.%$search%,'
        'serial_number.ilike.%$search%,'
        'user_name.ilike.%$search%',
      );
    }

    final response = await query.order('id', ascending: false);
    return (response as List<dynamic>)
        .map((e) => Asset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 자산 단건 조회
  Future<Asset> fetchAsset(int id) async {
    final response =
        await _client.from('assets').select().eq('id', id).single();
    return Asset.fromJson(response);
  }

  /// 자산 등록
  Future<Asset> createAsset(Map<String, dynamic> data) async {
    final response =
        await _client.from('assets').insert(data).select().single();
    return Asset.fromJson(response);
  }

  /// 자산 수정
  Future<Asset> updateAsset(int id, Map<String, dynamic> data) async {
    final response = await _client
        .from('assets')
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return Asset.fromJson(response);
  }

  /// 자산 삭제
  Future<void> deleteAsset(int id) async {
    await _client.from('assets').delete().eq('id', id);
  }

  // ---------------------------------------------------------------------------
  // 실사 (Asset Inspections)
  // ---------------------------------------------------------------------------

  /// 실사 목록 조회 (페이지네이션 + 필터 + 자산 JOIN)
  Future<({List<AssetInspection> data, int total})> fetchInspections({
    int page = 1,
    int pageSize = defaultPageSize,
    String? status,
    String? search,
    String? building,
    int? roundId,         // 특정 라운드만
    bool? onlyUnlocked,   // true=등록되지 않은 것만(locked=false)
    List<SearchCondition> conditions = const [],
  }) async {
    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;

    // 자산 join — UI 1줄 표시용 필드 모두 포함
    const selectFields =
        'id,asset_id,asset_code,asset_type,inspector_name,user_team,'
        'inspection_count,inspection_date,maintenance_company_staff,'
        'department_confirm,inspection_building,inspection_floor,'
        'inspection_position,status,memo,inspection_photo,signature_image,'
        'round_id,locked,synced,created_at,updated_at,'
        'assets!inner('
        'asset_uid,name,category,'
        'user_name,user_employee_id,user_department,'
        'owner_name,owner_employee_id,owner_department,'
        'admin_name,admin_employee_id,admin_department,'
        'building,floor,vendor,model_name,serial_number,'
        'network,normal_comment,oa_comment'
        ')';

    var query = _client.from('asset_inspections').select(selectFields);

    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }
    if (building != null && building.isNotEmpty) {
      query = query.eq('inspection_building', building);
    }
    if (roundId != null) {
      query = query.eq('round_id', roundId);
    }
    if (onlyUnlocked == true) {
      query = query.eq('locked', false);
    }

    // 자산 컬럼 검색 (embedded filter)
    if (conditions.isNotEmpty) {
      final hasOr = conditions.skip(1).any((c) => c.joiner == Joiner.or);
      final filled = conditions.where((c) => c.value.isNotEmpty).toList();
      if (filled.isNotEmpty) {
        if (!hasOr) {
          for (final c in filled) {
            final key = 'assets.${c.column.key}';
            query = c.op == SearchOp.eq
                ? query.eq(key, c.value)
                : query.ilike(key, '%${c.value}%');
          }
        } else {
          // OR가 섞이면 embedded resource or()
          final orStr = filled.map((c) {
            final v = c.value
                .replaceAll(',', r'\,')
                .replaceAll('(', r'\(')
                .replaceAll(')', r'\)')
                .replaceAll('*', r'\*');
            return c.op == SearchOp.eq
                ? '${c.column.key}.eq.$v'
                : '${c.column.key}.ilike.*$v*';
          }).join(',');
          query = query.or(orStr, referencedTable: 'assets');
        }
      }
    } else if (search != null && search.isNotEmpty) {
      // 옛 단일 검색 호환
      query = query.or(
        'asset_code.ilike.%$search%,'
        'inspector_name.ilike.%$search%',
      );
    }

    final response = await query
        .order('id', ascending: false)
        .range(from, to)
        .count(CountOption.exact);

    final total = response.count;
    final rows = response.data
        .map((e) => AssetInspection.fromJson(e))
        .toList();

    return (data: rows, total: total);
  }

  /// 실사 단건 조회 (자산 JOIN 포함)
  Future<AssetInspection> fetchInspection(int id) async {
    const selectFields =
        'id,asset_id,asset_code,asset_type,inspector_name,user_team,'
        'inspection_count,inspection_date,maintenance_company_staff,'
        'department_confirm,inspection_building,inspection_floor,'
        'inspection_position,status,memo,inspection_photo,signature_image,'
        'synced,created_at,updated_at,'
        'assets!inner(user_name,user_department)';

    final response = await _client
        .from('asset_inspections')
        .select(selectFields)
        .eq('id', id)
        .single();
    return AssetInspection.fromJson(response);
  }

  /// 실사 등록
  Future<AssetInspection> createInspection(Map<String, dynamic> data) async {
    final response = await _client
        .from('asset_inspections')
        .insert(data)
        .select()
        .single();
    return AssetInspection.fromJson(response);
  }

  /// 실사 수정
  Future<AssetInspection> updateInspection(
    int id,
    Map<String, dynamic> data,
  ) async {
    final response = await _client
        .from('asset_inspections')
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return AssetInspection.fromJson(response);
  }

  /// 실사 삭제
  Future<void> deleteInspection(int id) async {
    await _client.from('asset_inspections').delete().eq('id', id);
  }

  /// 실사 초기화 (RPC)
  Future<void> resetInspection({
    required int inspectionId,
    required String reason,
  }) async {
    await _client.rpc('reset_inspection', params: {
      'inspection_id': inspectionId,
      'reason': reason,
    });
  }

  // ---------------------------------------------------------------------------
  // 도면 (Drawings)
  // ---------------------------------------------------------------------------

  /// 도면 목록 조회
  Future<List<Drawing>> fetchDrawings() async {
    final response = await _client
        .from('drawings')
        .select()
        .order('id', ascending: false);
    return (response as List)
        .map((e) => Drawing.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 도면 단건 조회
  Future<Drawing> fetchDrawing(int id) async {
    final response =
        await _client.from('drawings').select().eq('id', id).single();
    return Drawing.fromJson(response);
  }

  /// 도면 등록
  Future<Drawing> createDrawing(Map<String, dynamic> data) async {
    final response =
        await _client.from('drawings').insert(data).select().single();
    return Drawing.fromJson(response);
  }

  /// 도면 수정
  Future<Drawing> updateDrawing(int id, Map<String, dynamic> data) async {
    final response = await _client
        .from('drawings')
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return Drawing.fromJson(response);
  }

  /// 도면 삭제
  Future<void> deleteDrawing(int id) async {
    await _client.from('drawings').delete().eq('id', id);
  }

  // ---------------------------------------------------------------------------
  // 사용자 (Users)
  // ---------------------------------------------------------------------------

  /// 사용자 목록 조회
  Future<List<User>> fetchUsers() async {
    final response =
        await _client.from('users').select().order('id', ascending: true);
    return (response as List<dynamic>)
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 사번으로 사용자 단건 조회
  Future<User?> fetchUserByEmployeeId(String employeeId) async {
    final response = await _client
        .from('users')
        .select()
        .eq('employee_id', employeeId)
        .maybeSingle();
    if (response == null) return null;
    return User.fromJson(response);
  }

  /// 사용자 단건 조회 (id)
  Future<User> fetchUser(int id) async {
    final response =
        await _client.from('users').select().eq('id', id).single();
    return User.fromJson(response);
  }

  // ---------------------------------------------------------------------------
  // RPC / Edge Functions
  // ---------------------------------------------------------------------------

  /// 만료 임박 자산 조회 (RPC)
  Future<List<Asset>> getExpiringAssets() async {
    final response = await _client.rpc('get_expiring_assets');
    return (response as List<dynamic>)
        .map((e) => Asset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 대시보드 통계 (Edge Function)
  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final response = await _client.functions.invoke('dashboard-stats');
    return response.data as Map<String, dynamic>;
  }

  /// 에이전트 푸시 알림 발송 (Edge Function)
  Future<Map<String, dynamic>> sendNotification({
    String? assetUid,
    String type = 'general',
    required String title,
    String? body,
  }) async {
    final response = await _client.functions.invoke('send-notification',
        body: {
          'asset_uid': assetUid,
          'type': type,
          'title': title,
          'body': body,
        });
    return response.data as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // 에이전트 설정 (Agent Settings)
  // ---------------------------------------------------------------------------

  /// agent_settings 전체 조회
  Future<List<Map<String, dynamic>>> fetchAgentSettings() async {
    final response = await _client
        .from('agent_settings')
        .select()
        .order('setting_key', ascending: true);
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// agent_settings 단건 수정 (관리자 전용 — RLS에서 is_admin() 체크)
  Future<void> updateAgentSetting(String key, String value) async {
    await _client
        .from('agent_settings')
        .update({'setting_value': value})
        .eq('setting_key', key);
  }

  // ---------------------------------------------------------------------------
  // 도면에 배치된 자산 조회
  // ---------------------------------------------------------------------------

  /// 특정 도면에 배치된 자산 목록
  Future<List<Asset>> fetchAssetsOnDrawing(int drawingId) async {
    final response = await _client
        .from('assets')
        .select()
        .eq('location_drawing_id', drawingId)
        .order('id', ascending: true);
    return (response as List<dynamic>)
        .map((e) => Asset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // 실사 라운드 (Inspection Rounds)
  // ---------------------------------------------------------------------------

  /// 라운드 목록 조회
  Future<List<InspectionRound>> fetchRounds() async {
    final response = await _client
        .from('inspection_rounds')
        .select()
        .order('year', ascending: false)
        .order('round', ascending: false);
    return (response as List)
        .map((e) => InspectionRound.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 현재 활성 라운드 조회 (1개 또는 null)
  Future<InspectionRound?> fetchActiveRound() async {
    final response = await _client
        .from('inspection_rounds')
        .select()
        .eq('status', 'active')
        .maybeSingle();
    if (response == null) return null;
    return InspectionRound.fromJson(response);
  }

  /// 라운드 생성
  Future<InspectionRound> createRound(Map<String, dynamic> data) async {
    final response = await _client
        .from('inspection_rounds')
        .insert(data)
        .select()
        .single();
    return InspectionRound.fromJson(response);
  }

  /// 라운드 시작 (draft → active)
  Future<InspectionRound> startRound(int roundId) async {
    final response = await _client.rpc('start_inspection_round', params: {
      'p_round_id': roundId,
    });
    return InspectionRound.fromJson(response as Map<String, dynamic>);
  }

  /// 라운드 종료 (active → closed)
  Future<InspectionRound> closeRound(int roundId) async {
    final response = await _client.rpc('close_inspection_round', params: {
      'p_round_id': roundId,
    });
    return InspectionRound.fromJson(response as Map<String, dynamic>);
  }

  /// 라운드 삭제 (관리자 전용).
  /// [force]가 true면 그 라운드에 속한 inspection의 round_id를 NULL로 분리 후 삭제.
  Future<Map<String, dynamic>> deleteRound(int roundId, {bool force = false}) async {
    final response = await _client.rpc('delete_inspection_round', params: {
      'p_round_id': roundId,
      'p_force': force,
    });
    return Map<String, dynamic>.from(response as Map);
  }

  /// 라운드 재오픈 (closed → active, 관리자 전용)
  Future<InspectionRound> reopenRound(int roundId) async {
    final response = await _client.rpc('reopen_inspection_round', params: {
      'p_round_id': roundId,
    });
    return InspectionRound.fromJson(response as Map<String, dynamic>);
  }

  /// 특정 자산의 실사 기록 중 가장 최근 1건 (또는 null)
  Future<AssetInspection?> fetchLatestInspectionForAsset(int assetId) async {
    final res = await _client
        .from('asset_inspections')
        .select()
        .eq('asset_id', assetId)
        .order('inspection_date', ascending: false)
        .order('id', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return AssetInspection.fromJson(res);
  }

  /// 실사 잠금 / 해제 (UI [N차 등록] / [N차 등록취소])
  Future<void> setInspectionLocked(int inspectionId, bool locked) async {
    await _client
        .from('asset_inspections')
        .update({'locked': locked})
        .eq('id', inspectionId);
  }
}

class _AssetCacheEntry {
  final DateTime at;
  final List<Asset> data;
  final int total;
  const _AssetCacheEntry({
    required this.at,
    required this.data,
    required this.total,
  });
}
