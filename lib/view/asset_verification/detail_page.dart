// lib/view/asset_verification/detail_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/inspection_provider.dart';
import '../common/app_scaffold.dart';
import 'verification_utils.dart';
import 'widgets/verification_action_section.dart';

class AssetVerificationDetailPage extends StatefulWidget {
  const AssetVerificationDetailPage({super.key, required this.assetUid});

  final String assetUid;

  @override
  State<AssetVerificationDetailPage> createState() => _AssetVerificationDetailPageState();
}

class _AssetVerificationDetailPageState extends State<AssetVerificationDetailPage> {
  bool _isBarcodeExpanded = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '자산 검증 상세',
      selectedIndex: 2,
      body: Consumer<InspectionProvider>(
        builder: (context, provider, _) {
          final inspection = provider.latestByAssetUid(widget.assetUid);
          final asset = provider.assetOf(widget.assetUid);

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
          final resolvedAssetCode = inspection?.assetUid ?? widget.assetUid;
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
            future: BarcodePhotoRegistry.pathFor(widget.assetUid),
            builder: (context, snapshot) {
              final photoPath = snapshot.data;
              final isLoadingPhoto = snapshot.connectionState == ConnectionState.waiting;

              final photoStatus = () {
                if (isLoadingPhoto) {
                  return '불러오는 중...';
                }
                return photoPath != null ? '사진 있음' : '사진 없음';
              }();

              final detailCells = <_DetailCell>[
                _DetailCell('팀', SelectableText(_displayValue(teamName))),
                _DetailCell('사용자', SelectableText(_displayValue(user?.name ?? '정보 없음'))),
                _DetailCell('장비', SelectableText(_displayValue(assetType))),
                _DetailCell('자산번호', SelectableText(resolvedAssetCode)),
                _DetailCell('관리자', SelectableText(_displayValue(manager))),
                _DetailCell('위치', SelectableText(_displayValue(location))),
                _DetailCell(
                  '인증여부',
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
                ),
                _DetailCell('바코드사진', SelectableText(photoStatus)),
              ];

              return Padding(
                padding: const EdgeInsets.all(5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '자산 정보',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 5),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingTextStyle: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(fontWeight: FontWeight.w700),
                                        columns: [
                                          for (final cell in detailCells)
                                            DataColumn(label: Text(cell.label)),
                                        ],
                                        rows: [
                                          DataRow(
                                            cells: [
                                              for (final cell in detailCells)
                                                DataCell(Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                  child: cell.value,
                                                )),
                                            ],
                                          ),
                                        ],
                                      ),
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
                            const SizedBox(height: 2),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '바코드 사진',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _isBarcodeExpanded = !_isBarcodeExpanded;
                                            });
                                          },
                                          icon: Icon(
                                            _isBarcodeExpanded ? Icons.expand_less : Icons.expand_more,
                                          ),
                                        ),
                                      ],
                                    ),
                                    AnimatedCrossFade(
                                      crossFadeState: _isBarcodeExpanded
                                          ? CrossFadeState.showSecond
                                          : CrossFadeState.showFirst,
                                      duration: const Duration(milliseconds: 200),
                                      firstChild: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 12),
                                          child: Text(photoStatus),
                                        ),
                                      ),
                                      secondChild: Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: Builder(
                                          builder: (context) {
                                            if (isLoadingPhoto) {
                                              return const Center(child: CircularProgressIndicator());
                                            }
                                            if (photoPath != null) {
                                              return ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.asset(
                                                  photoPath,
                                                  fit: BoxFit.contain,
                                                ),
                                              );
                                            }
                                            return const Text('등록된 바코드 사진이 없습니다.');
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
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

class _DetailCell {
  const _DetailCell(this.label, this.value);

  final String label;
  final Widget value;
}
