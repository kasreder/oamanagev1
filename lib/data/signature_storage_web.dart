import 'dart:convert';
import 'dart:typed_data';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:image/image.dart' as img;

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
  final webpBytes = _encodeToWebP(data);
  html.window.localStorage[key] = base64Encode(webpBytes);
  return StoredSignature(location: 'localStorage://$key');
}

Future<StoredSignature?> find({
  required String assetUid,
  required String userName,
  required String employeeId,
}) async {
  final key = _buildStorageKey(assetUid, userName, employeeId);
  final hasEntry = _ensureWebPEntryExists(key);
  if (!hasEntry) {
    return null;
  }
  return StoredSignature(location: 'localStorage://$key');
}

Future<Uint8List?> loadBytes({
  required String assetUid,
  required String userName,
  required String employeeId,
}) async {
  final key = _buildStorageKey(assetUid, userName, employeeId);
  final hasEntry = _ensureWebPEntryExists(key);
  if (!hasEntry) {
    return null;
  }
  final encoded = html.window.localStorage[key];
  if (encoded == null) {
    return null;
  }
  return Uint8List.fromList(base64Decode(encoded));
}

String _buildStorageKey(String assetUid, String userName, String employeeId) {
  final fileName = buildSignatureFileName(assetUid, userName, employeeId);
  return '$_storagePrefix$fileName.webp';
}

bool _ensureWebPEntryExists(String key) {
  if (html.window.localStorage.containsKey(key)) {
    return true;
  }

  final legacyKey = _buildLegacyStorageKey(key);
  final legacyEncoded = html.window.localStorage[legacyKey];
  if (legacyEncoded == null) {
    return false;
  }

  final legacyBytes = Uint8List.fromList(base64Decode(legacyEncoded));
  final webpBytes = _encodeToWebP(legacyBytes);
  html.window.localStorage[key] = base64Encode(webpBytes);
  html.window.localStorage.remove(legacyKey);
  return true;
}

String _buildLegacyStorageKey(String key) {
  const suffix = '.webp';
  if (key.endsWith(suffix)) {
    return key.substring(0, key.length - suffix.length);
  }
  return key;
}

Uint8List _encodeToWebP(Uint8List data) {
  final decoded = img.decodeImage(data);
  if (decoded == null) {
    throw const FormatException('Unable to decode signature image data');
  }
  final encoded = img.encodeWebP(
    decoded,
    quality: 100,
    lossless: true,
  );
  return Uint8List.fromList(encoded);
}
