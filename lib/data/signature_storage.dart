import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class SignatureStorage {
  const SignatureStorage._();

  static Future<File> save({
    required Uint8List data,
    required String assetUid,
    required String userName,
    required String employeeId,
  }) async {
    final directory = await _ensureDirectory();
    final fileName = _buildFileName(assetUid, userName, employeeId);
    final file = File('${directory.path}/$fileName.png');
    await file.writeAsBytes(data, flush: true);
    return file;
  }

  static Future<File?> find({
    required String assetUid,
    required String userName,
    required String employeeId,
  }) async {
    final directory = await _ensureDirectory();
    final fileName = _buildFileName(assetUid, userName, employeeId);
    final file = File('${directory.path}/$fileName.png');
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  static Future<Directory> _ensureDirectory() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final target = Directory('${baseDir.path}/assets/dummy/sign');
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    return target;
  }

  static String _buildFileName(String assetUid, String userName, String employeeId) {
    final normalizedAsset = _sanitize(assetUid);
    final normalizedUser = _sanitize(userName);
    final normalizedEmployee = _sanitize(employeeId);
    return '${normalizedAsset}_${normalizedUser}_${normalizedEmployee}';
  }

  static String _sanitize(String value) {
    final trimmed = value.trim();
    final buffer = StringBuffer();
    final allowed = RegExp(r'[a-zA-Z0-9가-힣_-]');
    final whitespace = RegExp(r'[\s]');
    for (final codeUnit in trimmed.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      if (allowed.hasMatch(char)) {
        buffer.write(char);
      } else if (whitespace.hasMatch(char)) {
        buffer.write('_');
      }
    }
    final result = buffer.toString();
    return result.isEmpty ? 'unknown' : result;
  }
}
