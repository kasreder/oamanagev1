// lib/view/asset_verification/details_group_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/inspection.dart';
import '../../providers/inspection_provider.dart';
import '../common/app_scaffold.dart';
import 'signature_utils.dart';
import 'verification_utils.dart';
import 'widgets/signature_thumbnail.dart';
import 'widgets/verification_action_section.dart';

class AssetVerificationDetailsGroupPage extends StatefulWidget {
  const AssetVerificationDetailsGroupPage({super.key, required this.assetUids});

  final List<String> assetUids;

  @override
  State<AssetVerificationDetailsGroupPage> createState() => _AssetVerificationDetailsGroupPageState();
}

class _AssetVerificationDetailsGroupPageState extends State<AssetVerificationDetailsGroupPage> {
  bool _isActionsExpanded = true;

  void _handleSignaturesSaved() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final uniqueAssetUids = {
      for (final uid in widget.assetUids)
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

                final missingAssets = entries.where((entry) => entry.inspection == null && entry.asset == null).map((entry) => entry.assetUid).toList(growable: false);
                final validEntries = entries.where((entry) => entry.inspection != null || entry.asset != null).toList(growable: false);
                final verificationTargets = validEntries.map((entry) => entry.assetUid).toList(growable: false);
                final primaryEntry = validEntries.isNotEmpty ? validEntries.first : null;
                final primaryUser = primaryEntry == null ? null : resolveUser(provider, primaryEntry.inspection, primaryEntry.asset);

                return FutureBuilder<Map<String, String>>(
                  future: BarcodePhotoRegistry.loadAllPaths(),
                  builder: (context, snapshot) {
                    final barcodePhotoPaths = snapshot.data ?? const <String, String>{};
                    final isLoadingPhotos = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;

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
                                  if (missingAssets.isNotEmpty)
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(5),
                                        child: Text(
                                          '다음 자산의 정보를 찾을 수 없습니다: ${missingAssets.join(', ')}',
                                          style: const TextStyle(color: Colors.redAccent),
                                        ),
                                      ),
                                    ),
                                  if (validEntries.isNotEmpty)
                                    _GroupAssetCard(
                                      entries: validEntries,
                                      photoPaths: barcodePhotoPaths,
                                      isLoadingPhoto: isLoadingPhotos,
                                    )
                                  else
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(5),
                                        child: Text(
                                          '표시할 자산 상세 정보가 없습니다.',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (validEntries.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '인증 작업',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _isActionsExpanded = !_isActionsExpanded;
                                            });
                                          },
                                          icon: Icon(
                                            _isActionsExpanded ? Icons.expand_less : Icons.expand_more,
                                          ),
                                        ),
                                      ],
                                    ),
                                    AnimatedCrossFade(
                                      crossFadeState: _isActionsExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                      duration: const Duration(milliseconds: 200),
                                      firstChild: const SizedBox.shrink(),
                                      secondChild: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 5),
                                        child: VerificationActionSection(
                                          assetUids: verificationTargets,
                                          primaryAssetUid: primaryEntry?.assetUid,
                                          primaryUser: primaryUser,
                                          onSignaturesSaved: _handleSignaturesSaved,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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

class _GroupAssetCard extends StatefulWidget {
  const _GroupAssetCard({
    super.key,
    required this.entries,
    required this.photoPaths,
    required this.isLoadingPhoto,
  });

  final List<_GroupAssetEntry> entries;
  final Map<String, String> photoPaths;
  final bool isLoadingPhoto;

  @override
  State<_GroupAssetCard> createState() => _GroupAssetCardState();
}

class _GroupAssetCardState extends State<_GroupAssetCard> {
  bool _isSignatureExpanded = true;
  bool _isBarcodeExpanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InspectionProvider>(context, listen: false);
    final rows = widget.entries.map((entry) {
      final inspection = entry.inspection;
      final asset = entry.asset;
      final teamName = resolveTeamName(inspection, asset);
      final assetType = resolveAssetType(inspection, asset);
      final manager = resolveManager(asset);
      final location = resolveLocation(asset);
      final user = resolveUser(provider, inspection, asset);
      final userNameLabel = resolveUserNameLabel(user, asset);
      final normalizedAssetUid = entry.assetUid.trim().toLowerCase();
      final photoPath = widget.photoPaths[normalizedAssetUid];

      return _GroupAssetRowData(
        assetUid: entry.assetUid,
        teamName: teamName,
        userName: userNameLabel,
        user: user,
        assetType: assetType,
        manager: manager,
        location: location,
        photoPath: photoPath,
      );
    }).toList(growable: false);

    return FutureBuilder<Map<String, SignatureData>>(
      future: _loadSignatureMap(rows),
      builder: (context, snapshot) {
        final signatureMap = snapshot.data ?? const <String, SignatureData>{};
        final isLoadingSignatures = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;

        final previewEntries = rows
            .map(
              (row) => MapEntry(
                row,
                signatureMap[signatureCacheKey(row.assetUid, row.user)],
              ),
            )
            .where((entry) => entry.value != null)
            .toList(growable: false);
        final barcodeEntries = rows.where((row) => row.photoPath != null).map((row) => MapEntry(row.assetUid, row.photoPath!)).toList(growable: false);

        final Widget signatureSummary = () {
          if (isLoadingSignatures) {
            return const Text('서명 정보를 불러오는 중입니다...');
          }
          if (previewEntries.isEmpty) {
            return const Text(
              '등록된 서명이 없습니다.',
              style: TextStyle(color: Colors.grey),
            );
          }
          return Text('등록된 서명 ${previewEntries.length}건');
        }();

        final Widget barcodeSummary = () {
          if (widget.isLoadingPhoto) {
            return const Text('바코드 사진을 불러오는 중입니다...');
          }
          if (barcodeEntries.isEmpty) {
            return const Text(
              '등록된 바코드 사진이 없습니다.',
              style: TextStyle(color: Colors.grey),
            );
          }
          return Text('등록된 바코드 사진 ${barcodeEntries.length}건');
        }();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    columns: [
                      const DataColumn(label: Text('자산번호')),
                      const DataColumn(label: Text('팀')),
                      const DataColumn(label: Text('사용자')),
                      const DataColumn(label: Text('장비')),
                      const DataColumn(label: Text('관리자')),
                      const DataColumn(label: Text('위치')),
                      const DataColumn(label: Text('인증상태')),
                      const DataColumn(label: Text('바코드사진')),
                    ],
                    rows: [
                      for (final row in rows)
                        DataRow(
                          cells: [
                            DataCell(_wrapCell(SelectableText(row.assetUid))),
                            DataCell(
                              _wrapCell(
                                Text(row.teamName.isNotEmpty ? row.teamName : '정보 없음'),
                              ),
                            ),
                            DataCell(
                              _wrapCell(
                                Text(row.userName.isNotEmpty ? row.userName : '정보 없음'),
                              ),
                            ),
                            DataCell(
                              _wrapCell(
                                Text(row.assetType.isNotEmpty ? row.assetType : '정보 없음'),
                              ),
                            ),
                            DataCell(
                              _wrapCell(
                                Text(row.manager.isNotEmpty ? row.manager : '정보 없음'),
                              ),
                            ),
                            DataCell(
                              _wrapCell(
                                Text(row.location.isNotEmpty ? row.location : '정보 없음'),
                              ),
                            ),
                            DataCell(
                              _wrapCell(
                                isLoadingSignatures
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : _buildVerificationChip(
                                        context,
                                        signatureMap[signatureCacheKey(
                                          row.assetUid,
                                          row.user,
                                        )],
                                      ),
                              ),
                            ),
                            DataCell(
                              _wrapCell(
                                _buildPhotoCell(row.photoPath),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Card(
              // margin: const EdgeInsets.only(bottom: 5),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
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
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: signatureSummary,
                        ),
                      ),
                      secondChild: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Builder(
                          builder: (context) {
                            if (isLoadingSignatures) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (previewEntries.isEmpty) {
                              return const Text(
                                '등록된 서명이 없습니다.',
                                style: TextStyle(color: Colors.grey),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final entry in previewEntries) ...[
                                  Text(
                                    '${entry.key.assetUid} (${entry.key.userName.isNotEmpty ? entry.key.userName : '정보 없음'})',
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      entry.value!.bytes,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText('저장 위치: ${entry.value!.location}'),
                                  const SizedBox(height: 16),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '추가 바코드 사진',
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
                      crossFadeState: _isBarcodeExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                      firstChild: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: barcodeSummary,
                        ),
                      ),
                      secondChild: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Builder(
                          builder: (context) {
                            if (widget.isLoadingPhoto) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (barcodeEntries.isEmpty) {
                              return const Text(
                                '등록된 바코드 사진이 없습니다.',
                                style: TextStyle(color: Colors.grey),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final entry in barcodeEntries) ...[
                                  Text(entry.key),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      entry.value,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _wrapCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: child,
    );
  }

  Widget _buildPhotoCell(String? photoPath) {
    if (widget.isLoadingPhoto) {
      return const Text('불러오는 중...');
    }
    if (photoPath == null) {
      const color = Colors.orange;
      return Chip(
        backgroundColor: color.withOpacity(0.15),
        label: _buildChipText(context, '사진없음', color),
      );
    }
    return SizedBox(
      width: 40,
      height: 20,
      child: Image.asset(
        photoPath,
        fit: BoxFit.cover,
      ),
    );
  }

  Future<Map<String, SignatureData>> _loadSignatureMap(
    List<_GroupAssetRowData> rows,
  ) async {
    final futures = rows.map((row) async {
      final signature = await loadSignatureData(
        assetUid: row.assetUid,
        user: row.user,
      );
      if (signature == null) {
        return null;
      }
      return MapEntry(signatureCacheKey(row.assetUid, row.user), signature);
    }).toList(growable: false);

    final results = await Future.wait(futures);
    return Map.fromEntries(results.whereType<MapEntry<String, SignatureData>>());
  }

  Widget _buildVerificationChip(
    BuildContext context,
    SignatureData? signature,
  ) {
    if (signature != null) {
      return SignatureThumbnail(bytes: signature.bytes);
    }

    const color = Colors.orange;
    return Chip(
      backgroundColor: color.withOpacity(0.15),
      label: _buildChipText(context, '미인증', color),
    );
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
}

class _GroupAssetRowData {
  const _GroupAssetRowData({
    required this.assetUid,
    required this.teamName,
    required this.userName,
    required this.user,
    required this.assetType,
    required this.manager,
    required this.location,
    required this.photoPath,
  });

  final String assetUid;
  final String teamName;
  final String userName;
  final UserInfo? user;
  final String assetType;
  final String manager;
  final String location;
  final String? photoPath;
}
