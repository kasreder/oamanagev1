import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../constants.dart';
import '../models/drawing.dart';
import '../notifiers/drawing_notifier.dart';
import '../notifiers/dropdown_options_provider.dart';
import '../services/api_service.dart';
import '../main.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';
import '../widgets/common/empty_state_widget.dart';

/// 5.1.7 도면 관리 화면 (/drawings)
///
/// - 건물/층별 도면 리스트
/// - FAB -> 새 도면 등록 다이얼로그 (건물명, 층, 이미지 업로드)
/// - 행 클릭 -> /drawing/:id
class DrawingManagerPage extends ConsumerStatefulWidget {
  const DrawingManagerPage({super.key});

  @override
  ConsumerState<DrawingManagerPage> createState() =>
      _DrawingManagerPageState();
}

class _DrawingManagerPageState extends ConsumerState<DrawingManagerPage> {
  final ApiService _api = ApiService();

  List<Drawing> _drawings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDrawings();
  }

  Future<void> _loadDrawings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _drawings = await _api.fetchDrawings();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  /// 건물별로 그룹화
  Map<String, List<Drawing>> get _groupedDrawings {
    final map = <String, List<Drawing>>{};
    for (final d in _drawings) {
      map.putIfAbsent(d.building, () => []).add(d);
    }
    // 건물명 정렬
    final sorted = Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return sorted;
  }

  /// 새 도면 등록 다이얼로그
  Future<void> _showCreateDialog() async => _showFormDialog();

  /// 기존 도면 수정 다이얼로그
  Future<void> _showEditDialog(Drawing d) async => _showFormDialog(existing: d);

  /// 도면 삭제 — 자산이 등록돼 있으면 차단.
  Future<void> _confirmDelete(Drawing drawing) async {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // 등록된 자산 수 확인
    List<dynamic> registered;
    try {
      registered = await _api.fetchAssetsOnDrawing(drawing.id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: SelectableText('자산 조회 실패: $e')),
      );
      return;
    }

    if (!mounted) return;

    if (registered.isNotEmpty) {
      // 자산이 있으면 차단
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.block, color: theme.colorScheme.error),
          title: const Text('삭제할 수 없습니다'),
          content: Text(
            '${drawing.building} ${drawing.floor} 도면에 자산 ${registered.length}건이 등록되어 있어 삭제할 수 없습니다.\n\n'
            '도면 뷰어에서 자산 위치를 모두 해제한 후 다시 시도하세요.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    // 자산이 없으면 삭제 확인
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_forever, color: theme.colorScheme.error),
        title: const Text('도면 삭제'),
        content: Text(
          '${drawing.building} ${drawing.floor} 도면을 삭제하시겠습니까?\n\n'
          '도면 이미지 파일과 격자 설정도 함께 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(drawingNotifierProvider.notifier).deleteDrawing(drawing.id);
      await _loadDrawings();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${drawing.building} ${drawing.floor} 도면을 삭제했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: SelectableText('삭제 실패: $e')),
      );
    }
  }

  /// 등록/수정 공용 다이얼로그
  Future<void> _showFormDialog({Drawing? existing}) async {
    final isEdit = existing != null;
    String? selectedBuilding = existing?.building;
    String? selectedFloor = existing?.floor;
    final descCtrl =
        TextEditingController(text: existing?.description ?? '');
    final rowsCtrl =
        TextEditingController(text: '${existing?.gridRows ?? 500}');
    final colsCtrl =
        TextEditingController(text: '${existing?.gridCols ?? 500}');
    XFile? selectedImage;

    // DB 동적 옵션 (실패 시 const fallback)
    final buildings = ref
            .read(dropdownOptionsProvider(
                const DropdownKey('asset_detail', 'building1')))
            .valueOrNull ??
        building1Options;
    final floors = ref
            .read(dropdownOptionsProvider(
                const DropdownKey('asset_detail', 'floor')))
            .valueOrNull ??
        floorOptions;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? '도면 수정' : '새 도면 등록'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: buildings.contains(selectedBuilding)
                        ? selectedBuilding
                        : null,
                    decoration: const InputDecoration(
                      labelText: '건물 *',
                      border: OutlineInputBorder(),
                    ),
                    items: buildings
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedBuilding = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: floors.contains(selectedFloor) ? selectedFloor : null,
                    decoration: const InputDecoration(
                      labelText: '층 *',
                      border: OutlineInputBorder(),
                    ),
                    items: floors
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedFloor = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: rowsCtrl,
                          decoration: const InputDecoration(
                            labelText: '행 (가로, 1~700)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: colsCtrl,
                          decoration: const InputDecoration(
                            labelText: '열 (세로, 1~700)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: '설명',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  OutlinedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final image = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 2048,
                      );
                      if (image != null) {
                        setDialogState(() => selectedImage = image);
                      }
                    },
                    icon: const Icon(Icons.image),
                    label: Text(
                      selectedImage != null
                          ? '이미지 선택됨'
                          : (isEdit ? '도면 이미지 교체' : '도면 이미지 선택'),
                    ),
                  ),
                  if (selectedImage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        selectedImage!.name,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else if (isEdit && existing.drawingFile != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '기존: ${existing.drawingFile}',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () {
                  if ((selectedBuilding ?? '').isEmpty ||
                      (selectedFloor ?? '').isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('건물과 층을 선택하세요.')),
                    );
                    return;
                  }
                  final r = int.tryParse(rowsCtrl.text.trim());
                  final c = int.tryParse(colsCtrl.text.trim());
                  if (r == null || c == null || r < 1 || c < 1 || r > 700 || c > 700) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('행(가로)/열(세로)은 1~700 사이의 숫자여야 합니다.')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: Text(isEdit ? '저장' : '등록'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true) return;

    String? uploadedPath;
    try {
      String? drawingFile;
      if (selectedImage != null) {
        final bytes = await selectedImage!.readAsBytes();
        final ext = selectedImage!.name.split('.').last;
        final fileName =
            'drawings/${DateTime.now().millisecondsSinceEpoch}.$ext';
        await supabase.storage.from('drawing-images').uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );
        drawingFile = fileName;
        uploadedPath = fileName;
      }

      final payload = <String, dynamic>{
        'building': selectedBuilding!,
        'floor': selectedFloor!,
        'description': descCtrl.text.trim(),
        'grid_rows': int.parse(rowsCtrl.text.trim()),
        'grid_cols': int.parse(colsCtrl.text.trim()),
        if (drawingFile != null) 'drawing_file': drawingFile,
      };

      if (isEdit) {
        await _api.updateDrawing(existing.id, payload);
      } else {
        await _api.createDrawing(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? '도면이 수정되었습니다.' : '도면이 등록되었습니다.')),
        );
        _loadDrawings();
      }
    } catch (e) {
      if (uploadedPath != null) {
        try {
          await supabase.storage
              .from('drawing-images')
              .remove([uploadedPath]);
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('${isEdit ? "수정" : "등록"} 실패: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '도면 관리',
      currentIndex: 4,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const LoadingWidget(message: '도면 목록을 불러오는 중...');
    }
    if (_error != null) {
      return AppErrorWidget(message: _error!, onRetry: _loadDrawings);
    }
    if (_drawings.isEmpty) {
      return Stack(
        children: [
          const EmptyStateWidget(
            icon: Icons.map,
            message: '등록된 도면이 없습니다.',
            subMessage: '우측 하단 버튼으로 새 도면을 등록하세요.',
          ),
          _buildFab(),
        ],
      );
    }

    final grouped = _groupedDrawings;
    final theme = Theme.of(context);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadDrawings,
          child: ListView(
            padding:
                const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 80),
            children: grouped.entries.map((entry) {
              final building = entry.key;
              final floors = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 건물명 헤더
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.business,
                            size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          building,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${floors.length}개 층)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 층별 도면 카드
                  ...floors.map(
                    (drawing) => Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              theme.colorScheme.primaryContainer,
                          child: Icon(
                            Icons.layers,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        title: Text('${drawing.building} ${drawing.floor}'),
                        subtitle: Text(
                          '가로 ${drawing.gridRows} × 세로 ${drawing.gridCols} 격자'
                          '${(drawing.description?.isNotEmpty ?? false) ? "  ·  ${drawing.description}" : ""}',
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '도면 수정',
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _showEditDialog(drawing),
                            ),
                            IconButton(
                              tooltip: '도면 삭제',
                              icon: Icon(Icons.delete_outline,
                                  size: 18, color: theme.colorScheme.error),
                              onPressed: () => _confirmDelete(drawing),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => context.go('/drawing/${drawing.id}'),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        _buildFab(),
      ],
    );
  }

  Widget _buildFab() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: FloatingActionButton(
        heroTag: 'drawing_new',
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
