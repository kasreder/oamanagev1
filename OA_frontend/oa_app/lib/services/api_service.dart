import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/asset.dart';
import '../models/asset_inspection.dart';
import '../models/drawing.dart';
import '../models/user.dart';
import '../constants.dart';

class ApiService {
  final SupabaseClient _client = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // 자산 (Assets)
  // ---------------------------------------------------------------------------

  /// 자산 목록 조회 (페이지네이션 + 필터)
  Future<({List<Asset> data, int total})> fetchAssets({
    int page = 1,
    int pageSize = defaultPageSize,
    String? category,
    String? status,
    String? search,
    String? building,
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
    if (search != null && search.isNotEmpty) {
      query = query.or(
        'asset_uid.ilike.%$search%,'
        'name.ilike.%$search%,'
        'serial_number.ilike.%$search%,'
        'user_name.ilike.%$search%',
      );
    }

    final response = await query
        .order('id', ascending: false)
        .range(from, to)
        .count(CountOption.exact);

    final total = response.count;
    final rows = response.data
        .map((e) => Asset.fromJson(e))
        .toList();

    return (data: rows, total: total);
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
  }) async {
    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;

    const selectFields =
        'id,asset_id,asset_code,asset_type,inspector_name,user_team,'
        'inspection_count,inspection_date,maintenance_company_staff,'
        'department_confirm,inspection_building,inspection_floor,'
        'inspection_position,status,memo,inspection_photo,signature_image,'
        'synced,created_at,updated_at,'
        'assets!inner(user_name,user_department)';

    var query = _client.from('asset_inspections').select(selectFields);

    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }
    if (building != null && building.isNotEmpty) {
      query = query.eq('inspection_building', building);
    }
    if (search != null && search.isNotEmpty) {
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
}
