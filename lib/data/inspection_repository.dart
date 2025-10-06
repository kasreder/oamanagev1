// Path: lib/data/inspection_repository.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';
import '../models/inspection.dart';

/// 메모리 기반 실사 저장소.
///
/// - 앱 부팅 시 더미 JSON을 로드하여 [_items] 리스트를 구성하고,
/// - 이후에는 Provider 등을 통해 in-memory 상태를 갱신한다.
///
/// 본 클래스는 비동기 로딩, 정렬, 메모 생성 로직 등 실사 데이터
/// 전처리를 담당한다.
class InspectionRepository {
  final List<Inspection> _items = [];
  // TODO: Hive/Sqflite 등 영속 저장소 교체 포인트 고려

  /// 에셋 JSON으로부터 초기 데이터를 로드한다.
  ///
  /// 1. `asset_inspections.json`을 읽어 실사 원본을 파싱한다.
  /// 2. `assets.json`을 추가로 읽어 자산별 상태(status)를 매핑한다.
  /// 3. 누락된 필드는 디폴트 값을 채워 넣으며, 메모 문자열을 구성한다.
  /// 4. 로드한 실사 목록을 최근 스캔 순으로 정렬하여 [_items]에 보관한다.
  Future<void> loadFromAssets() async {
    try {
      final raw = await _loadInspectionRaw();
      final decoded = await _decodeInspectionsWithFallback(raw);
      final statusMap = await _loadAssetStatuses();
      final items = <Inspection>[];
      for (final item in decoded) {
        final assetUid =
            _stringOrNull(item['asset_code']) ?? _stringOrNull(item['assetUid']);
        if (assetUid == null) {
          continue;
        }
        final userId = _stringOrNull(item['user_id']) ?? _stringOrNull(item['userId']);
        final rawId = item['id'];
        final id = rawId == null
            ? 'ins_$assetUid'
            : rawId is String
                ? rawId
                : 'ins_${rawId.toString()}';
        final parsedDate = DateTime.tryParse(
              _stringOrNull(item['inspection_date']) ??
                  _stringOrNull(item['scannedAt']) ??
                  '',
            ) ??
            DateTime.now();
        final memo = _buildMemo(item) ?? _stringOrNull(item['memo']);
        final assetType =
            _stringOrNull(item['asset_type']) ?? _stringOrNull(item['assetType']);
        final isVerified = item['is_verified'] as bool? ??
            item['isVerified'] as bool? ??
            true;
        final barcodePhoto = _stringOrNull(item['barcode_photo']) ??
            _stringOrNull(item['barcodePhoto']) ??
            _stringOrNull(item['barcode_photo_url']) ??
            _stringOrNull(item['barcodePhotoUrl']);
        items.add(
          Inspection(
            id: id,
            assetUid: assetUid,
            status: statusMap[assetUid] ?? _stringOrNull(item['status']) ?? '사용',
            memo: memo,
            scannedAt: parsedDate,
            synced: item['synced'] as bool? ?? ((item['inspection_count'] as int? ?? 0) % 2 == 0),
            userTeam: _stringOrNull(item['user_team']),
            userId: userId,
            assetType: assetType,
            isVerified: isVerified,
            barcodePhotoUrl: barcodePhoto,
          ),
        );
      }
      _items
        ..clear()
        ..addAll(items);
      _sortItems();
    } on FlutterError {
      _items.clear();
    } on FormatException catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to parse inspection assets: $error');
      }
      _items.clear();
    }
  }

  /// 현재 보유 중인 실사 리스트를 반환한다.
  ///
  /// 외부에서 [_items]를 변경하지 못하도록 `List.unmodifiable`을 사용한다.
  List<Inspection> getAll() => List.unmodifiable(_items);

  /// 실사 내역을 추가하거나 갱신한다.
  ///
  /// [inspection.id] 기준으로 기존 항목을 찾고, 존재하면 교체 후 정렬을 유지한다.
  void upsert(Inspection inspection) {
    final index = _items.indexWhere((item) => item.id == inspection.id);
    if (index >= 0) {
      _items[index] = inspection;
    } else {
      _items.add(inspection);
    }
    _sortItems();
  }

  /// 식별자로 실사를 삭제한다.
  ///
  /// 주로 상세 화면에서 삭제 요청 시 호출되며, 정렬은 재실행할 필요가 없다.
  void delete(String id) {
    _items.removeWhere((item) => item.id == id);
  }

  /// ID로 실사 단건을 조회한다. 존재하지 않으면 `null`을 반환한다.
  Inspection? findById(String id) {
    return _items.firstWhereOrNull((item) => item.id == id);
  }

  /// 스캔 일자를 기준으로 내림차순 정렬한다.
  ///
  /// 최신 스캔이 리스트 상단에 위치하도록 정렬하여 UX를 개선한다.
  void _sortItems() {
    _items.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
  }

  /// 자산 실사 더미 JSON을 읽는다.
  ///
  /// `assets/dummy/mock` 경로가 없을 경우 `assets/mock` 경로를 폴백으로 사용한다.
  Future<String> _loadInspectionRaw() async {
    try {
      return await rootBundle.loadString('assets/dummy/mock/asset_inspections.json');
    } on FlutterError {
      return rootBundle.loadString('assets/mock/asset_inspections.json');
    }
  }

  /// 더미 실사 JSON을 안전하게 디코드한다.
  ///
  /// 주 파일 파싱에 실패하면 폴백 에셋을 재시도한다.
  Future<List<Map<String, dynamic>>> _decodeInspectionsWithFallback(String raw) async {
    try {
      return _decodeInspectionList(raw);
    } on FormatException catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to parse dummy inspections: $error. Falling back to default mock data.');
      }
      final fallbackRaw = await rootBundle.loadString('assets/mock/asset_inspections.json');
      return _decodeInspectionList(fallbackRaw);
    }
  }

  /// 실사 JSON 문자열을 디코드하여 리스트로 반환한다.
  List<Map<String, dynamic>> _decodeInspectionList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Expected a JSON array of inspections.');
    }
    return decoded.cast<Map<String, dynamic>>();
  }

  /// 자산 상태 정보를 읽어서 UID → 상태 맵을 구성한다.
  ///
  /// JSON 파싱에 실패하거나 파일이 없으면 빈 맵을 반환한다.
  Future<Map<String, String>> _loadAssetStatuses() async {
    Future<String> load(String path) => rootBundle.loadString(path);
    try {
      final raw = await load('assets/dummy/mock/assets.json');
      return _parseAssetStatuses(raw);
    } on FlutterError {
      try {
        final raw = await load('assets/mock/assets.json');
        return _parseAssetStatuses(raw);
      } on FlutterError {
        return {};
      }
    }
  }

  /// 자산 상태 JSON 문자열을 파싱하여 UID 기반 맵을 만든다.
  Map<String, String> _parseAssetStatuses(String raw) {
    final decoded = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    final map = <String, String>{};
    for (final item in decoded) {
      final uid = _stringOrNull(item['asset_uid']) ?? _stringOrNull(item['uid']);
      final status =
          _stringOrNull(item['assets_status']) ?? _stringOrNull(item['status']);
      if (uid != null && status != null) {
        map[uid] = status;
      }
    }
    return map;
  }

  /// 값이 `null`이거나 빈 문자열일 경우 `null`을 반환하는 헬퍼.
  String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }

  /// 점검자/자산 정보를 기반으로 한 다중 행 메모를 생성한다.
  ///
  /// JSON에 포함된 필드를 순차적으로 조합하여 사용자에게 읽기 쉬운 문자열을 만든다.
  String? _buildMemo(Map<String, dynamic> item) {
    final lines = <String>[];
    final inspector = _stringOrNull(item['inspector_name']);
    final team = _stringOrNull(item['user_team']);
    final maintenance = _stringOrNull(item['maintenance_company_staff']);
    final confirm = _stringOrNull(item['department_confirm']);
    final assetInfo = item['asset_info'];
    if (inspector != null) {
      lines.add('점검자: $inspector');
    }
    if (team != null) {
      lines.add('소속: $team');
    }
    if (assetInfo is Map<String, dynamic>) {
      final usage = _stringOrNull(assetInfo['usage']);
      final model = _stringOrNull(assetInfo['model_name']);
      final serial = _stringOrNull(assetInfo['serial_number']);
      if (usage != null) {
        lines.add('용도: $usage');
      }
      if (model != null) {
        lines.add('모델: $model');
      }
      if (serial != null) {
        lines.add('시리얼: $serial');
      }
    }
    if (maintenance != null) {
      lines.add('유지보수: $maintenance');
    }
    if (confirm != null) {
      lines.add('확인부서: $confirm');
    }
    if (lines.isEmpty) {
      return null;
    }
    return lines.join('\n');
  }
}
