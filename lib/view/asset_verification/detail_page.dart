// lib/view/asset_verification/detail_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/inspection_provider.dart';
import '../common/app_scaffold.dart';
import 'signature_utils.dart';
import 'verification_utils.dart';
import 'widgets/signature_thumbnail.dart';
import 'widgets/verification_action_section.dart';

class AssetVerificationDetailPage extends StatefulWidget {
  const AssetVerificationDetailPage({super.key, required this.assetUid});

  final String assetUid;

  @override
  State<AssetVerificationDetailPage> createState() => _AssetVerificationDetailPageState();
}

class _AssetVerificationDetailPageState extends State<AssetVerificationDetailPage> {
  bool _isBarcodeExpanded = false;
  bool _isSignatureExpanded = false;

  void _handleSignaturesSaved() {
    if (!mounted) return;
    setState(() {});
  }

  Widget _buildChipText(BuildContext context, String text, Color color) {
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ) ??
        TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        );
    return Text(text, style: textStyle);
  }

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

          final teamName = resolveTeamName(inspection, asset);
          final user = resolveUser(provider, inspection, asset);
          final assetType = resolveAssetType(inspection, asset);
          final manager = resolveManager(asset);
          final location = resolveLocation(asset);
          final resolvedAssetCode = inspection?.assetUid ?? widget.assetUid;
          return FutureBuilder<_DetailExtras>(
            future: _loadDetailExtras(resolvedAssetCode, user),
            builder: (context, snapshot) {
              final extras = snapshot.data;
              final isLoadingExtras =
                  snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
              final photoPath = extras?.photoPath;
              final signature = extras?.signature;

              final photoStatus = () {
                if (isLoadingExtras) {
                  return '불러오는 중...';
                }
                return photoPath != null ? '사진 있음' : '사진 없음';
              }();

              final bool isVerified = !isLoadingExtras && signature != null;
              late final Color verificationColor;
              late final Widget verificationLabel;
              if (isLoadingExtras) {
                verificationColor = Colors.blueGrey;
                verificationLabel = _buildChipText(context, '확인 중', verificationColor);
              } else if (isVerified) {
                verificationColor = Colors.green;
                verificationLabel = SignatureThumbnail(bytes: signature!.bytes);
              } else {
                verificationColor = Colors.orange;
                verificationLabel = _buildChipText(context, '미인증', verificationColor);
              }
              final Widget signatureStatus = () {
                if (isLoadingExtras) {
                  return const SelectableText('불러오는 중...');
                }
                if (signature != null) {
                  return SignatureThumbnail(bytes: signature.bytes);
                }
                return const SelectableText('서명 없음');
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
                    label: verificationLabel,
                  ),
                ),
                _DetailCell('바코드사진', SelectableText(photoStatus)),
                _DetailCell('인증서명', signatureStatus),
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
                                            if (isLoadingExtras) {
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
                                          '인증 서명',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _isSignatureExpanded = !_isSignatureExpanded;
                                            });
                                          },
                                          icon: Icon(
                                            _isSignatureExpanded ? Icons.expand_less : Icons.expand_more,
                                          ),
                                        ),
                                      ],
                                    ),
                                    AnimatedCrossFade(
                                      crossFadeState: _isSignatureExpanded
                                          ? CrossFadeState.showSecond
                                          : CrossFadeState.showFirst,
                                      duration: const Duration(milliseconds: 200),
                                      firstChild: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 12),
                                          child: signatureStatus,
                                        ),
                                      ),
                                      secondChild: Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: Builder(
                                          builder: (context) {
                                            if (isLoadingExtras) {
                                              return const Center(child: CircularProgressIndicator());
                                            }
                                            if (signature != null) {
                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Image.memory(
                                                      signature.bytes,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  SelectableText('저장 위치: ${signature.location}'),
                                                ],
                                              );
                                            }
                                            return const Text('등록된 서명이 없습니다.');
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
                      onSignaturesSaved: _handleSignaturesSaved,
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

  Future<_DetailExtras> _loadDetailExtras(String assetUid, UserInfo? user) async {
    final photoPath = await BarcodePhotoRegistry.pathFor(assetUid);
    final signature = await loadSignatureData(assetUid: assetUid, user: user);
    return _DetailExtras(photoPath: photoPath, signature: signature);
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

class _DetailExtras {
  const _DetailExtras({
    required this.photoPath,
    required this.signature,
  });

  final String? photoPath;
  final SignatureData? signature;
}
