// lib/view/asset_verification/detail_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/inspection_provider.dart';
import '../common/app_scaffold.dart';
import 'verification_utils.dart';
import 'widgets/verification_action_section.dart';

class AssetVerificationDetailPage extends StatelessWidget {
  const AssetVerificationDetailPage({super.key, required this.assetUid});

  final String assetUid;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '자산 검증 상세',
      selectedIndex: 2,
      body: Consumer<InspectionProvider>(
        builder: (context, provider, _) {
          final inspection = provider.latestByAssetUid(assetUid);
          final asset = provider.assetOf(assetUid);

          if (inspection == null && asset == null) {
            return const Center(
              child: Text('자산 정보를 찾을 수 없습니다.'),
            );
          }

          final teamName = normalizeTeamName(
            inspection?.userTeam ?? asset?.metadata['organization_team'],
          );
          final user = resolveUser(provider, inspection, asset);
          final assetType = resolveAssetType(inspection, asset);
          final manager = resolveManager(asset);
          final location = resolveLocation(asset);
          final resolvedAssetCode = inspection?.assetUid ?? assetUid;
          final isVerified = inspection?.isVerified;
          final verificationLabel = switch (isVerified) {
            true => '인증 완료',
            false => '미인증',
            null => '실사 내역 없음',
          };
          final verificationColor = switch (isVerified) {
            true => Colors.green,
            false => Colors.orange,
            null => Colors.grey,
          };

          return FutureBuilder<String?>(
            future: BarcodePhotoRegistry.pathFor(assetUid),
            builder: (context, snapshot) {
              final photoPath = snapshot.data;
              final isLoadingPhoto = snapshot.connectionState == ConnectionState.waiting;

              final photoStatus = () {
                if (isLoadingPhoto) {
                  return '불러오는 중...';
                }
                return photoPath != null ? '사진 있음' : '사진 없음';
              }();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '자산 정보',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            _DetailRow(
                              label: '팀',
                              child: SelectableText(_displayValue(teamName)),
                            ),
                            _DetailRow(
                              label: '사용자',
                              child: SelectableText(_displayValue(user?.name ?? '정보 없음')),
                            ),
                            _DetailRow(
                              label: '장비',
                              child: SelectableText(_displayValue(assetType)),
                            ),
                            _DetailRow(
                              label: '자산번호',
                              child: SelectableText(resolvedAssetCode),
                            ),
                            _DetailRow(
                              label: '관리자',
                              child: SelectableText(_displayValue(manager)),
                            ),
                            _DetailRow(
                              label: '위치',
                              child: SelectableText(_displayValue(location)),
                            ),
                            _DetailRow(
                              label: '인증여부',
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Chip(
                                  backgroundColor: verificationColor.withOpacity(0.15),
                                  label: Text(
                                    verificationLabel,
                                    style: TextStyle(
                                      color: verificationColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _DetailRow(
                              label: '바코드사진',
                              child: SelectableText(photoStatus),
                            ),
                            if (inspection == null)
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Text(
                                  '이 자산에 대한 최근 실사 내역이 없습니다.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '바코드 사진',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            if (isLoadingPhoto)
                              const Center(child: CircularProgressIndicator())
                            else if (photoPath != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  photoPath,
                                  fit: BoxFit.contain,
                                ),
                              )
                            else
                              const Text('등록된 바코드 사진이 없습니다.'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    VerificationActionSection(
                      assetUids: [resolvedAssetCode],
                      primaryAssetUid: resolvedAssetCode,
                      primaryUser: user,
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

  static String _displayValue(String value) {
    if (value.trim().isEmpty) {
      return '정보 없음';
    }
    return value;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: labelStyle),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
