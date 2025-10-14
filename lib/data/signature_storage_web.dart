import 'dart:convert';
import 'dart:typed_data';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:image/image.dart' as img;
import 'signature_storage_result.dart';
import 'signature_storage_shared.dart';

typedef _SignatureHandle = ({Object handle, String fileName});

const _storagePrefix = 'signature_storage:';
const _signatureExtension = signatureFileExtension;
const _legacyLocalStorageSuffixes = ['.webp', ''];

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
    final baseFileName = _buildBaseFileName(assetUid, userName, employeeId);
    final fileName = '$baseFileName$_signatureExtension';
    final fileHandle = await _createFileHandle(directory, fileName);
    final pngBytes = _encodeToPng(data);

    await _writeFile(fileHandle, pngBytes);
    for (final legacyFileName in _legacyFileNames(
      assetUid: assetUid,
      userName: userName,
      employeeId: employeeId,
      currentBaseName: baseFileName,
    )) {
      await _removeFile(directory, legacyFileName);
    }
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
    final signatureHandle = await _getExistingOrLegacyFileHandle(
      directory,
      fileName,
      assetUid: assetUid,
      userName: userName,
      employeeId: employeeId,
    );
    if (signatureHandle == null) {
      return null;
    }
    return StoredSignature(
      location: 'assets/dummy/sign/${signatureHandle.fileName}',
    );
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
    final signatureHandle = await _getExistingOrLegacyFileHandle(
      directory,
      fileName,
      assetUid: assetUid,
      userName: userName,
      employeeId: employeeId,
    );
    if (signatureHandle == null) {
      return null;
    }
    return _readFile(signatureHandle.handle);
  } on UnsupportedError {
    return _loadBytesFromLocalStorage(
      assetUid: assetUid,
      userName: userName,
      employeeId: employeeId,
    );
  }
}

String _buildBaseFileName(String assetUid, String userName, String employeeId) {
  return buildSignatureFileName(assetUid, userName, employeeId);
}

String _buildFileName(String assetUid, String userName, String employeeId) {
  return '${_buildBaseFileName(assetUid, userName, employeeId)}$_signatureExtension';
}

Uint8List _encodeToPng(Uint8List data) {
  final decoded = img.decodeImage(data);
  if (decoded == null) {
    throw const FormatException('Unable to decode signature image data');
  }
  final encoded = img.encodePng(decoded);
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

Future<_SignatureHandle?> _getExistingOrLegacyFileHandle(
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
    return (handle: existing, fileName: fileName);
  }

  final currentBaseName = fileName.endsWith(_signatureExtension)
      ? fileName.substring(0, fileName.length - _signatureExtension.length)
      : fileName;

  for (final legacyFileName in _legacyFileNames(
    assetUid: assetUid,
    userName: userName,
    employeeId: employeeId,
    currentBaseName: currentBaseName,
  )) {
    final legacyHandle =
        await _getExistingFileHandle(directory, legacyFileName);
    if (legacyHandle == null) {
      continue;
    }

    final migrated = await _migrateLegacyFile(
      directory: directory,
      legacyHandle: legacyHandle,
      legacyFileName: legacyFileName,
      targetFileName: fileName,
    );
    if (migrated != null) {
      return migrated;
    }
    return (handle: legacyHandle, fileName: legacyFileName);
  }

  final migratedHandle = await _migrateLegacyEntry(
    directory,
    fileName,
    assetUid: assetUid,
    userName: userName,
    employeeId: employeeId,
  );
  if (migratedHandle != null) {
    return (handle: migratedHandle, fileName: fileName);
  }

  return null;
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
  for (final key in _legacyStorageKeys(assetUid, userName, employeeId)) {
    final encoded = html.window.localStorage[key];
    if (encoded == null) {
      continue;
    }

    try {
      final legacyBytes = Uint8List.fromList(base64Decode(encoded));
      final pngBytes = _encodeToPng(legacyBytes);
      final fileHandle = await _createFileHandle(directory, fileName);
      await _writeFile(fileHandle, pngBytes);
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
  final key = _buildStorageKey(assetUid, userName, employeeId);
  final pngBytes = _encodeToPng(data);
  html.window.localStorage[key] = base64Encode(pngBytes);
  for (final legacyKey in _legacyStorageKeys(assetUid, userName, employeeId)) {
    if (legacyKey == key) {
      continue;
    }
    html.window.localStorage.remove(legacyKey);
  }
  return StoredSignature(location: 'localStorage://$key');
}

Future<StoredSignature?> _findInLocalStorage({
  required String assetUid,
  required String userName,
  required String employeeId,
}) async {
  for (final key in _storageKeyCandidates(assetUid, userName, employeeId)) {
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
  for (final key in _storageKeyCandidates(assetUid, userName, employeeId)) {
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
  for (final key in _storageKeyCandidates(assetUid, userName, employeeId)) {
    html.window.localStorage.remove(key);
  }
}

Iterable<String> _storageKeyCandidates(
  String assetUid,
  String userName,
  String employeeId,
) sync* {
  for (final baseName in buildSignatureFileNameCandidates(assetUid, userName, employeeId)) {
    final baseKey = '$_storagePrefix$baseName';
    yield '$baseKey$_signatureExtension';
    for (final suffix in _legacyLocalStorageSuffixes) {
      yield '$baseKey$suffix';
    }
  }
}

String _buildStorageKey(
  String assetUid,
  String userName,
  String employeeId,
) {
  final baseName = _buildBaseFileName(assetUid, userName, employeeId);
  return '$_storagePrefix$baseName$_signatureExtension';
}

Iterable<String> _legacyStorageKeys(
  String assetUid,
  String userName,
  String employeeId,
) sync* {
  for (final baseName in buildSignatureFileNameCandidates(assetUid, userName, employeeId)) {
    final baseKey = '$_storagePrefix$baseName';
    yield '$baseKey$_signatureExtension';
    for (final suffix in _legacyLocalStorageSuffixes) {
      yield '$baseKey$suffix';
    }
  }
}

Iterable<String> _legacyFileNames({
  required String assetUid,
  required String userName,
  required String employeeId,
  required String currentBaseName,
}) sync* {
  for (final baseName in buildSignatureFileNameCandidates(assetUid, userName, employeeId)) {
    final isCurrent = baseName == currentBaseName;
    if (!isCurrent) {
      yield '$baseName$_signatureExtension';
    }
    for (final extension in legacySignatureFileExtensions) {
      yield '$baseName$extension';
    }
  }
}

Future<_SignatureHandle?> _migrateLegacyFile({
  required Object directory,
  required Object legacyHandle,
  required String legacyFileName,
  required String targetFileName,
}) async {
  try {
    final legacyBytes = await _readFile(legacyHandle);
    if (legacyBytes == null) {
      return null;
    }
    final pngBytes = _encodeToPng(legacyBytes);
    final targetHandle = await _createFileHandle(directory, targetFileName);
    await _writeFile(targetHandle, pngBytes);
    await _removeFile(directory, legacyFileName);
    return (handle: targetHandle, fileName: targetFileName);
  } on Object {
    return null;
  }
}

Future<void> _removeFile(Object directory, String fileName) async {
  try {
    await js_util.promiseToFuture<void>(
      js_util.callMethod(directory, 'removeEntry', [fileName]),
    );
  } on Object {
    // ignore failures when removing legacy files
  }
}

