// lib/view/asset_verification/list_page.dart
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/inspection.dart';
import '../../providers/inspection_provider.dart';
import '../common/app_scaffold.dart';

class AssetVerificationListPage extends StatelessWidget {
  const AssetVerificationListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InspectionProvider>(
      builder: (context, provider, _) {
        final inspections = provider.items;
        if (inspections.isEmpty) {
          return AppScaffold(
            title: '팀별 자산 인증 현황',
            selectedIndex: 2,
            body: const Center(
              child: Text('표시할 자산 실사 이력이 없습니다.'),
            ),
          );
        }
        final grouped = SplayTreeMap<String, List<Inspection>>((a, b) {
          if (a == b) return 0;
          if (a == '미지정 팀') return 1;
          if (b == '미지정 팀') return -1;
          return a.compareTo(b);
        });
        for (final inspection in inspections) {
          final teamName = _normalizeTeamName(inspection.userTeam);
          grouped.putIfAbsent(teamName, () => <Inspection>[]).add(inspection);
        }
        return AppScaffold(
          title: '팀별 자산 인증 현황',
          selectedIndex: 2,
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                for (final inspection in entry.value
                  ..sort((a, b) => a.assetUid.compareTo(b.assetUid)))
                  _InspectionCard(
                    inspection: inspection,
                    provider: provider,
                  ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        );
      },
    );
  }
}

String _normalizeTeamName(String? team) {
  final name = team?.trim();
  if (name == null || name.isEmpty) {
    return '미지정 팀';
  }
  return name;
}

class _InspectionCard extends StatelessWidget {
  const _InspectionCard({
    required this.inspection,
    required this.provider,
  });

  final Inspection inspection;
  final InspectionProvider provider;

  @override
  Widget build(BuildContext context) {
    final asset = provider.assetOf(inspection.assetUid);
    final user = _resolveUser(provider, inspection, asset);
    final assetType = inspection.assetType?.isNotEmpty == true
        ? inspection.assetType!
        : (asset?.assets_types.isNotEmpty == true ? asset!.assets_types : '');
    final location = _resolveLocation(asset);
    final manager = asset?.metadata['member_name'] ?? '';
    final hasPhoto = _hasBarcodePhoto(inspection, asset);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.qr_code, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inspection.assetUid,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.formatDateTime(inspection.scannedAt),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                inspection.isVerified
                    ? const Text(
                        '완료',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('인증 기능이 준비 중입니다.'),
                            ),
                          );
                        },
                        child: const Text('인증하기'),
                      ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: '사용자', value: user?.name ?? '정보 없음'),
            _InfoRow(
              label: '장비',
              value: assetType.isNotEmpty ? assetType : '정보 없음',
            ),
            _InfoRow(label: '자산번호', value: inspection.assetUid),
            _InfoRow(
              label: '관리자',
              value: manager.isNotEmpty ? manager : '정보 없음',
            ),
            _InfoRow(
              label: '위치',
              value: location.isNotEmpty ? location : '정보 없음',
            ),
            _InfoRow(
              label: '바코드사진',
              value: hasPhoto ? '사진 있음' : '없음',
            ),
          ],
        ),
      ),
    );
  }

  UserInfo? _resolveUser(
    InspectionProvider provider,
    Inspection inspection,
    AssetInfo? asset,
  ) {
    final candidates = <String?>[
      inspection.userId,
      asset?.metadata['user_id'],
      asset?.metadata['employee_id'],
    ];
    for (final id in candidates) {
      if (id == null) continue;
      final user = provider.userOf(id);
      if (user != null) {
        return user;
      }
    }
    return null;
  }

  String _resolveLocation(AssetInfo? asset) {
    if (asset == null) return '';
    final parts = <String?>[
      asset.metadata['building1'],
      asset.metadata['building'],
      asset.metadata['floor'],
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    return asset.location;
  }

  bool _hasBarcodePhoto(Inspection inspection, AssetInfo? asset) {
    final candidates = <String?>[
      inspection.barcodePhotoUrl,
      asset?.metadata['barcode_photo'],
      asset?.metadata['barcode_photo_url'],
      asset?.metadata['barcodePhoto'],
      asset?.metadata['barcodePhotoUrl'],
    ];
    return candidates.any((value) => value != null && value.trim().isNotEmpty);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
