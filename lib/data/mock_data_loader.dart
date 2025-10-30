import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/asset_info.dart';
import '../models/inspection.dart';
import '../models/user_info.dart';

const _mockRoot = 'assets/dummy/mock';
const _fallbackRoot = 'assets/mock';

const _assetCoreKeys = <String>{
  'id',
  'asset_uid',
  'uid',
  'name',
  'assets_status',
  'status',
  'assets_types',
  'assetType',
  'serial_number',
  'serialNumber',
  'model_name',
  'modelName',
  'vendor',
  'organization',
  'network',
  'building1',
  'building',
  'floor',
  'location',
  'location_drawing_id',
  'location_row',
  'location_col',
  'location_drawing_file',
  'member_name',
  'user_id',
  'userId',
  'created_at',
  'updated_at',
};

/// Loads mock JSON data from the Flutter asset bundle.
///
/// The app relies on this data as a local/offline fallback when the
/// backend API is unreachable. The implementation mirrors the logic from
/// the original repository-based loaders so that the in-memory models keep
/// their structure consistent with the /docs specifications.
class MockDataLoader {
  const MockDataLoader();

  Future<List<Inspection>> loadInspections() async {
    final raw = await _loadJsonList('asset_inspections.json');
    final statusMap = await _loadAssetStatusMap();
    final inspections = <Inspection>[];
    for (final item in raw) {
      final assetUid = _stringOrNull(item['asset_code']) ?? _stringOrNull(item['assetUid']);
      if (assetUid == null) {
        continue;
      }
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
      final assetType = _stringOrNull(item['asset_type']) ?? _stringOrNull(item['assetType']);
      final barcodePhoto = _stringOrNull(item['barcode_photo']) ??
          _stringOrNull(item['barcodePhoto']) ??
          _stringOrNull(item['barcode_photo_url']) ??
          _stringOrNull(item['barcodePhotoUrl']);
      inspections.add(
        Inspection(
          id: id,
          assetUid: assetUid,
          status: statusMap[assetUid] ?? _stringOrNull(item['status']) ?? '사용',
          memo: memo,
          scannedAt: parsedDate,
          synced: item['synced'] as bool? ?? ((item['inspection_count'] as int? ?? 0) % 2 == 0),
          userTeam: _stringOrNull(item['user_team']),
          userId: _stringOrNull(item['user_id']) ?? _stringOrNull(item['userId']),
          assetType: assetType,
          isVerified: item['is_verified'] as bool? ?? item['isVerified'] as bool? ?? true,
          barcodePhotoUrl: barcodePhoto,
        ),
      );
    }
    inspections.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return inspections;
  }

  Future<List<AssetInfo>> loadAssets() async {
    final raw = await _loadJsonList('assets.json');
    final assets = <AssetInfo>[];
    for (final item in raw) {
      final uid = _stringOrNull(item['asset_uid']) ?? _stringOrNull(item['uid']);
      if (uid == null) {
        continue;
      }
      final metadata = <String, String>{};
      for (final entry in item.entries) {
        if (_assetCoreKeys.contains(entry.key)) {
          continue;
        }
        final value = _stringOrNull(entry.value);
        if (value != null) {
          metadata[entry.key] = value;
        }
      }
      final ownerId = _stringOrNull(item['user_id']) ?? _stringOrNull(item['userId']);
      final ownerName = _stringOrNull(item['member_name']);
      assets.add(
        AssetInfo(
          uid: uid,
          name: _stringOrNull(item['name']) ?? ownerName ?? '미배정',
          model: _stringOrNull(item['model_name']) ?? _stringOrNull(item['modelName']) ?? '',
          serial: _stringOrNull(item['serial_number']) ?? _stringOrNull(item['serialNumber']) ?? '',
          vendor: _stringOrNull(item['vendor']) ?? '',
          location: _resolveLocation(item),
          status: _stringOrNull(item['assets_status']) ?? _stringOrNull(item['status']) ?? '사용',
          assetsTypes: _stringOrNull(item['assets_types']) ?? _stringOrNull(item['assetType']) ?? '',
          organization: _stringOrNull(item['organization']) ?? '',
          owner: ownerId != null || ownerName != null
              ? OwnerInfo(
                  id: ownerId ?? ownerName ?? '',
                  name: ownerName ?? ownerId ?? '',
                  department: _resolveDepartment(item),
                )
              : null,
          barcodePhotoUrl: metadata['barcode_photo_url'] ?? metadata['barcodePhotoUrl'],
          metadata: metadata,
        ),
      );
    }
    return assets;
  }

  Future<List<UserInfo>> loadUsers() async {
    final raw = await _loadJsonList('users.json');
    return raw
        .map(
          (item) => UserInfo(
            id: _stringOrNull(item['employee_id']) ?? _stringOrNull(item['id']) ?? '',
            name: _stringOrNull(item['employee_name']) ?? _stringOrNull(item['name']) ?? '미상',
            department: _resolveDepartment(item) ?? '',
            employeeId: _stringOrNull(item['employee_id']),
            numericId: _stringOrNull(item['id']),
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, String>> _loadAssetStatusMap() async {
    final raw = await _loadJsonList('assets.json');
    final map = <String, String>{};
    for (final item in raw) {
      final uid = _stringOrNull(item['asset_uid']) ?? _stringOrNull(item['uid']);
      if (uid == null) {
        continue;
      }
      final status = _stringOrNull(item['assets_status']) ?? _stringOrNull(item['status']);
      if (status != null) {
        map[uid] = status;
      }
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> _loadJsonList(String fileName) async {
    final path = '$_mockRoot/$fileName';
    try {
      final raw = await rootBundle.loadString(path);
      return _decodeList(raw);
    } on FlutterError catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to load $path: $error. Falling back to legacy assets.');
      }
      final fallbackRaw = await rootBundle.loadString('$_fallbackRoot/$fileName');
      return _decodeList(fallbackRaw);
    }
  }

  List<Map<String, dynamic>> _decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Expected JSON array data.');
    }
    return decoded.cast<Map<String, dynamic>>();
  }

  String? _stringOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }

  String? _resolveDepartment(Map<String, dynamic> item) {
    final parts = <String?>[
      _stringOrNull(item['organization_hq']),
      _stringOrNull(item['organization_dept']),
      _stringOrNull(item['organization_team']),
      _stringOrNull(item['organization_part']),
    ]..removeWhere((element) => element == null || element.isEmpty);
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' > ');
  }

  String _resolveLocation(Map<String, dynamic> item) {
    final parts = <String?>[
      _stringOrNull(item['building1']),
      _stringOrNull(item['building']),
      _stringOrNull(item['floor']),
    ];
    final row = item['location_row'];
    final col = item['location_col'];
    if (row != null) {
      parts.add('R$row');
    }
    if (col != null) {
      parts.add('C$col');
    }
    parts.removeWhere((element) => element == null || element.isEmpty);
    return parts.join(' ');
  }

  String? _buildMemo(Map<String, dynamic> item) {
    final buffer = StringBuffer();
    final normalComment = _stringOrNull(item['normal_comment']);
    final oaComment = _stringOrNull(item['oa_comment']);
    if (normalComment != null) {
      buffer.write(normalComment);
    }
    if (oaComment != null) {
      if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      buffer.write(oaComment);
    }
    return buffer.isEmpty ? null : buffer.toString();
  }
}
