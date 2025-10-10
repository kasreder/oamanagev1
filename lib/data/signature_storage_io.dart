import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
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
  final file = File('${directory.path}/$fileName.webp');
  final decoded = img.decodeImage(data);
  if (decoded == null) {
    throw const FormatException('Unable to decode signature image data');
  }
  final encoded = img.encodeWebP(
    decoded,
    quality: 100,
    lossless: true,
  );
  await file.writeAsBytes(encoded, flush: true);
  return StoredSignature(location: file.path);
}

Future<StoredSignature?> find({
  required String assetUid,
  required String userName,
  required String employeeId,
}) async {
  final directory = await _ensureDirectory();
  final fileName = buildSignatureFileName(assetUid, userName, employeeId);
  final file = File('${directory.path}/$fileName.webp');
  if (await file.exists()) {
    return StoredSignature(location: file.path);
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
  final file = File('${directory.path}/$fileName.webp');
  if (await file.exists()) {
    return file.readAsBytes();
  }
  return null;
}

Future<Directory> _ensureDirectory() async {
  final target = Directory('assets/dummy/sign');
  if (!await target.exists()) {
    await target.create(recursive: true);
  }
  return target;
}
