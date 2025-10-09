String buildSignatureFileName(
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
