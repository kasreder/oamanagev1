import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../constants.dart';
import '../main.dart';
import '../models/asset.dart';
import '../models/drawing.dart';
import '../services/api_service.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';

/// 5.1.7a 도면 뷰어 화면 (/drawing/:id)
///
/// - InteractiveViewer + 도면 이미지 + DrawingGridOverlay + AssetMarkerWidgets
/// - 마커 탭 -> 자산 정보 표시
class DrawingViewerPage extends ConsumerStatefulWidget {
  final int drawingId;

  const DrawingViewerPage({
    super.key,
    required this.drawingId,
  });

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
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

  /// 도면 이미지 URL 취득
  String? get _imageUrl {
    if (_drawing?.drawingFile == null) return null;
    return supabase.storage
        .from('drawings')
        .getPublicUrl(_drawing!.drawingFile!);
  }

  /// 자산 마커 탭 -> 바텀 시트
  void _showAssetInfo(Asset asset) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Icon(Icons.devices,
                    color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    asset.name ?? asset.assetUid,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            _infoRow('자산번호', asset.assetUid),
            _infoRow('카테고리', asset.category),
            _infoRow('상태', asset.assetsStatus),
            _infoRow('사용자', asset.userName ?? '-'),
            _infoRow('부서', asset.userDepartment ?? '-'),
            if (asset.locationRow != null && asset.locationCol != null)
              _infoRow('위치',
                  Drawing.getGridLabel(asset.locationRow!, asset.locationCol!)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/asset/${asset.id}');
                },
                child: const Text('자산 상세 보기'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _drawing != null
        ? '${_drawing!.building} ${_drawing!.floor}'
        : '도면 뷰어';

    return AppScaffold(
      title: title,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const LoadingWidget(message: '도면을 불러오는 중...');
    }
    if (_error != null) {
      return AppErrorWidget(message: _error!, onRetry: _loadData);
    }
    if (_drawing == null) {
      return const AppErrorWidget(message: '도면 정보를 찾을 수 없습니다.');
    }

    final theme = Theme.of(context);

    return Column(
      children: [
        // ── 도구 모음 ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Row(
            children: [
              Text(
                '자산 ${_assets.length}건',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const Spacer(),
              // 격자 토글
              IconButton(
                icon: Icon(
                  _showGrid ? Icons.grid_on : Icons.grid_off,
                  size: 20,
                ),
                onPressed: () => setState(() => _showGrid = !_showGrid),
                tooltip: '격자 표시',
              ),
              // 확대/축소 리셋
              IconButton(
                icon: const Icon(Icons.fit_screen, size: 20),
                onPressed: () => _transformCtrl.value = Matrix4.identity(),
                tooltip: '화면 맞춤',
              ),
            ],
          ),
        ),

        // ── 도면 뷰어 ──
        Expanded(
          child: InteractiveViewer(
            transformationController: _transformCtrl,
            minScale: drawingMinScale,
            maxScale: drawingMaxScale,
            boundaryMargin: const EdgeInsets.all(100),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // 도면 이미지
                    if (_imageUrl != null)
                      CachedNetworkImage(
                        imageUrl: _imageUrl!,
                        fit: BoxFit.contain,
                        width: constraints.maxWidth,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (_, __, ___) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image,
                                  size: 48,
                                  color: theme.colorScheme.outline),
                              const SizedBox(height: 8),
                              Text('이미지를 불러올 수 없습니다.',
                                  style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: Text('도면 이미지가 등록되지 않았습니다.'),
                        ),
                      ),

                    // 격자 오버레이
                    if (_showGrid && _drawing != null)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _GridPainter(
                            rows: _drawing!.gridRows,
                            cols: _drawing!.gridCols,
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                      ),

                    // 자산 마커
                    ..._assets
                        .where((a) =>
                            a.locationRow != null && a.locationCol != null)
                        .map((asset) {
                      final cellW =
                          constraints.maxWidth / (_drawing?.gridCols ?? 8);
                      final cellH =
                          constraints.maxHeight / (_drawing?.gridRows ?? 10);
                      final left = asset.locationCol! * cellW + cellW / 2 - 14;
                      final top = asset.locationRow! * cellH + cellH / 2 - 14;

                      return Positioned(
                        left: left.clamp(0, constraints.maxWidth - 28),
                        top: top.clamp(0, constraints.maxHeight - 28),
                        child: GestureDetector(
                          onTap: () => _showAssetInfo(asset),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.devices,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// 격자 선 페인터
class _GridPainter extends CustomPainter {
  final int rows;
  final int cols;
  final Color color;

  _GridPainter({
    required this.rows,
    required this.cols,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final cellW = size.width / cols;
    final cellH = size.height / rows;

    // 세로선
    for (int c = 0; c <= cols; c++) {
      final x = c * cellW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // 가로선
    for (int r = 0; r <= rows; r++) {
      final y = r * cellH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.rows != rows ||
        oldDelegate.cols != cols ||
        oldDelegate.color != color;
  }
}
