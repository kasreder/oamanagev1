import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../main.dart';
import '../models/asset.dart';
import '../models/drawing.dart';
import '../notifiers/auth_notifier.dart';
import '../services/api_service.dart';
import '../utils/category_icons.dart';
import '../widgets/asset_cell_card.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';

/// 5.1.7a 도면 뷰어 (대형 격자 지원)
class DrawingViewerPage extends ConsumerStatefulWidget {
  final int drawingId;
  const DrawingViewerPage({super.key, required this.drawingId});

  @override
  ConsumerState<DrawingViewerPage> createState() => _DrawingViewerPageState();
}

class _DrawingViewerPageState extends ConsumerState<DrawingViewerPage> {
  final ApiService _api = ApiService();
  final TransformationController _transformCtrl = TransformationController();

  Drawing? _drawing;
  List<Asset> _assets = [];
  bool _isLoading = true;
  String? _error;
  bool _showGrid = true;
  bool _editMode = false;
  Asset? _pendingMoveAsset;

  static const double _minScale = 0.5;
  static const double _maxScale = 8.0;
  static const double _zoomStep = 0.5;

  @override
  void initState() {
    super.initState();
    _transformCtrl.addListener(_onTransformChanged);
    _loadData();
  }

  @override
  void dispose() {
    _transformCtrl.removeListener(_onTransformChanged);
    _transformCtrl.dispose();
    super.dispose();
  }

  void _onTransformChanged() => setState(() {});

  double get _currentScale => _transformCtrl.value.getMaxScaleOnAxis();

  void _applyZoom(double newScale) {
    final s = newScale.clamp(_minScale, _maxScale);
    _transformCtrl.value = Matrix4.identity()..scale(s, s);
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final drawing = await _api.fetchDrawing(widget.drawingId);
      final assets = await _api.fetchAssetsOnDrawing(widget.drawingId);
      setState(() {
        _drawing = drawing;
        _assets = assets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  String? get _imageUrl {
    if (_drawing?.drawingFile == null) return null;
    return supabase.storage
        .from('drawing-images')
        .getPublicUrl(_drawing!.drawingFile!);
  }

  Map<(int, int), List<Asset>> get _groupedAssets {
    final map = <(int, int), List<Asset>>{};
    for (final a in _assets) {
      if (a.locationRow == null || a.locationCol == null) continue;
      map.putIfAbsent((a.locationRow!, a.locationCol!), () => []).add(a);
    }
    return map;
  }

  bool get _isAdminUser =>
      ref.read(authNotifierProvider).valueOrNull?.user?.isAdminGroup ?? false;

  // ── 셀 클릭 핸들러 ──────────────────────────────────────────────────
  void _onCellTap(int row, int col, List<Asset> assetsInCell) {
    if (_editMode && _pendingMoveAsset != null) {
      _moveAssetTo(_pendingMoveAsset!, row, col);
      return;
    }
    if (assetsInCell.isEmpty) {
      if (_editMode) _showAssignDialog(row, col);
      return;
    }
    _showCellSheet(assetsInCell, row, col);
  }

  void _showCellSheet(List<Asset> assets, int row, int col) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.chair_alt,
                    color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  '${Drawing.getGridLabel(row, col)}  ·  ${assets.length}대',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: assets.length,
                itemBuilder: (_, i) {
                  final a = assets[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(iconForCategory(a.category),
                        color: theme.colorScheme.primary),
                    title: Text(a.assetUid,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${a.name ?? "-"}'
                      '${(a.userName?.isNotEmpty ?? false) ? "  ·  ${a.userName}" : ""}',
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: _editMode
                        ? PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (v) {
                              Navigator.pop(ctx);
                              if (v == 'move') {
                                setState(() => _pendingMoveAsset = a);
                              } else if (v == 'unassign') {
                                _unassignAsset(a);
                              } else if (v == 'open') {
                                context.go('/asset/${a.id}');
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'move', child: Text('이동')),
                              PopupMenuItem(
                                  value: 'unassign', child: Text('해제')),
                              PopupMenuItem(
                                  value: 'open', child: Text('자산 상세')),
                            ],
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _editMode
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            context.go('/asset/${a.id}');
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAssignDialog(int row, int col) async {
    final picked = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => _AssignAssetsDialog(
        cellLabel: Drawing.getGridLabel(row, col),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    try {
      for (final id in picked) {
        await _api.updateAsset(id, {
          'location_drawing_id': widget.drawingId,
          'location_row': row,
          'location_col': col,
        });
      }
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${picked.length}건을 ${Drawing.getGridLabel(row, col)} 에 배치')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('할당 실패: $e')),
        );
      }
    }
  }

  Future<void> _moveAssetTo(Asset asset, int row, int col) async {
    try {
      await _api.updateAsset(asset.id, {
        'location_drawing_id': widget.drawingId,
        'location_row': row,
        'location_col': col,
      });
      setState(() => _pendingMoveAsset = null);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${asset.assetUid} → ${Drawing.getGridLabel(row, col)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('이동 실패: $e')),
        );
      }
    }
  }

  Future<void> _unassignAsset(Asset asset) async {
    try {
      await _api.updateAsset(asset.id, {
        'location_drawing_id': null,
        'location_row': null,
        'location_col': null,
      });
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${asset.assetUid} 위치 해제됨')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('해제 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _drawing != null
        ? '${_drawing!.building} ${_drawing!.floor}'
        : '도면 뷰어';
    return AppScaffold(title: title, body: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) return const LoadingWidget(message: '도면을 불러오는 중...');
    if (_error != null) {
      return AppErrorWidget(message: _error!, onRetry: _loadData);
    }
    if (_drawing == null) {
      return const AppErrorWidget(message: '도면 정보를 찾을 수 없습니다.');
    }

    final theme = Theme.of(context);
    final canEdit = _isAdminUser;
    final rows = _drawing!.gridRows;
    final cols = _drawing!.gridCols;

    return Column(
      children: [
        // ── 도구 모음 ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Text(
                '자산 ${_assets.length}건  ·  가로 $rows × 세로 $cols',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(width: 12),
              if (canEdit)
                FilterChip(
                  label: const Text('편집'),
                  avatar: const Icon(Icons.edit, size: 14),
                  selected: _editMode,
                  onSelected: (v) => setState(() {
                    _editMode = v;
                    _pendingMoveAsset = null;
                  }),
                ),
              const Spacer(),
              IconButton(
                icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off,
                    size: 20),
                onPressed: () => setState(() => _showGrid = !_showGrid),
                tooltip: '격자 표시',
              ),
              IconButton(
                icon: const Icon(Icons.fit_screen, size: 20),
                onPressed: () => _applyZoom(1.0),
                tooltip: '화면 맞춤',
              ),
            ],
          ),
        ),

        // ── 이동 대기 안내 배너 ──
        if (_pendingMoveAsset != null)
          Container(
            color: Colors.amber.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.open_with, size: 16, color: Colors.brown),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_pendingMoveAsset!.assetUid} 이동 중 — 빈 셀 또는 다른 셀을 클릭하세요',
                    style: const TextStyle(fontSize: 12, color: Colors.brown),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _pendingMoveAsset = null),
                  child: const Text('취소'),
                ),
              ],
            ),
          ),

        // ── 도면 뷰어 ──
        Expanded(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  // 정사각형 셀 — 좌상단 정렬
                  // 행 = 가로(X축, rows개), 열 = 세로(Y축, cols개)
                  final cellSize = math.min(
                    constraints.maxWidth / rows,
                    constraints.maxHeight / cols,
                  );
                  final gridW = cellSize * rows;
                  final gridH = cellSize * cols;

                  return InteractiveViewer(
                    transformationController: _transformCtrl,
                    minScale: _minScale,
                    maxScale: _maxScale,
                    boundaryMargin: const EdgeInsets.all(100),
                    constrained: false,
                    child: SizedBox(
                      width: gridW,
                      height: gridH,
                      child: Stack(
                        children: [
                          // 도면 이미지
                          if (_imageUrl != null)
                            Positioned.fill(
                              child: CachedNetworkImage(
                                imageUrl: _imageUrl!,
                                fit: BoxFit.fill,
                                placeholder: (_, __) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (_, __, ___) => Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.broken_image,
                                          size: 48,
                                          color:
                                              theme.colorScheme.outline),
                                      const SizedBox(height: 8),
                                      Text('이미지를 불러올 수 없습니다.',
                                          style: theme.textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            Positioned.fill(
                              child: Container(
                                color: theme.colorScheme
                                    .surfaceContainerHighest,
                                child: const Center(
                                  child: Text('도면 이미지가 등록되지 않았습니다.'),
                                ),
                              ),
                            ),

                          // 격자 painter — viewport culling + step LOD
                          if (_showGrid)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _GridPainter(
                                    rows: rows,
                                    cols: cols,
                                    cellSize: cellSize,
                                    scale: _currentScale,
                                    lineColor: theme.colorScheme.outline
                                        .withValues(alpha: 0.45),
                                    fillColor: theme.colorScheme.primary
                                        .withValues(alpha: 0.05),
                                  ),
                                ),
                              ),
                            ),

                          // 자산 있는 셀 — LOD 분기
                          ..._buildAssetMarkers(cellSize, theme),

                          // 빈 셀 hit-test — 편집 모드에서만, 단일 GestureDetector
                          if (_editMode)
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTapDown: (d) {
                                  final r = (d.localPosition.dx / cellSize)
                                      .floor()
                                      .clamp(0, rows - 1);
                                  final c = (d.localPosition.dy / cellSize)
                                      .floor()
                                      .clamp(0, cols - 1);
                                  _onCellTap(
                                      r, c, _groupedAssets[(r, c)] ?? const []);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // ── 우하단 0.5 단위 줌 컨트롤 ──
              Positioned(
                right: 12,
                bottom: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentScale.toStringAsFixed(1)}×',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'zoom_in',
                      tooltip: '확대 (+0.5)',
                      onPressed: () => _applyZoom(_currentScale + _zoomStep),
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'zoom_reset',
                      tooltip: '1× 리셋',
                      onPressed: () => _applyZoom(1.0),
                      child: const Icon(Icons.center_focus_strong),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'zoom_out',
                      tooltip: '축소 (-0.5)',
                      onPressed: () => _applyZoom(_currentScale - _zoomStep),
                      child: const Icon(Icons.remove),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 자산 있는 셀 — LOD 적용. 시각 cellSize(=cellSize*scale)에 따라 위젯 종류 다름.
  List<Widget> _buildAssetMarkers(double cellSize, ThemeData theme) {
    final visualCell = cellSize * _currentScale;
    final groups = _groupedAssets;
    final widgets = <Widget>[];

    // 행 r → X축, 열 c → Y축
    if (visualCell < 4) {
      // 점만 표시
      for (final entry in groups.entries) {
        final r = entry.key.$1;
        final c = entry.key.$2;
        widgets.add(Positioned(
          left: r * cellSize + cellSize / 2 - 1,
          top: c * cellSize + cellSize / 2 - 1,
          width: 2,
          height: 2,
          child: const ColoredBox(color: Color(0xFF1976D2)),
        ));
      }
    } else if (visualCell < 12) {
      // 색 사각형만
      for (final entry in groups.entries) {
        final r = entry.key.$1;
        final c = entry.key.$2;
        widgets.add(Positioned(
          left: r * cellSize,
          top: c * cellSize,
          width: cellSize,
          height: cellSize,
          child: GestureDetector(
            onTap: () => _onCellTap(r, c, entry.value),
            child: Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ));
      }
    } else {
      // 풀 카드
      for (final entry in groups.entries) {
        final r = entry.key.$1;
        final c = entry.key.$2;
        widgets.add(Positioned(
          left: r * cellSize,
          top: c * cellSize,
          width: cellSize,
          height: cellSize,
          child: AssetCellCard(
            assets: entry.value,
            cellSize: cellSize,
            scale: _currentScale,
            onTap: () => _onCellTap(r, c, entry.value),
          ),
        ));
      }
    }
    return widgets;
  }
}

/// 격자 페인터 — 시야 안 라인만 + step LOD.
/// 시각 cellSize(=cellSize*scale)가 작을수록 step이 커진다.
class _GridPainter extends CustomPainter {
  final int rows;
  final int cols;
  final double cellSize;
  final double scale;
  final Color lineColor;
  final Color fillColor;

  _GridPainter({
    required this.rows,
    required this.cols,
    required this.cellSize,
    required this.scale,
    required this.lineColor,
    required this.fillColor,
  });

  int _stepForScale() {
    final visualCell = cellSize * scale;
    if (visualCell >= 6) return 1;
    if (visualCell >= 1) return 10;
    return 100;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final step = _stepForScale();
    final thinPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    final thickPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.8)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    // 행 r → X축(가로 분할 rows개), 열 c → Y축(세로 분할 cols개)
    // 셀별 옅은 배경 (step ≥ 1이라 작은 줌에서는 부담 줄임)
    if (step <= 1 && cellSize * scale >= 12) {
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          canvas.drawRect(
              Rect.fromLTWH(r * cellSize, c * cellSize, cellSize, cellSize),
              fill);
        }
      }
    }

    // 세로선 — x = r * cellSize, r 인덱스를 따라
    for (int r = 0; r <= rows; r += step) {
      final x = r * cellSize;
      final p = (r % (step * 10) == 0) ? thickPaint : thinPaint;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    // 가로선 — y = c * cellSize, c 인덱스를 따라
    for (int c = 0; c <= cols; c += step) {
      final y = c * cellSize;
      final p = (c % (step * 10) == 0) ? thickPaint : thinPaint;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.rows != rows ||
      old.cols != cols ||
      old.cellSize != cellSize ||
      old.scale != scale ||
      old.lineColor != lineColor ||
      old.fillColor != fillColor;
}

// ── 자산 검색/다중선택 할당 다이얼로그 ───────────────────────────────────
class _AssignAssetsDialog extends StatefulWidget {
  final String cellLabel;
  const _AssignAssetsDialog({required this.cellLabel});

  @override
  State<_AssignAssetsDialog> createState() => _AssignAssetsDialogState();
}

class _AssignAssetsDialogState extends State<_AssignAssetsDialog> {
  final _searchCtrl = TextEditingController();
  final Set<int> _picked = {};
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    try {
      final esc = q
          .replaceAll(',', r'\,')
          .replaceAll('(', r'\(')
          .replaceAll(')', r'\)')
          .replaceAll('*', r'\*');
      final rows = await supabase
          .from('assets')
          .select(
              'id, asset_uid, name, user_name, category, location_drawing_id, location_row, location_col')
          .or('asset_uid.ilike.*$esc*,name.ilike.*$esc*,user_name.ilike.*$esc*')
          .order('asset_uid')
          .limit(50);
      if (!mounted) return;
      setState(() {
        _results = List<Map<String, dynamic>>.from(rows as List);
        _searched = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _searched = true;
        _results = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: SelectableText('검색 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('${widget.cellLabel} 칸에 자산 할당'),
      content: SizedBox(
        width: 440,
        height: 480,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '자산명 / 자산번호 / 사용자명 검색',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _search,
                  child: const Text('검색'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _searched ? '결과 없음' : '키워드 입력 후 검색',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (_, i) {
                            final a = _results[i];
                            final id = a['id'] as int;
                            final uid = a['asset_uid'] as String? ?? '';
                            final name = a['name'] as String? ?? '';
                            final user = a['user_name'] as String? ?? '';
                            final cat = a['category'] as String? ?? '';
                            final inDrawing =
                                a['location_drawing_id'] as int?;
                            final r = a['location_row'] as int?;
                            final c = a['location_col'] as int?;
                            final hasLoc = r != null && c != null;
                            final checked = _picked.contains(id);
                            return CheckboxListTile(
                              dense: true,
                              value: checked,
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _picked.add(id);
                                } else {
                                  _picked.remove(id);
                                }
                              }),
                              title: Text(
                                '$uid  ·  ${name.isEmpty ? "-" : name}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                [
                                  if (cat.isNotEmpty) cat,
                                  if (user.isNotEmpty) user,
                                  if (hasLoc)
                                    '현재: ${Drawing.getGridLabel(r, c)}'
                                        '${inDrawing != null ? " (도면 #$inDrawing)" : ""}',
                                ].join('  ·  '),
                                style: theme.textTheme.bodySmall,
                              ),
                            );
                          },
                        ),
            ),
            if (_picked.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${_picked.length}건 선택됨',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _picked.isEmpty
              ? null
              : () => Navigator.pop(context, _picked.toList()),
          child: Text('선택한 ${_picked.length}건 할당'),
        ),
      ],
    );
  }
}
