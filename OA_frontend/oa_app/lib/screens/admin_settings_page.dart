import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifiers/auth_notifier.dart';
import '../services/api_service.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';

/// 관리자 에이전트 설정 페이지.
///
/// agent_settings 테이블의 설정값을 조회/수정합니다.
/// RLS 정책에 의해 admin 권한 사용자만 수정 가능합니다.
class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _settings = [];

  // heartbeat_interval 전용
  int _heartbeatInterval = 5;
  final _intervalOptions = [5, 10, 15, 30];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final settings = await _api.fetchAgentSettings();
      _settings = settings;

      // heartbeat_interval 초기값 설정
      final hbSetting = settings.firstWhere(
        (s) => s['setting_key'] == 'heartbeat_interval',
        orElse: () => {'setting_value': '5'},
      );
      _heartbeatInterval =
          int.tryParse(hbSetting['setting_value'] as String? ?? '5') ?? 5;

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _updateHeartbeatInterval(int value) async {
    try {
      await _api.updateAgentSetting('heartbeat_interval', value.toString());
      setState(() => _heartbeatInterval = value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Heartbeat 주기가 ${value}분으로 변경되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('변경 실패: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull?.user;
    final isAdmin = user?.isAdminGroup ?? false;

    return AppScaffold(
      title: '에이전트 설정',
      currentIndex: -1,
      body: _buildBody(context, isAdmin),
    );
  }

  Widget _buildBody(BuildContext context, bool isAdmin) {
    if (_isLoading) {
      return const LoadingWidget(message: '설정을 불러오는 중...');
    }
    if (_error != null) {
      return AppErrorWidget(message: _error!, onRetry: _loadSettings);
    }
    if (!isAdmin) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('관리자 권한이 필요합니다.', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _loadSettings,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Heartbeat 주기 설정 카드 ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Heartbeat 전송 주기',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '에이전트가 서버에 장비 상태를 보고하는 주기입니다.\n'
                    '변경 시 모든 에이전트가 다음 접속 때 새 주기를 적용합니다.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<int>(
                    segments: _intervalOptions.map((v) {
                      return ButtonSegment<int>(
                        value: v,
                        label: Text('${v}분'),
                      );
                    }).toList(),
                    selected: {_heartbeatInterval},
                    onSelectionChanged: (selected) {
                      final value = selected.first;
                      if (value != _heartbeatInterval) {
                        _updateHeartbeatInterval(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── 기타 에이전트 설정 표시 ──
          Text(
            '기타 에이전트 설정',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._settings
              .where((s) => s['setting_key'] != 'heartbeat_interval')
              .map((s) => _buildSettingTile(s, theme)),
        ],
      ),
    );
  }

  Widget _buildSettingTile(Map<String, dynamic> setting, ThemeData theme) {
    final key = setting['setting_key'] as String? ?? '';
    final value = setting['setting_value'] as String? ?? '';
    final label = _settingLabel(key);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        title: Text(label),
        subtitle: Text(value),
        trailing: IconButton(
          icon: const Icon(Icons.edit, size: 20),
          onPressed: () => _showEditDialog(key, value, label),
        ),
      ),
    );
  }

  String _settingLabel(String key) {
    switch (key) {
      case 'latest_agent_version':
        return '최신 에이전트 버전';
      case 'min_agent_version':
        return '최소 에이전트 버전';
      case 'agent_download_url':
        return '에이전트 다운로드 URL';
      default:
        return key;
    }
  }

  Future<void> _showEditDialog(
      String key, String currentValue, String label) async {
    final controller = TextEditingController(text: currentValue);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '값',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (result != null && result != currentValue) {
      try {
        await _api.updateAgentSetting(key, result);
        await _loadSettings();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label이(가) 변경되었습니다.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('변경 실패: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
