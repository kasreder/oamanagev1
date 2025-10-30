import 'dart:typed_data';

import 'api_client.dart';
import 'signature_storage_result.dart';
import 'signature_storage_shared.dart';

class SignatureStorage {
  SignatureStorage._();

  static ApiClient? _apiClient;
  static final Map<String, StoredSignature?> _cache = <String, StoredSignature?>{};
  static final Map<String, Uint8List> _byteCache = <String, Uint8List>{};

  static void configure(ApiClient client) {
    _apiClient = client;
  }

  static ApiClient get _client {
    final client = _apiClient;
    if (client == null) {
      throw StateError('SignatureStorage is not configured');
    }
    return client;
  }

  static String _cacheKey({
    required String assetUid,
    required String userName,
    required String employeeId,
  }) {
    return '${assetUid.trim().toLowerCase()}::${userName.trim().toLowerCase()}::${employeeId.trim().toLowerCase()}';
  }

  static Future<StoredSignature> save({
    required Uint8List data,
    required String assetUid,
    required String userName,
    required String employeeId,
  }) async {
    final fileBaseName = buildSignatureFileName(assetUid, userName, employeeId);
    final response = await _client.uploadSignature(
      assetUid: assetUid,
      bytes: data,
      fileName: '$fileBaseName$signatureFileExtension',
      userId: employeeId,
      userName: userName,
    );
    final metaJson = (response['signatureMeta'] as Map<String, dynamic>?) ?? response;
    final stored = StoredSignature.fromJson(metaJson).copyWith(
      location: response['storageLocation'] as String? ?? metaJson['storageLocation'] as String? ?? '',
      assetUid: assetUid,
    );
    final key = _cacheKey(assetUid: assetUid, userName: userName, employeeId: employeeId);
    _cache[key] = stored;
    _byteCache.remove(key);
    return stored;
  }

  static Future<StoredSignature?> find({
    required String assetUid,
    required String userName,
    required String employeeId,
  }) async {
    final key = _cacheKey(assetUid: assetUid, userName: userName, employeeId: employeeId);
    if (_cache.containsKey(key)) {
      return _cache[key];
    }
    final detail = await _client.fetchVerificationDetail(assetUid);
    if (detail == null) {
      _cache[key] = null;
      return null;
    }
    final metaJson = detail['signatureMeta'] as Map<String, dynamic>?;
    if (metaJson == null) {
      _cache[key] = null;
      return null;
    }
    final stored = StoredSignature.fromJson(metaJson);
    if (!_matchesUser(stored, userName: userName, employeeId: employeeId)) {
      _cache[key] = null;
      return null;
    }
    final enriched = stored.copyWith(
      location: metaJson['storageLocation'] as String? ?? stored.location,
      assetUid: stored.assetUid ?? assetUid,
    );
    _cache[key] = enriched;
    return enriched;
  }

  static Future<Uint8List?> loadBytes({
    required String assetUid,
    required String userName,
    required String employeeId,
  }) async {
    final key = _cacheKey(assetUid: assetUid, userName: userName, employeeId: employeeId);
    final cached = _byteCache[key];
    if (cached != null) {
      return cached;
    }
    final stored = await find(
      assetUid: assetUid,
      userName: userName,
      employeeId: employeeId,
    );
    if (stored == null) {
      return null;
    }
    final bytes = await _client.downloadSignature(stored.assetUid ?? assetUid);
    if (bytes != null) {
      _byteCache[key] = bytes;
    }
    return bytes;
  }

  static bool _matchesUser(
    StoredSignature stored, {
    required String userName,
    required String employeeId,
  }) {
    final normalizedEmployeeId = employeeId.trim().toLowerCase();
    final normalizedUserName = userName.trim().toLowerCase();
    final storedId = stored.userId?.trim().toLowerCase();
    final storedName = stored.userName?.trim().toLowerCase();
    if (storedId != null && storedId.isNotEmpty && storedId == normalizedEmployeeId) {
      return true;
    }
    if (storedName != null && storedName.isNotEmpty && storedName == normalizedUserName) {
      return true;
    }
    if (storedId == null && storedName == null) {
      return true;
    }
    return false;
  }
}
