import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../notifiers/auth_notifier.dart';

import '../constants.dart';
import '../main.dart';
import '../models/asset.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';
import '../widgets/common/empty_state_widget.dart';

/// 5.1.2 홈 화면 (/)
///
/// - 상단 카드: 총 자산 수, 실사 완료율, 미검증 자산 수
/// - 최신 등록 자산 10건
/// - 만료 임박 자산 (D-7 이내, supply_type ∈ supplyTypesRequireEndDate = 렌탈/대여/도급/개인)
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ApiService _api = ApiService();
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');

  bool _isLoading = true;
  String? _error;

  // 대시보드 통계
  int _totalAssets = 0;
  double _inspectionRate = 0.0;
  int _unverifiedCount = 0;

  // 최신 등록 자산
  List<Asset> _recentAssets = [];

  // 대여일 만료예정 (D-7 이내)
  List<Asset> _expiringAssets = [];

  // 대여일 초과 자산
  List<Asset> _overdueAssets = [];

  // 실사용자 불일치 자산
  List<Asset> _mismatchAssets = [];

  // 접기/펼치기 (10건 초과면 기본 접힘)
  bool _overdueExpanded = true;
  bool _expiringExpanded = true;
  bool _noticesExpanded = true;

  // 전달사항 (관리자 그룹만 노출, SharedPreferences 영속, 완료 후 12h 자동삭제)
  List<_HomeNotice> _notices = [];
  static const String _noticesPrefsKey = 'home_notices_v1';
  static const int _noticesAutoExpireHours = 12;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadNotices();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 대시보드 통계 (Edge Function)
      Map<String, dynamic> stats;
      try {
        stats = await _api.fetchDashboardStats();
      } catch (_) {
        // Edge Function 미구성 시 fallback
        stats = {};
      }

      _totalAssets = (stats['total_assets'] as num?)?.toInt() ?? 0;
      _inspectionRate = (stats['inspection_rate'] as num?)?.toDouble() ?? 0.0;
      _unverifiedCount = (stats['unverified_count'] as num?)?.toInt() ?? 0;

      // 최신 등록 자산 10건
      final recentResult = await supabase
          .from('assets')
          .select()
          .order('created_at', ascending: false)
          .limit(10);
      _recentAssets = (recentResult as List<dynamic>)
          .map((e) => Asset.fromJson(e as Map<String, dynamic>))
          .toList();

      // Edge Function 실패 시 총 자산 수 보정
      if (_totalAssets == 0 && _recentAssets.isNotEmpty) {
        final countResult =
            await supabase.from('assets').select('id').count(CountOption.exact);
        _totalAssets = countResult.count;
      }

      // 대여일 만료예정 (D-7 이내) + 대여일 초과 자산
      try {
        final now = DateTime.now();
        final sevenDaysLater = now.add(const Duration(days: 7));

        // 만료예정: 오늘 ~ 7일 후
        final expiringResult = await supabase
            .from('assets')
            .select()
            .inFilter('supply_type', supplyTypesRequireEndDate.toList())
            .lte('supply_end_date', sevenDaysLater.toIso8601String())
            .gte('supply_end_date', now.toIso8601String())
            .order('supply_end_date', ascending: true);
        _expiringAssets = (expiringResult as List<dynamic>)
            .map((e) => Asset.fromJson(e as Map<String, dynamic>))
            .toList();

        // 초과: 만료일이 오늘 이전
        final overdueResult = await supabase
            .from('assets')
            .select()
            .inFilter('supply_type', supplyTypesRequireEndDate.toList())
            .lt('supply_end_date', now.toIso8601String())
            .order('supply_end_date', ascending: true);
        _overdueAssets = (overdueResult as List<dynamic>)
            .map((e) => Asset.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _expiringAssets = [];
        _overdueAssets = [];
      }

      // 실사용자 불일치 자산
      try {
        final mismatchResult = await supabase
            .from('assets')
            .select()
            .not('specifications->user_mismatch', 'is', null)
            .order('last_active_at', ascending: false);
        _mismatchAssets = (mismatchResult as List<dynamic>)
            .map((e) => Asset.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _mismatchAssets = [];
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // 10건 초과 시 기본 접힘
        _overdueExpanded = _overdueAssets.length <= 10;
        _expiringExpanded = _expiringAssets.length <= 10;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  // ── 전달사항: SharedPreferences IO + 12시간 자동 정리 ──────────────────
  Future<void> _loadNotices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_noticesPrefsKey);
      var list = <_HomeNotice>[];
      if (raw != null) {
        final arr = jsonDecode(raw) as List;
        list = arr
            .map((e) => _HomeNotice.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      // 완료 후 12시간 경과한 항목 제거
      final cutoff = DateTime.now()
          .subtract(const Duration(hours: _noticesAutoExpireHours));
      final filtered = list.where((n) {
        if (!n.completed) return true;
        if (n.completedAt == null) return true;
        return n.completedAt!.isAfter(cutoff);
      }).toList();
      if (filtered.length != list.length) {
        await prefs.setString(
            _noticesPrefsKey, jsonEncode(filtered.map((e) => e.toJson()).toList()));
      }
      if (!mounted) return;
      setState(() {
        _notices = filtered;
        _noticesExpanded = filtered.length <= 10;
      });
    } catch (_) {/* ignore */}
  }

  Future<void> _saveNotices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _noticesPrefsKey,
        jsonEncode(_notices.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _addNoticeDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('전달사항 등록'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '내용을 입력하세요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('등록')),
        ],
      ),
    );
    if (ok != true) return;
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _notices.insert(
        0,
        _HomeNotice(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          createdAt: DateTime.now(),
        ),
      );
    });
    _saveNotices();
  }

  void _toggleNoticeCompleted(_HomeNotice n, bool v) {
    setState(() {
      final idx = _notices.indexWhere((e) => e.id == n.id);
      if (idx < 0) return;
      _notices[idx] = _notices[idx].copyWith(
        completed: v,
        completedAt: v ? DateTime.now() : null,
      );
    });
    _saveNotices();
  }

  void _deleteNotice(_HomeNotice n) {
    setState(() => _notices.removeWhere((e) => e.id == n.id));
    _saveNotices();
  }

  /// 건수에 따른 강조 색 — 0~9: 기본, 10+: 노랑, 50+: 주황, 100+: 빨강
  Color _countBadgeColor(int count, ThemeData theme) {
    if (count >= 100) return Colors.red.shade700;
    if (count >= 50) return Colors.orange.shade700;
    if (count >= 10) return Colors.amber.shade700;
    return theme.colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '홈',
      currentIndex: 0,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const LoadingWidget(message: '대시보드를 불러오는 중...');
    }
    if (_error != null) {
      return AppErrorWidget(message: _error!, onRetry: _loadData);
    }

    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 상단 통계 카드 ──
          _buildStatsRow(context, brightness),
          const SizedBox(height: 24),

          // ── 전달사항 (관리자 그룹만) ──
          if ((ref.watch(authNotifierProvider).valueOrNull?.user?.isAdminGroup ??
              false)) ...[
            _buildSectionHeader(
              context,
              icon: Icons.campaign,
              title: '전달사항',
              count: _notices.length,
              expanded: _noticesExpanded,
              onToggle: () =>
                  setState(() => _noticesExpanded = !_noticesExpanded),
              trailing: TextButton.icon(
                onPressed: _addNoticeDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('등록'),
              ),
            ),
            if (_noticesExpanded) ...[
              const SizedBox(height: 8),
              if (_notices.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: EmptyStateWidget(
                      icon: Icons.campaign,
                      message: '등록된 전달사항이 없습니다.',
                      subMessage: '[등록] 버튼으로 한 줄씩 추가하세요. 완료 후 12시간 뒤 자동 삭제됩니다.',
                    ),
                  ),
                )
              else
                ..._notices.map((n) => _buildNoticeTile(n)),
            ],
            const SizedBox(height: 24),
          ],

          // ── 실사용자 불일치 자산 ──
          if (_mismatchAssets.isNotEmpty) ...[
            Text(
              '실사용자 불일치 (${_mismatchAssets.length}건)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 8),
            ..._mismatchAssets.map((asset) {
              final mismatch = (asset.specifications['user_mismatch']
                  as Map<String, dynamic>?) ?? {};
              return Card(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepOrange.withOpacity(0.15),
                    child: const Icon(Icons.person_off, color: Colors.deepOrange, size: 20),
                  ),
                  title: Text(asset.name ?? asset.assetUid, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${asset.assetUid}  |  등록: ${mismatch['expected'] ?? '-'}  →  에이전트: ${mismatch['actual'] ?? '-'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('불일치', style: TextStyle(
                      color: Colors.deepOrange, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  onTap: () => context.go('/asset/${asset.id}'),
                ),
              );
            }),
            const SizedBox(height: 24),
          ],

          // ── 대여일 초과 자산 ──
          _buildSectionHeader(
            context,
            icon: Icons.warning,
            title: '대여일 초과 자산',
            count: _overdueAssets.length,
            expanded: _overdueExpanded,
            onToggle: () =>
                setState(() => _overdueExpanded = !_overdueExpanded),
          ),
          if (_overdueExpanded) ...[
            const SizedBox(height: 8),
            if (_overdueAssets.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: EmptyStateWidget(
                    icon: Icons.check_circle_outline,
                    message: '대여일 초과 자산이 없습니다.',
                  ),
                ),
              )
            else
              ..._overdueAssets
                  .map((asset) => _buildOverdueTile(asset, brightness,
                      _countBadgeColor(_overdueAssets.length, theme))),
          ],

          const SizedBox(height: 24),

          // ── 대여일 만료예정 (D-7) ──
          _buildSectionHeader(
            context,
            icon: Icons.timer,
            title: '대여일 만료예정 (D-7)',
            count: _expiringAssets.length,
            expanded: _expiringExpanded,
            onToggle: () =>
                setState(() => _expiringExpanded = !_expiringExpanded),
          ),
          if (_expiringExpanded) ...[
            const SizedBox(height: 8),
            if (_expiringAssets.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: EmptyStateWidget(
                    icon: Icons.check_circle_outline,
                    message: '만료예정 자산이 없습니다.',
                    subMessage: '렌탈/대여/도급/개인 자산 중 7일 이내 만료 건이 없습니다.',
                  ),
                ),
              )
            else
              ..._expiringAssets
                  .map((asset) => _buildExpiringTile(asset, brightness,
                      _countBadgeColor(_expiringAssets.length, theme))),
          ],
        ],
      ),
    );
  }

  /// 섹션 헤더 — 좌측 아이콘+제목, 우측 건수 뱃지 + 펼침 아이콘 + 옵션 trailing
  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int count,
    required bool expanded,
    required VoidCallback onToggle,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final badgeColor = _countBadgeColor(count, theme);
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: badgeColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count건',
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            if (trailing != null) trailing,
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }

  /// 자산 타일 title — 자산번호 + 사용자 + 사용자부서
  Widget _buildAssetTitle(Asset asset, ThemeData theme) {
    final user = asset.userName?.isNotEmpty == true ? asset.userName! : '-';
    final dept = asset.userDepartment?.isNotEmpty == true
        ? asset.userDepartment!
        : '-';
    return RichText(
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        children: [
          TextSpan(
            text: asset.assetUid,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: '  ·  ',
            style: TextStyle(color: theme.colorScheme.outline),
          ),
          TextSpan(text: user),
          TextSpan(
            text: ' / $dept',
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeTile(_HomeNotice n) {
    final theme = Theme.of(context);
    final df = DateFormat('MM-dd HH:mm');
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        title: Text(
          n.text,
          style: TextStyle(
            decoration: n.completed ? TextDecoration.lineThrough : null,
            color: n.completed
                ? theme.colorScheme.outline
                : null,
          ),
        ),
        subtitle: Text(
          '등록: ${df.format(n.createdAt)}'
          '${n.completed ? '  /  완료: ${df.format(n.completedAt!)} (12h 후 자동삭제)' : ''}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: n.completed,
              onChanged: (v) => _toggleNoticeCompleted(n, v ?? false),
            ),
            IconButton(
              tooltip: '삭제',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteNotice(n),
            ),
          ],
        ),
      ),
    );
  }

  /// 상단 통계 카드 3개
  Widget _buildStatsRow(BuildContext context, Brightness brightness) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: '총 자산',
            value: '$_totalAssets',
            icon: Icons.inventory_2,
            color: brightness == Brightness.light
                ? AppColorsLight.statusAvailable
                : AppColorsDark.statusAvailable,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            title: '실사 완료율',
            value: '${(_inspectionRate * 100).toStringAsFixed(1)}%',
            icon: Icons.fact_check,
            color: brightness == Brightness.light
                ? AppColorsLight.statusUsing
                : AppColorsDark.statusUsing,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            title: '미검증',
            value: '$_unverifiedCount',
            icon: Icons.warning_amber,
            color: brightness == Brightness.light
                ? AppColorsLight.statusNeedCheck
                : AppColorsDark.statusNeedCheck,
            onTap: () => context.go('/unverified'),
          ),
        ),
      ],
    );
  }

  /// 최신 자산 목록 타일
  Widget _buildAssetTile(Asset asset, Brightness brightness) {
    final statusColor = getStatusColor(asset.supplyType, brightness);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.15),
          child: Icon(Icons.devices, color: statusColor, size: 20),
        ),
        title: Text(
          asset.name ?? asset.assetUid,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${asset.assetUid}  |  ${asset.category}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            asset.supplyType,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        onTap: () => context.go('/asset/${asset.id}'),
      ),
    );
  }

  /// 만료 임박 자산 타일
  Widget _buildExpiringTile(Asset asset, Brightness brightness, Color color) {
    final theme = Theme.of(context);
    final daysLeft = asset.supplyEndDate != null
        ? asset.supplyEndDate!.difference(DateTime.now()).inDays
        : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.timer, color: color, size: 20),
        ),
        title: _buildAssetTitle(asset, theme),
        subtitle: Text(
          asset.normalComment?.isNotEmpty == true ? asset.normalComment! : '',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'D-$daysLeft',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => context.go('/asset/${asset.id}'),
      ),
    );
  }

  /// 대여일 초과 자산 타일
  Widget _buildOverdueTile(Asset asset, Brightness brightness, Color color) {
    final theme = Theme.of(context);
    final daysOver = asset.supplyEndDate != null
        ? DateTime.now().difference(asset.supplyEndDate!).inDays
        : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.warning, color: color, size: 20),
        ),
        title: _buildAssetTitle(asset, theme),
        subtitle: Text(
          asset.normalComment?.isNotEmpty == true ? asset.normalComment! : '',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '+$daysOver일 초과',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => context.go('/asset/${asset.id}'),
      ),
    );
  }
}

/// 통계 카드 위젯
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 홈 전달사항 — SharedPreferences 영속, 완료 후 12시간 자동 삭제
class _HomeNotice {
  final String id;
  final String text;
  final DateTime createdAt;
  final bool completed;
  final DateTime? completedAt;

  const _HomeNotice({
    required this.id,
    required this.text,
    required this.createdAt,
    this.completed = false,
    this.completedAt,
  });

  _HomeNotice copyWith({bool? completed, DateTime? completedAt}) {
    return _HomeNotice(
      id: id,
      text: text,
      createdAt: createdAt,
      completed: completed ?? this.completed,
      completedAt: completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'completed': completed,
        'completedAt': completedAt?.toIso8601String(),
      };

  factory _HomeNotice.fromJson(Map<String, dynamic> j) => _HomeNotice(
        id: j['id'] as String,
        text: j['text'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        completed: j['completed'] == true,
        completedAt: j['completedAt'] != null
            ? DateTime.parse(j['completedAt'] as String)
            : null,
      );
}
