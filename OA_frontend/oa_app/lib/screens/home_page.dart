import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

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
/// - 만료 임박 자산 (D-7 이내, supply_type='렌탈'|'대여')
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

  // 만료 임박 자산
  List<Asset> _expiringAssets = [];

  @override
  void initState() {
    super.initState();
    _loadData();
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

      // 만료 임박 자산 (D-7 이내)
      try {
        _expiringAssets = await _api.getExpiringAssets();
      } catch (_) {
        // RPC 미구성 시 직접 조회
        final now = DateTime.now();
        final sevenDaysLater = now.add(const Duration(days: 7));
        final expiringResult = await supabase
            .from('assets')
            .select()
            .inFilter('supply_type', ['렌탈', '대여'])
            .lte('supply_end_date', sevenDaysLater.toIso8601String())
            .gte('supply_end_date', now.toIso8601String())
            .order('supply_end_date', ascending: true);
        _expiringAssets = (expiringResult as List<dynamic>)
            .map((e) => Asset.fromJson(e as Map<String, dynamic>))
            .toList();
      }

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

          // ── 최신 등록 자산 ──
          Text(
            '최신 등록 자산',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_recentAssets.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: EmptyStateWidget(
                  icon: Icons.inventory_2,
                  message: '등록된 자산이 없습니다.',
                ),
              ),
            )
          else
            ..._recentAssets.map((asset) => _buildAssetTile(asset, brightness)),

          const SizedBox(height: 24),

          // ── 만료 임박 자산 ──
          Text(
            '만료 임박 자산 (D-7)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          if (_expiringAssets.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: EmptyStateWidget(
                  icon: Icons.check_circle_outline,
                  message: '만료 임박 자산이 없습니다.',
                  subMessage: '렌탈/대여 자산 중 7일 이내 만료 건이 없습니다.',
                ),
              ),
            )
          else
            ..._expiringAssets
                .map((asset) => _buildExpiringTile(asset, brightness)),
        ],
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
    final statusColor = getStatusColor(asset.assetsStatus, brightness);

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
            asset.assetsStatus,
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
  Widget _buildExpiringTile(Asset asset, Brightness brightness) {
    final theme = Theme.of(context);
    final daysLeft = asset.supplyEndDate != null
        ? asset.supplyEndDate!.difference(DateTime.now()).inDays
        : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.error.withOpacity(0.15),
          child: Icon(Icons.timer, color: theme.colorScheme.error, size: 20),
        ),
        title: Text(
          asset.name ?? asset.assetUid,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${asset.assetUid}  |  ${asset.supplyType}  |  만료: ${asset.supplyEndDate != null ? _dateFmt.format(asset.supplyEndDate!) : "-"}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'D-$daysLeft',
            style: TextStyle(
              color: theme.colorScheme.error,
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
