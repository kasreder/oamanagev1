// lib/view/asset_verification/details_group_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/inspection.dart';
import '../../providers/inspection_provider.dart';
import '../common/app_scaffold.dart';
import 'verification_utils.dart';
import 'widgets/verification_action_section.dart';

class AssetVerificationDetailsGroupPage extends StatelessWidget {
  const AssetVerificationDetailsGroupPage({super.key, required this.assetUids});

  final List<String> assetUids;

  @override
  Widget build(BuildContext context) {
    final uniqueAssetUids = {
      for (final uid in assetUids)
        if (uid.trim().isNotEmpty) uid.trim()
    }.toList();

    return AppScaffold(
      title: '선택 자산 인증',
      selectedIndex: 2,
      body: uniqueAssetUids.isEmpty
          ? const Center(child: Text('선택된 자산이 없습니다.'))
          : Consumer<InspectionProvider>(
              builder: (context, provider, _) {
                final entries = uniqueAssetUids
                    .map(
                      (uid) => _GroupAssetEntry(
                        assetUid: uid,
                        inspection: provider.latestByAssetUid(uid),
                        asset: provider.assetOf(uid),
                      ),
                    )
                    .toList(growable: false);

                final missingAssets = entries
                    .where((entry) => entry.inspection == null && entry.asset == null)
                    .map((entry) => entry.assetUid)
                    .toList(growable: false);
                final validEntries = entries
                    .where((entry) => entry.inspection != null || entry.asset != null)
                    .toList(growable: false);
                final verificationTargets =
                    validEntries.map((entry) => entry.assetUid).toList(growable: false);
                final primaryEntry = validEntries.isNotEmpty ? validEntries.first : null;
                final primaryUser = primaryEntry == null
                    ? null
                    : resolveUser(provider, primaryEntry.inspection, primaryEntry.asset);

                return FutureBuilder<Set<String>>(
                  future: BarcodePhotoRegistry.loadCodes(),
                  builder: (context, snapshot) {
                    final barcodeAssetCodes = snapshot.data ?? const <String>{};
                    final isLoadingPhotos =
                        snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (missingAssets.isNotEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  '다음 자산의 정보를 찾을 수 없습니다: ${missingAssets.join(', ')}',
                                  style: const TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ),
                          if (validEntries.isNotEmpty) ...[ 
                            ...validEntries.map(
                              (entry) => _GroupAssetCard(
                                entry: entry,
                                hasPhoto: barcodeAssetCodes
                                    .contains(entry.assetUid.trim().toLowerCase()),
                                isLoadingPhoto: isLoadingPhotos,
                              ),
                            ),
                            const SizedBox(height: 16),
                            VerificationActionSection(
                              assetUids: verificationTargets,
                              primaryAssetUid: primaryEntry?.assetUid,
                              primaryUser: primaryUser,
                            ),
                          ] else
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  '표시할 자산 상세 정보가 없습니다.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _GroupAssetEntry {
  const _GroupAssetEntry({
    required this.assetUid,
    required this.inspection,
    required this.asset,
  });

  final String assetUid;
  final Inspection? inspection;
  final AssetInfo? asset;
}

class _GroupAssetCard extends StatelessWidget {
  const _GroupAssetCard({
    required this.entry,
    required this.hasPhoto,
    required this.isLoadingPhoto,
  });

  final _GroupAssetEntry entry;
  final bool hasPhoto;
  final bool isLoadingPhoto;

  @override
  Widget build(BuildContext context) {
    final inspection = entry.inspection;
    final asset = entry.asset;

    final teamName = normalizeTeamName(
      inspection?.userTeam ?? asset?.metadata['organization_team'],
    );
    final assetType = resolveAssetType(inspection, asset);
    final manager = resolveManager(asset);
    final location = resolveLocation(asset);
    final verificationState = inspection?.isVerified;
    final verificationLabel = switch (verificationState) {
      true => '인증 완료',
      false => '미인증',
      null => '실사 내역 없음',
    };
    final verificationColor = switch (verificationState) {
      true => Colors.green,
      false => Colors.orange,
      null => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.assetUid,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Chip(
                  backgroundColor: verificationColor.withOpacity(0.15),
                  label: Text(
                    verificationLabel,
                    style: TextStyle(
                      color: verificationColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: '팀', value: teamName),
            _InfoRow(label: '사용자', value: _resolveUserName(context, inspection, asset)),
            _InfoRow(label: '장비', value: assetType.isNotEmpty ? assetType : '정보 없음'),
            _InfoRow(label: '관리자', value: manager.isNotEmpty ? manager : '정보 없음'),
            _InfoRow(label: '위치', value: location.isNotEmpty ? location : '정보 없음'),
            _InfoRow(
              label: '바코드사진',
              value: isLoadingPhoto
                  ? '불러오는 중...'
                  : hasPhoto
                      ? '사진 있음'
                      : '사진 없음',
            ),
          ],
        ),
      ),
    );
  }

  String _resolveUserName(
    BuildContext context,
    Inspection? inspection,
    AssetInfo? asset,
  ) {
    final provider = Provider.of<InspectionProvider>(context, listen: false);
    final user = resolveUser(provider, inspection, asset);
    return user?.name ?? '정보 없음';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: style?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
