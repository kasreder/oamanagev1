const signatureFileExtension = '.png';
const legacySignatureFileExtensions = ['.webp'];
const _verificationSuffix = '인증확인';

String buildSignatureFileName(
  String assetUid,
  String userName,
  String employeeId,
) {
  final baseName = _buildBaseName(assetUid, userName, employeeId);
  final suffix = _sanitize(_verificationSuffix);
  return '${baseName}_$suffix';
}

Iterable<String> buildSignatureFileNameCandidates(
  String assetUid,
  String userName,
  String employeeId,
) sync* {
  yield buildSignatureFileName(assetUid, userName, employeeId);
  yield* buildLegacySignatureFileNames(assetUid, userName, employeeId);
}

Iterable<String> buildLegacySignatureFileNames(
  String assetUid,
  String userName,
  String employeeId,
) sync* {
  yield _buildBaseName(assetUid, userName, employeeId);
}

String _buildBaseName(
  String assetUid,
  String userName,
  String employeeId,
) {
  final normalizedAsset = _sanitize(assetUid);
  final normalizedUser = _sanitize(userName);
  final normalizedEmployee = _sanitize(employeeId);
  return '${normalizedAsset}_${normalizedUser}_${normalizedEmployee}';
}

String _sanitize(String value) {
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
