import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/drawing.dart';
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
  Future<void> _showCreateDialog() async {
    final buildingCtrl = TextEditingController();
    final floorCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    XFile? selectedImage;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('새 도면 등록'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: buildingCtrl,
                    decoration: const InputDecoration(
                      labelText: '건물명 *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: floorCtrl,
                    decoration: const InputDecoration(
                      labelText: '층 *',
                      hintText: '예: 1F, B1',
                      border: OutlineInputBorder(),
                    ),
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

                  // 이미지 선택
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
                          : '도면 이미지 선택',
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
                  if (buildingCtrl.text.trim().isEmpty ||
                      floorCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('건물명과 층을 입력하세요.')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('등록'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true) return;

    try {
      // 이미지 업로드
      String? drawingFile;
      if (selectedImage != null) {
        final bytes = await selectedImage!.readAsBytes();
        final ext = selectedImage!.name.split('.').last;
        final fileName =
            'drawings/${DateTime.now().millisecondsSinceEpoch}.$ext';

        await supabase.storage.from('drawings').uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );
        drawingFile = fileName;
      }

      // 도면 레코드 생성
      await _api.createDrawing({
        'building': buildingCtrl.text.trim(),
        'floor': floorCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        if (drawingFile != null) 'drawing_file': drawingFile,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('도면이 등록되었습니다.')),
        );
        _loadDrawings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('등록 실패: ${e.toString()}'),
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
                          drawing.description ??
                              '${drawing.gridRows}x${drawing.gridCols} 격자',
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: const Icon(Icons.chevron_right),
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
