import 'dart:typed_data';

import '../../data/signature_storage.dart';
import '../../providers/inspection_provider.dart';

class SignatureData {
  const SignatureData({required this.location, required this.bytes});

  final String location;
  final Uint8List bytes;
}

String signatureCacheKey(String assetUid, UserInfo? user) {
  final normalizedAsset = assetUid.trim().toLowerCase();
  final normalizedUserId = user?.id.trim() ?? '';
  final normalizedUserName = user?.name.trim() ?? '';
  return '$normalizedAsset::$normalizedUserId::$normalizedUserName';
}

Future<bool> signatureExists({
  required String assetUid,
  required UserInfo? user,
}) async {
  final normalizedAsset = assetUid.trim();
  final normalizedUser = user;
  if (normalizedAsset.isEmpty ||
      normalizedUser == null ||
      normalizedUser.id.trim().isEmpty ||
      normalizedUser.name.trim().isEmpty) {
    return false;
  }

  final storedSignature = await SignatureStorage.find(
    assetUid: normalizedAsset,
    userName: normalizedUser.name.trim(),
    employeeId: normalizedUser.id.trim(),
  );
  return storedSignature != null;
}

Future<SignatureData?> loadSignatureData({
  required String assetUid,
  required UserInfo? user,
}) async {
  final normalizedAsset = assetUid.trim();
  final normalizedUser = user;
  if (normalizedAsset.isEmpty ||
      normalizedUser == null ||
      normalizedUser.id.trim().isEmpty ||
      normalizedUser.name.trim().isEmpty) {
    return null;
  }

  final storedSignature = await SignatureStorage.find(
    assetUid: normalizedAsset,
    userName: normalizedUser.name.trim(),
    employeeId: normalizedUser.id.trim(),
  );
  if (storedSignature == null) {
    return null;
  }

  final bytes = await SignatureStorage.loadBytes(
    assetUid: normalizedAsset,
    userName: normalizedUser.name.trim(),
    employeeId: normalizedUser.id.trim(),
  );
  if (bytes == null) {
    return null;
  }

  return SignatureData(location: storedSignature.location, bytes: bytes);
}
