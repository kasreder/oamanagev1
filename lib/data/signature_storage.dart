import 'dart:typed_data';

import 'signature_storage_result.dart';
import 'signature_storage_io.dart'
    if (dart.library.html) 'signature_storage_web.dart' as storage_impl;

class SignatureStorage {
  const SignatureStorage._();

  static Future<StoredSignature> save({
    required Uint8List data,
    required String assetUid,
    required String userName,
    required String employeeId,
  }) {
    return storage_impl.save(
      data: data,
      assetUid: assetUid,
      userName: userName,
      employeeId: employeeId,
    );
  }

  static Future<StoredSignature?> find({
    required String assetUid,
    required String userName,
    required String employeeId,
  }) {
    return storage_impl.find(
      assetUid: assetUid,
      userName: userName,
      employeeId: employeeId,
    );
  }
}
