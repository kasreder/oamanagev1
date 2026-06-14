import 'package:flutter/material.dart';

/// OS 보안 표기 등급
/// good — 보안 정보 양호
/// caution — Android 90~180일 경과 등
/// danger — Android 180일 초과 등
/// notCollected — 에이전트가 값을 수집하지 않은 경우
/// notImplemented — 해당 OS 에이전트가 아직 보안 정보를 수집하지 않는 경우
enum OsSecurityStatus { good, caution, danger, notCollected, notImplemented }

class OsSecurityVerdict {
  /// 컬럼/칩에 그대로 표기되는 값. OS별 표기법 (OS 버전 컬럼과 중복되지 않는 보안 식별자):
  ///   - Android        → YYYY-MM-DD (security_patch)
  ///   - Windows        → Build/UBR  (예: 19045.5247)
  ///   - macOS          → Build XXXX (예: Build 24A348)
  ///   - Linux          → 커널 / 패키지 업데이트 일 (현재 미수집)
  ///   - iOS/iPadOS     → 마이너 버전 (예: 19.1.1) — 에이전트 미구현
  ///   - 그 외 / 미수집 → '미수집' 또는 '-'
  final String label;
  final OsSecurityStatus status;
  final String detail;
  const OsSecurityVerdict(this.status, this.label, this.detail);

  Color color(BuildContext ctx) {
    switch (status) {
      case OsSecurityStatus.good:
        return Colors.green.shade700;
      case OsSecurityStatus.caution:
        return Colors.orange.shade700;
      case OsSecurityStatus.danger:
        return Colors.red.shade700;
      case OsSecurityStatus.notCollected:
        return Theme.of(ctx).colorScheme.outline;
      case OsSecurityStatus.notImplemented:
        return Colors.purple;
    }
  }

  IconData get icon {
    switch (status) {
      case OsSecurityStatus.good:
        return Icons.shield;
      case OsSecurityStatus.caution:
        return Icons.warning_amber;
      case OsSecurityStatus.danger:
        return Icons.dangerous;
      case OsSecurityStatus.notCollected:
        return Icons.help_outline;
      case OsSecurityStatus.notImplemented:
        return Icons.build_circle_outlined;
    }
  }
}

/// 자산의 specifications -> device_status JSONB를 입력으로 받아 OS 보안 상태를 평가.
/// OS 버전은 별도 컬럼에서 표기하므로 OS 종류 자체는 노출하지 않고, 보안 식별자(패치 날짜 / Build / UBR 등)만 라벨로 반환한다.
OsSecurityVerdict evaluateOsSecurity(Map<String, dynamic>? deviceStatus) {
  if (deviceStatus == null || deviceStatus.isEmpty) {
    return const OsSecurityVerdict(
      OsSecurityStatus.notCollected,
      '미수집',
      '에이전트 정보 없음',
    );
  }
  final osVer = (deviceStatus['os_version'] as String?)?.toLowerCase() ?? '';

  if (osVer.contains('android')) return _evalAndroid(deviceStatus);
  if (osVer.contains('windows')) return _evalWindows(deviceStatus);
  if (osVer.contains('mac')) return _evalMac(deviceStatus);
  if (osVer.contains('linux') ||
      osVer.contains('ubuntu') ||
      osVer.contains('debian') ||
      osVer.contains('rhel') ||
      osVer.contains('centos') ||
      osVer.contains('fedora')) {
    return const OsSecurityVerdict(
      OsSecurityStatus.notImplemented,
      '미구현',
      'Linux: 커널 버전 + 배포판 패키지 업데이트 날짜 (수집 미구현)',
    );
  }
  if (osVer.contains('ios') || osVer.contains('ipados')) {
    return const OsSecurityVerdict(
      OsSecurityStatus.notImplemented,
      '미구현',
      'iOS/iPadOS: 마이너 버전 (예: 19.1.1) — 에이전트 미구현',
    );
  }
  return const OsSecurityVerdict(
    OsSecurityStatus.notCollected,
    '-',
    'OS 종류를 판정할 수 없음',
  );
}

OsSecurityVerdict _evalAndroid(Map<String, dynamic> ds) {
  final patch = (ds['os_security_patch'] as String?) ?? '';
  if (patch.isEmpty) {
    return const OsSecurityVerdict(
      OsSecurityStatus.notCollected,
      '미수집',
      '보안패치 날짜가 수집되지 않음',
    );
  }
  final regex = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  final m = regex.firstMatch(patch);
  if (m == null) {
    return OsSecurityVerdict(
      OsSecurityStatus.notCollected,
      patch,
      '보안패치 날짜 형식 오류',
    );
  }
  final patchDate = DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
  final age = DateTime.now().difference(patchDate).inDays;
  // 라벨은 항상 패치 날짜 그대로. 색만 등급에 따라.
  if (age > 180) {
    return OsSecurityVerdict(OsSecurityStatus.danger, patch, '$age일 경과 (위험: 180일+)');
  }
  if (age > 90) {
    return OsSecurityVerdict(OsSecurityStatus.caution, patch, '$age일 경과 (주의: 90일+)');
  }
  return OsSecurityVerdict(OsSecurityStatus.good, patch, '$age일 경과 (양호)');
}

OsSecurityVerdict _evalWindows(Map<String, dynamic> ds) {
  final build = (ds['os_build_number'] as String?) ?? '';
  final ubr = (ds['os_ubr'] as String?) ?? '';
  final kb = (ds['os_kb_list'] as String?) ?? '';
  if (build.isEmpty && ubr.isEmpty) {
    return const OsSecurityVerdict(
      OsSecurityStatus.notCollected,
      '미수집',
      'OS Build / UBR 미수집',
    );
  }
  final label = '${build.isEmpty ? '?' : build}.${ubr.isEmpty ? '?' : ubr}';
  final kbCount =
      kb.isEmpty ? 0 : kb.split(',').where((e) => e.trim().isNotEmpty).length;
  return OsSecurityVerdict(
    OsSecurityStatus.good,
    label,
    'Build $build / UBR $ubr / KB $kbCount건',
  );
}

OsSecurityVerdict _evalMac(Map<String, dynamic> ds) {
  final build = (ds['os_build_number'] as String?) ?? '';
  if (build.isEmpty) {
    return const OsSecurityVerdict(
      OsSecurityStatus.notCollected,
      '미수집',
      '시스템 빌드 번호 미수집',
    );
  }
  return OsSecurityVerdict(
    OsSecurityStatus.good,
    'Build $build',
    '시스템 빌드 $build',
  );
}
