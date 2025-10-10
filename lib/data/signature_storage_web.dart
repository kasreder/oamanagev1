import 'dart:convert';
import 'dart:typed_data';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;

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
  try {
    final directory = await _ensureDirectory();
    if (directory == null) {
      throw UnsupportedError('Unable to access browser file system directory.');
    }
    final fileName = _buildFileName(assetUid, userName, employeeId);
    final fileHandle = await _createFileHandle(directory, fileName);
    final webpBytes = _encodeToWebp(data);

    await _writeFile(fileHandle, webpBytes);
    _removeLegacyLocalStorageEntries(
      assetUid: assetUid,
      userName: userName,
      employeeId: employeeId,
    );
    return StoredSignature(location: 'assets/dummy/sign/$fileName');
  } on UnsupportedError {
    return _saveToLocalStorage(
      data: data,
      assetUid: assetUid,
      userName: userName,
      employeeId: employeeId,
    );
  }
}

Future<StoredSignature?> find({
  required String assetUid,
  required String userName,
  required String employeeId,
}) async {
  try {
    final directory = await _ensureDirectory(optional: true);
    if (directory == null) {
      return _findInLocalStorage(
        assetUid: assetUid,
        userName: userName,
        employeeId: employeeId,
      );
    }
    final fileName = _buildFileName(assetUid, userName, employeeId);
    final fileHandle = await _getExistingOrLegacyFileHandle(
      directory,
      fileName,
      assetUid: assetUid,
      userName: userName,
      employeeId: employeeId,
    );
    if (fileHandle == null) {
      return null;
    }
    return StoredSignature(location: 'assets/dummy/sign/$fileName');
  } on UnsupportedError {
    return _findInLocalStorage(
      assetUid: assetUid,
      userName: userName,
      employeeId: employeeId,
    );
  }
}

Future<Uint8List?> loadBytes({
  required String assetUid,
  required String userName,
  required String employeeId,
}) async {
  try {
    final directory = await _ensureDirectory(optional: true);
    if (directory == null) {
      return _loadBytesFromLocalStorage(
        assetUid: assetUid,
        userName: userName,
        employeeId: employeeId,
      );
    }
    final fileName = _buildFileName(assetUid, userName, employeeId);
    final fileHandle = await _getExistingOrLegacyFileHandle(
      directory,
      fileName,
      assetUid: assetUid,
      userName: userName,
      employeeId: employeeId,
    );
    if (fileHandle == null) {
      return null;
    }
    return _readFile(fileHandle);
  } on UnsupportedError {
    return _loadBytesFromLocalStorage(
      assetUid: assetUid,
      userName: userName,
      employeeId: employeeId,
    );
  }
}

String _buildFileName(String assetUid, String userName, String employeeId) {
  final fileName = buildSignatureFileName(assetUid, userName, employeeId);
  return '$fileName.webp';
}

Uint8List _encodeToWebp(Uint8List data) {

  final decoded = img.decodeImage(data);
  if (decoded == null) {
    throw const FormatException('Unable to decode signature image data');
  }
  final encoded = img.encodeWebp(

    decoded,
    quality: 100,
    lossless: true,
  );
  return Uint8List.fromList(encoded);
}

Future<Object?> _ensureDirectory({bool optional = false}) async {

  final storage = html.window.navigator.storage;
  if (storage == null) {
    if (optional) {
      return null;
    }
    throw UnsupportedError('File system access API is not supported on this browser.');
  }

  final dynamic rootHandle;
  try {
    rootHandle = await js_util.promiseToFuture<Object?>(
      js_util.callMethod(storage, 'getDirectory', []),
    );
  } on Object {
    if (optional) {
      return null;
    }
    throw UnsupportedError('Unable to access browser file system directory.');
  }

  if (rootHandle == null ||
      !js_util.hasProperty(rootHandle, 'getDirectoryHandle')) {

    if (optional) {
      return null;
    }
    throw UnsupportedError('Unable to access browser file system directory.');
  }

  var current = rootHandle;

  final segments = ['assets', 'dummy', 'sign'];
  for (final segment in segments) {
    final create = !optional;
    try {
      current = await js_util.promiseToFuture<Object>(

        js_util.callMethod(
          current,
          'getDirectoryHandle',
          [segment, js_util.jsify({'create': create})],
        ),
      );
    } on Object {
      if (optional) {
        return null;
      }
      throw UnsupportedError('Unable to open browser file system directory.');

    }
  }

  return current;
}

Future<Object> _createFileHandle(
  Object directory,
  String fileName,
) async {
  try {
    return await js_util.promiseToFuture<Object>(
      js_util.callMethod(
        directory,
        'getFileHandle',
        [fileName, js_util.jsify({'create': true})],
      ),
    );
  } on Object {
    throw UnsupportedError('Unable to create browser file handle.');
  }
}

Future<Object?> _getExistingFileHandle(
  Object directory,
  String fileName,
) async {
  try {
    return await js_util.promiseToFuture<Object>(
      js_util.callMethod(
        directory,
        'getFileHandle',
        [fileName, js_util.jsify({'create': false})],
      ),
    );
  } on Object {
    return null;
  }
}

Future<Object?> _getExistingOrLegacyFileHandle(
  Object directory,
  String fileName,
  {
  required String assetUid,
  required String userName,
  required String employeeId,
}
) async {
  final existing = await _getExistingFileHandle(directory, fileName);
  if (existing != null) {
    return existing;
  }
  return _migrateLegacyEntry(
    directory,
    fileName,
    assetUid: assetUid,
    userName: userName,
    employeeId: employeeId,
  );
}

Future<void> _writeFile(Object handle, Uint8List bytes) async {
  try {
    final writable = await js_util.promiseToFuture<Object>(
      js_util.callMethod(handle, 'createWritable', []),
    );
    await js_util.promiseToFuture<void>(
      js_util.callMethod(writable, 'write', [bytes]),
    );
    await js_util.promiseToFuture<void>(
      js_util.callMethod(writable, 'close', []),
    );
  } on Object {
    throw UnsupportedError('Unable to write browser file handle.');
  }
}

Future<Uint8List?> _readFile(Object handle) async {
  try {
    final file = await js_util.promiseToFuture<html.File>(
      js_util.callMethod(handle, 'getFile', []),
    );
    final buffer = await js_util.promiseToFuture<Object>(
      js_util.callMethod(file, 'arrayBuffer', []),
    );
    if (buffer is ByteBuffer) {
      return Uint8List.view(buffer);
    }
    final sliced = js_util.callMethod<Object?>(buffer, 'slice', []);
    if (sliced is ByteBuffer) {
      return Uint8List.view(sliced);
    }
    return null;
  } on UnsupportedError {
    rethrow;
  } on Object {
    throw UnsupportedError('Unable to read browser file handle.');
  }
}

Future<Object?> _migrateLegacyEntry(
  Object directory,
  String fileName,
  {
  required String assetUid,
  required String userName,
  required String employeeId,
}
) async {
  final storageBaseKey =
      _buildStorageBaseKey(assetUid, userName, employeeId);
  final candidates = <String>[
    '$storageBaseKey.webp',
    storageBaseKey,
  ];

  for (final key in candidates) {
    final encoded = html.window.localStorage[key];
    if (encoded == null) {
      continue;
    }

    try {
      final legacyBytes = Uint8List.fromList(base64Decode(encoded));
      final webpBytes = _encodeToWebp(legacyBytes);
      final fileHandle = await _createFileHandle(directory, fileName);
      await _writeFile(fileHandle, webpBytes);
      html.window.localStorage.remove(key);
      return fileHandle;
    } on Object {
      // If decoding fails, fall through and try the next candidate.
    }
  }

  return null;
}

Future<StoredSignature> _saveToLocalStorage({
  required Uint8List data,
  required String assetUid,
  required String userName,
  required String employeeId,
}) async {
  final baseKey = _buildStorageBaseKey(assetUid, userName, employeeId);
  final key = '$baseKey.webp';
  final webpBytes = _encodeToWebp(data);
  html.window.localStorage[key] = base64Encode(webpBytes);
  html.window.localStorage.remove(baseKey);
  return StoredSignature(location: 'localStorage://$key');
}

Future<StoredSignature?> _findInLocalStorage({
  required String assetUid,
  required String userName,
  required String employeeId,
}) async {
  final baseKey = _buildStorageBaseKey(assetUid, userName, employeeId);
  final candidates = <String>['$baseKey.webp', baseKey];
  for (final key in candidates) {
    if (html.window.localStorage.containsKey(key)) {
      return StoredSignature(location: 'localStorage://$key');
    }
  }
  return null;
}

Future<Uint8List?> _loadBytesFromLocalStorage({
  required String assetUid,
  required String userName,
  required String employeeId,
}) async {
  final baseKey = _buildStorageBaseKey(assetUid, userName, employeeId);
  final candidates = <String>['$baseKey.webp', baseKey];
  for (final key in candidates) {
    final encoded = html.window.localStorage[key];
    if (encoded == null) {
      continue;
    }
    try {
      final bytes = Uint8List.fromList(base64Decode(encoded));
      return bytes;
    } on Object {
      // ignore malformed legacy data and try the next candidate
    }
  }
  return null;
}

void _removeLegacyLocalStorageEntries({
  required String assetUid,
  required String userName,
  required String employeeId,
}) {
  final baseKey = _buildStorageBaseKey(assetUid, userName, employeeId);
  final candidates = <String>['$baseKey.webp', baseKey];
  for (final key in candidates) {
    html.window.localStorage.remove(key);
  }
}

String _buildStorageBaseKey(
  String assetUid,
  String userName,
  String employeeId,
) {
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
