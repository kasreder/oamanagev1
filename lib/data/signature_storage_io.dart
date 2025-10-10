import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'signature_storage_result.dart';
import 'signature_storage_shared.dart';

Future<StoredSignature> save({
  required Uint8List data,
  required String assetUid,
  required String userName,
  required String employeeId,
}) async {
  final directory = await _ensureDirectory();
  final fileName = buildSignatureFileName(assetUid, userName, employeeId);
  final file = File('${directory.path}/$fileName$signatureFileExtension');
  final decoded = img.decodeImage(data);
  if (decoded == null) {
    throw const FormatException('Unable to decode signature image data');
  }
  final encoded = img.encodePng(decoded);
  await file.writeAsBytes(encoded, flush: true);
  for (final legacyExtension in legacySignatureFileExtensions) {
    final legacyFile = File('${directory.path}/$fileName$legacyExtension');
    if (await legacyFile.exists()) {
      await legacyFile.delete();
    }
  }
  return StoredSignature(location: file.path);
}

Future<StoredSignature?> find({
  required String assetUid,
  required String userName,
  required String employeeId,
}) async {
  final directory = await _ensureDirectory();
  final fileName = buildSignatureFileName(assetUid, userName, employeeId);
  final primary = File('${directory.path}/$fileName$signatureFileExtension');
  if (await primary.exists()) {
    return StoredSignature(location: primary.path);
  }
  for (final legacyExtension in legacySignatureFileExtensions) {
    final legacyFile = File('${directory.path}/$fileName$legacyExtension');
    if (await legacyFile.exists()) {
      return StoredSignature(location: legacyFile.path);
    }
  }
  return null;
}

Future<Uint8List?> loadBytes({
  required String assetUid,
  required String userName,
  required String employeeId,
}) async {
  final directory = await _ensureDirectory();
  final fileName = buildSignatureFileName(assetUid, userName, employeeId);
  final primary = File('${directory.path}/$fileName$signatureFileExtension');
  if (await primary.exists()) {
    return primary.readAsBytes();
  }
  for (final legacyExtension in legacySignatureFileExtensions) {
    final legacyFile = File('${directory.path}/$fileName$legacyExtension');
    if (await legacyFile.exists()) {
      return legacyFile.readAsBytes();
    }
  }
  return null;
}

Future<Directory> _ensureDirectory() async {
  final baseDirectory = await path_provider.getApplicationSupportDirectory();
  final target = Directory('${baseDirectory.path}/signatures');
  if (!await target.exists()) {
    await target.create(recursive: true);
  }
  return target;
}
