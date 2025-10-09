import 'dart:convert';
import 'dart:typed_data';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'signature_storage_result.dart';
import 'signature_storage_shared.dart';

const _storagePrefix = 'signature_storage:';

Future<StoredSignature> save({
  required Uint8List data,
  required String assetUid,
  required String userName,
  required String employeeId,
}) async {
  final key = _buildStorageKey(assetUid, userName, employeeId);
  final encoded = base64Encode(data);
  html.window.localStorage[key] = encoded;
  return StoredSignature(location: 'localStorage://$key');
}

Future<StoredSignature?> find({
  required String assetUid,
  required String userName,
  required String employeeId,
}) async {
  final key = _buildStorageKey(assetUid, userName, employeeId);
  if (!html.window.localStorage.containsKey(key)) {
    return null;
  }
  return StoredSignature(location: 'localStorage://$key');
}

String _buildStorageKey(String assetUid, String userName, String employeeId) {
  final fileName = buildSignatureFileName(assetUid, userName, employeeId);
  return '$_storagePrefix$fileName';
}
