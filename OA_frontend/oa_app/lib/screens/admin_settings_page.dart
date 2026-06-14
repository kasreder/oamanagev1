import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/inspection_round.dart';
import '../models/user.dart' as app_user;
import '../notifiers/auth_notifier.dart';
import '../services/api_service.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/error_widget.dart';
import '../widgets/common/loading_widget.dart';

/// 관리자 에이전트 설정 페이지.
///
/// agent_settings 테이블의 설정값을 조회/수정합니다.
/// RLS 정책에 의해 admin 권한 사용자만 수정 가능합니다.
class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _settings = [];

  // 유저 정보 탭
  List<Map<String, dynamic>> _users = [];
  String? _usersLoadError;
  bool _usersLoading = false;

  // heartbeat_interval 전용
  int _heartbeatInterval = 5;
  final _intervalOptions = [5, 10, 15, 30, 1440];

  // 마스터 관리자 관련 상태
  static const int _masterLimit = 4;
  List<Map<String, dynamic>> _admins = []; // role='admin' 사용자 전체
  String? _adminsLoadError;

  // 실사 회차 관련 상태
  InspectionRound? _activeRound;
  List<InspectionRound> _rounds = [];
  bool _isRoundBusy = false;
  String? _roundsLoadError;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAdmins();
    _loadRounds();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _usersLoading = true);
    try {
      // RLS: 일반 user는 자기 행만 보이도록 정책이 잡혀 있어야 함.
      // 관리자/마스터관리자는 RLS 정책에서 전체 허용.
      final rows = await Supabase.instance.client
          .from('users')
          .select(
              'id, employee_id, employee_name, role, is_master_admin, organization_dept, created_at')
          .order('role', ascending: false)
          .order('employee_id');
      if (!mounted) return;
      setState(() {
        _users = List<Map<String, dynamic>>.from(rows as List);
        _usersLoadError = null;
        _usersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usersLoadError = e.toString();
        _usersLoading = false;
      });
    }
  }

  /// role 변경 — 관리자 그룹만 사용.
  Future<void> _updateUserRole(String employeeId, String role) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({'role': role})
          .eq('employee_id', employeeId);
      // 권한이 admin이 아니면 is_master_admin도 false로 자동 정리
      if (role != 'admin') {
        await Supabase.instance.client
            .from('users')
            .update({'is_master_admin': false})
            .eq('employee_id', employeeId);
      }
      await Future.wait([_loadUsers(), _loadAdmins()]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$employeeId 권한이 $role 로 변경되었습니다.')),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('변경 실패: ${e.message}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SelectableText('변경 실패: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _resetUserPassword(String employeeId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$employeeId 비번 초기화'),
        content: Text('$employeeId 의 비밀번호를 [$employeeId' '1234!]로 초기화합니다. 계속하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('초기화')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.rpc(
        'admin_reset_user_password',
        params: {'p_employee_id': employeeId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$employeeId 비번 초기화 완료')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SelectableText('초기화 실패: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _loadRounds() async {
    try {
      final all = await _api.fetchRounds();
      final active = await _api.fetchActiveRound();
      if (!mounted) return;
      setState(() {
        _rounds = all;
        _activeRound = active;
        _roundsLoadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _roundsLoadError = e.toString());
    }
  }

  Future<void> _loadAdmins() async {
    try {
      final rows = await Supabase.instance.client
          .from('users')
          .select('id, employee_id, employee_name, is_master_admin')
          .eq('role', 'admin')
          .order('employee_id');
      if (!mounted) return;
      setState(() {
        _admins = List<Map<String, dynamic>>.from(rows as List);
        _adminsLoadError = null;
      });
    } catch (e, st) {
      // ignore: avoid_print
      print('[admin_settings] _loadAdmins failed: $e\n$st');
      if (!mounted) return;
      setState(() => _adminsLoadError = e.toString());
    }
  }

  Future<void> _toggleMaster(String employeeId, bool value) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({'is_master_admin': value})
          .eq('employee_id', employeeId);
      await Future.wait([_loadAdmins(), _loadUsers()]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value
            ? '$employeeId 을(를) 마스터 관리자로 지정했습니다.'
            : '$employeeId 의 마스터 관리자 권한을 해제했습니다.')),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('실패: ${e.message}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('실패: $e')),
      );
    }
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
        SnackBar(
          content: Text(
            'Heartbeat 주기가 ${value >= 60 ? '${value ~/ 60}시간' : '$value분'}으로 변경되었습니다.',
          ),
        ),
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
    final tabs = <Tab>[
      const Tab(text: '시스템 설정', icon: Icon(Icons.settings, size: 18)),
      const Tab(text: '유저 정보', icon: Icon(Icons.people, size: 18)),
      if (isAdmin)
        const Tab(text: '아이디 생성', icon: Icon(Icons.person_add, size: 18)),
      if (isAdmin)
        const Tab(text: '권한 관리', icon: Icon(Icons.shield, size: 18)),
    ];

    return AppScaffold(
      title: '설정',
      showPrimaryNav: false,
      body: DefaultTabController(
        length: tabs.length,
        child: Column(
          children: [
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: TabBar(tabs: tabs),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSystemTab(context, isAdmin, user),
                  _buildUsersTab(context, user),
                  if (isAdmin) _buildCreateUserTab(context, user),
                  if (isAdmin) _buildPermissionsTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 권한 관리 탭 (관리자 그룹 전용) ────────────────────────────────────────
  static const List<_Role> _roles = [
    _Role('master', '마스터관리자', Colors.red),
    _Role('admin', '관리자', Colors.blue),
    _Role('operator1', '운영자1', Colors.teal),
    _Role('operator2', '운영자2', Colors.teal),
    _Role('user', '일반', Colors.grey),
  ];

  /// 권한 매트릭스 — 코드/RLS의 실제 검사 흐름을 토대로 정리.
  /// 값: true=허용, false=차단, null=조건부 (셀에 △ 표시)
  static const List<_Permission> _permissions = [
    // 일반 사용
    _Permission('자산 목록 조회', {
      'master': true, 'admin': true, 'operator1': true,
      'operator2': true, 'user': true,
    }),
    _Permission('자산 등록/수정/삭제', {
      'master': true, 'admin': true, 'operator1': true,
      'operator2': true, 'user': false,
    }),
    _Permission('자산 CSV 내보내기', {
      'master': true, 'admin': true, 'operator1': true,
      'operator2': true, 'user': false,
    }),
    _Permission('실사 회차 생성/시작/종료/삭제', {
      'master': true, 'admin': true, 'operator1': false,
      'operator2': false, 'user': false,
    }),
    _Permission('실사 등록 (잠금)', {
      'master': true, 'admin': true, 'operator1': true,
      'operator2': true, 'user': null,
    }),
    _Permission('실사 등록취소 (잠금 해제)', {
      'master': true, 'admin': true, 'operator1': false,
      'operator2': false, 'user': false,
    }),
    _Permission('재실사 요청', {
      'master': true, 'admin': true, 'operator1': true,
      'operator2': true, 'user': true,
    }),
    // 사용자/권한 관리
    _Permission('사용자 생성', {
      'master': true, 'admin': true, 'operator1': false,
      'operator2': false, 'user': false,
    }),
    _Permission('사용자 비번 초기화', {
      'master': true, 'admin': true, 'operator1': true,
      'operator2': true, 'user': false,
    }),
    _Permission('사용자 권한 변경', {
      'master': true, 'admin': true, 'operator1': true,
      'operator2': true, 'user': false,
    }),
    _Permission('마스터 관리자 지정 (최대 4명)', {
      'master': true, 'admin': null, 'operator1': false,
      'operator2': false, 'user': false,
    }),
    // 시스템
    _Permission('설정 페이지 접근', {
      'master': true, 'admin': true, 'operator1': true,
      'operator2': true, 'user': false,
    }),
    _Permission('Heartbeat/Agent 설정 변경', {
      'master': true, 'admin': true, 'operator1': false,
      'operator2': false, 'user': false,
    }),
    _Permission('알림(notifications) 발송', {
      'master': true, 'admin': true, 'operator1': true,
      'operator2': true, 'user': false,
    }),
  ];

  Widget _buildPermissionsTab(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '권한 그룹별 기능 매트릭스',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          '○ 허용 / ✗ 차단 / △ 조건부 (활성 회차 등 추가 조건 필요)',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                theme.colorScheme.surfaceContainerHighest,
              ),
              columns: [
                const DataColumn(
                  label: Text('기능',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ..._roles.map(
                  (r) => DataColumn(
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: r.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            r.label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: r.color,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              rows: _permissions.map((p) {
                return DataRow(cells: [
                  DataCell(Text(p.label,
                      style: const TextStyle(fontSize: 13))),
                  ..._roles.map((r) {
                    final v = p.allowed[r.code];
                    final label = v == true ? '○' : (v == false ? '✗' : '△');
                    final color = v == true
                        ? Colors.green
                        : (v == false
                            ? theme.colorScheme.outline
                            : Colors.orange);
                    return DataCell(
                      Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    );
                  }),
                ]);
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: theme.colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('그룹 정의', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                _legendRow(theme, '마스터관리자',
                    'role=admin AND is_master_admin=true. 최대 4명. 마스터 지정/해제 권한 보유.'),
                _legendRow(theme, '관리자(admin)',
                    'admin. 모든 운영 기능. 마스터관리자만이 마스터 지정 가능.'),
                _legendRow(theme, '운영자(operator1/2)',
                    'isAdminGroup에 포함. 일반 운영 — 회차/lock 해제 등 일부 제한.'),
                _legendRow(theme, '일반(user)',
                    '읽기 위주. 본인 실사는 회차 중에만 등록.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendRow(ThemeData theme, String name, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodySmall,
          children: [
            TextSpan(
              text: '$name — ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: desc,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemTab(BuildContext ctx, bool isAdmin, app_user.User? user) {
    try {
      return _buildBody(ctx, isAdmin, user);
    } catch (e, st) {
      return AppErrorWidget(
        message: '본문 빌드 실패: $e',
        onRetry: () {
          // ignore: avoid_print
          print('[admin_settings] build error: $e\n$st');
          _loadSettings();
          _loadAdmins();
        },
      );
    }
  }

  Widget _buildUsersTab(BuildContext context, app_user.User? me) {
    final theme = Theme.of(context);
    if (_usersLoading) {
      return const LoadingWidget(message: '사용자 정보를 불러오는 중...');
    }
    if (_usersLoadError != null && _users.isEmpty) {
      return AppErrorWidget(
        message: '사용자 목록을 불러오지 못했습니다.\n$_usersLoadError',
        onRetry: _loadUsers,
      );
    }

    final isMine = (Map<String, dynamic> u) =>
        me?.employeeId != null && u['employee_id'] == me!.employeeId;
    final canManage = me?.isAdminGroup ?? false;
    final visible = canManage
        ? _users
        : _users.where(isMine).toList();
    final masterCount =
        _users.where((u) => u['is_master_admin'] == true).length;
    final df = (DateTime? d) =>
        d == null ? '-' : d.toLocal().toString().substring(0, 10);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text('총 ${visible.length}명',
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              tooltip: '새로고침',
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('표시할 사용자가 없습니다.')),
          )
        else
          ...visible.map((u) {
            final empId = u['employee_id'] as String? ?? '-';
            final empName = u['employee_name'] as String? ?? '-';
            final role = u['role'] as String? ?? 'user';
            final isMaster = u['is_master_admin'] == true;
            final dept = u['organization_dept'] as String? ?? '-';
            final createdAt = u['created_at'] != null
                ? DateTime.tryParse(u['created_at'] as String)
                : null;
            final roleLabel = isMaster
                ? '마스터관리자'
                : (role == 'admin'
                    ? '관리자'
                    : (role.startsWith('operator') ? '운영자' : '일반'));
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$empName ($empId)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isMaster
                                ? Colors.red.withValues(alpha: 0.15)
                                : (role == 'admin'
                                    ? Colors.blue.withValues(alpha: 0.15)
                                    : theme.colorScheme.surfaceContainerHigh),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            roleLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isMaster
                                  ? Colors.red
                                  : (role == 'admin'
                                      ? Colors.blue
                                      : theme.colorScheme.onSurface),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        Text('사번: $empId',
                            style: theme.textTheme.bodySmall),
                        Text('부서: $dept',
                            style: theme.textTheme.bodySmall),
                        Text('가입일: ${df(createdAt)}',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                    if (canManage) ...[
                      const SizedBox(height: 8),
                      // 권한 변경 (드롭다운)
                      Row(
                        children: [
                          const Text('권한: ', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          DropdownButton<String>(
                            value: role,
                            isDense: true,
                            items: const [
                              DropdownMenuItem(
                                  value: 'user', child: Text('일반')),
                              DropdownMenuItem(
                                  value: 'operator1', child: Text('운영자1')),
                              DropdownMenuItem(
                                  value: 'operator2', child: Text('운영자2')),
                              DropdownMenuItem(
                                  value: 'admin', child: Text('관리자')),
                            ],
                            onChanged: (v) {
                              if (v == null || v == role) return;
                              _updateUserRole(empId, v);
                            },
                          ),
                          const SizedBox(width: 12),
                          // 마스터 관리자 스위치 (admin인 경우만)
                          if (role == 'admin') ...[
                            const Text('마스터:',
                                style: TextStyle(fontSize: 13)),
                            Switch(
                              value: isMaster,
                              onChanged: (!isMaster &&
                                      masterCount >= _masterLimit)
                                  ? null
                                  : (v) => _toggleMaster(empId, v),
                            ),
                          ],
                        ],
                      ),
                      if (role == 'admin' &&
                          !isMaster &&
                          masterCount >= _masterLimit)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '마스터 관리자는 최대 $_masterLimit명까지 지정할 수 있습니다.',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => _resetUserPassword(empId),
                          icon: const Icon(Icons.lock_reset, size: 16),
                          label: Text('비번 초기화 ($empId' '1234!)'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCreateUserTab(BuildContext context, app_user.User? me) {
    return _CreateUserForm(onCreated: _loadUsers);
  }

  Widget _buildBody(
    BuildContext context,
    bool isAdmin,
    app_user.User? user,
  ) {
    final theme = Theme.of(context);

    if (_isLoading && _settings.isEmpty) {
      return const LoadingWidget(message: '설정 정보를 불러오는 중입니다...');
    }

    if (_error != null && _settings.isEmpty) {
      return AppErrorWidget(
        message: '설정을 불러오지 못했습니다.\n$_error',
        onRetry: () {
          _loadSettings();
          _loadAdmins();
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '기본 정보',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text('접속 사용자: ${user?.employeeName ?? '-'}'),
                Text('사번: ${user?.employeeId ?? '-'}'),
                Text('권한 그룹: ${user?.role ?? '-'}'),
                Text('관리자 화면 접근 가능: ${isAdmin ? '예' : '아니오'}'),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '일부 데이터를 불러오지 못했습니다: $_error',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    _loadSettings();
                    _loadAdmins();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('새로고침'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Heartbeat 주기',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '에이전트 상태 보고 주기를 선택합니다. 현재 값은 ${_heartbeatInterval >= 60 ? '${_heartbeatInterval ~/ 60}시간' : '$_heartbeatInterval분'}입니다.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _intervalOptions.map((value) {
                    final isSelected = value == _heartbeatInterval;
                    return ChoiceChip(
                      label: Text(value >= 60 ? '${value ~/ 60}시간' : '$value분'),
                      selected: isSelected,
                      onSelected: (_) => _updateHeartbeatInterval(value),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '버전 및 다운로드 설정',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._settings
                    .where((setting) => setting['setting_key'] != 'heartbeat_interval')
                    .map(
                      (setting) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_settingLabel(setting['setting_key'] as String)),
                        subtitle: SelectableText(
                          (setting['setting_value'] as String?)?.isNotEmpty == true
                              ? setting['setting_value'] as String
                              : '-',
                        ),
                        trailing: IconButton(
                          onPressed: () => _showEditDialog(
                            setting['setting_key'] as String,
                            setting['setting_value'] as String? ?? '',
                            _settingLabel(setting['setting_key'] as String),
                          ),
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: '수정',
                        ),
                      ),
                    ),
                if (_settings.where((setting) => setting['setting_key'] != 'heartbeat_interval').isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('표시할 설정이 없습니다.'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildRoundManagementCard(context, isAdmin),
      ],
    );
  }

  // ── 회차(라운드) 관리 카드 ────────────────────────────────────────────────
  Widget _buildRoundManagementCard(BuildContext context, bool isAdmin) {
    final theme = Theme.of(context);
    final active = _activeRound;
    // 년도 → 차수 정렬 (최근 우선)
    final sorted = List<InspectionRound>.from(_rounds)
      ..sort((a, b) {
        if (a.year != b.year) return b.year.compareTo(a.year);
        return b.round.compareTo(a.round);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_repeat, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '실사 회차 관리',
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: '새로고침',
                  onPressed: _loadRounds,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_roundsLoadError != null)
              Text(
                '회차 정보를 불러오지 못했습니다: $_roundsLoadError',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            // 활성 라운드 상태
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: active != null
                    ? Colors.blue.withValues(alpha: 0.08)
                    : theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    active != null
                        ? Icons.play_circle
                        : Icons.pause_circle_outline,
                    color: active != null
                        ? Colors.blue
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      active != null
                          ? '진행 중: ${active.year}년 ${active.round}차 — ${active.title}'
                          : '현재 진행 중인 라운드가 없습니다',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 액션 버튼 영역
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      (!isAdmin || _isRoundBusy) ? null : _createNextRound,
                  icon: const Icon(Icons.add),
                  label: const Text('새 라운드 생성'),
                ),
                if (active != null)
                  OutlinedButton.icon(
                    onPressed: (!isAdmin || _isRoundBusy)
                        ? null
                        : () => _closeRound(active),
                    icon: const Icon(Icons.stop_circle),
                    label: const Text('현재 라운드 종료(등록 완료)'),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 라운드 목록 (년도/차수 별 관리)
            if (sorted.isNotEmpty) ...[
              Text(
                '전체 회차 (${sorted.length}건)',
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...sorted.map((r) {
                final isActive = r.status == 'active';
                final isClosed = r.status == 'closed';
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isActive
                          ? Colors.blue
                          : theme.colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.blue
                              : isClosed
                                  ? theme.colorScheme.surfaceContainerHigh
                                  : Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isActive ? '진행중' : (isClosed ? '종료됨' : '대기'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r.year}년 ${r.round}차',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              r.title,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 액션 (status별 다름)
                      if (isClosed)
                        IconButton(
                          tooltip: '재오픈',
                          icon: const Icon(Icons.replay, size: 18),
                          onPressed: (!isAdmin || _isRoundBusy)
                              ? null
                              : () => _reopenRound(r),
                        ),
                      if (!isActive && !isClosed)
                        IconButton(
                          tooltip: '시작',
                          icon: const Icon(Icons.play_arrow, size: 18),
                          onPressed: (!isAdmin || _isRoundBusy)
                              ? null
                              : () => _startRoundDirect(r),
                        ),
                      if (isActive)
                        IconButton(
                          tooltip: '종료(등록 완료)',
                          icon: const Icon(Icons.stop_circle, size: 18),
                          onPressed: (!isAdmin || _isRoundBusy)
                              ? null
                              : () => _closeRound(r),
                        ),
                      if (!isActive)
                        IconButton(
                          tooltip: '삭제',
                          icon: Icon(Icons.delete_outline,
                              size: 18, color: theme.colorScheme.error),
                          onPressed: (!isAdmin || _isRoundBusy)
                              ? null
                              : () => _deleteRound(r),
                        ),
                    ],
                  ),
                );
              }),
            ],
            if (!isAdmin) ...[
              const SizedBox(height: 8),
              Text(
                '회차 생성/종료/재오픈은 관리자(admin)만 가능합니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _createNextRound() async {
    final result = await showDialog<_NewRoundInput>(
      context: context,
      builder: (ctx) => _NewRoundDialog(existingRounds: _rounds),
    );
    if (result == null) return;

    setState(() => _isRoundBusy = true);
    try {
      final created = await _api.createRound({
        'year': result.year,
        'round': result.round,
        'title': result.title,
      });
      // 현재 활성 라운드 없을 때만 자동 시작
      if (result.autoStart && _activeRound == null) {
        await _api.startRound(created.id);
      }
      await _loadRounds();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.year}년 ${result.round}차 '
              '${result.autoStart && _activeRound == null ? '시작됨' : '생성됨'}',
            ),
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('실패: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRoundBusy = false);
    }
  }

  /// 라운드 즉시 시작 (목록의 draft/closed 항목에서 호출)
  Future<void> _startRoundDirect(InspectionRound round) async {
    if (_activeRound != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 진행 중인 라운드가 있습니다.')),
        );
      }
      return;
    }
    setState(() => _isRoundBusy = true);
    try {
      await _api.startRound(round.id);
      await _loadRounds();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRoundBusy = false);
    }
  }

  Future<void> _closeRound(InspectionRound round) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${round.year}년 ${round.round}차 종료'),
        content: const Text(
            '라운드를 종료하면 일반 사용자는 실사를 수정할 수 없게 됩니다. 계속하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('종료')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _isRoundBusy = true);
    try {
      await _api.closeRound(round.id);
      await _loadRounds();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRoundBusy = false);
    }
  }

  Future<void> _deleteRound(InspectionRound round) async {
    if (round.status == 'active') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('진행 중인 라운드는 먼저 종료한 뒤 삭제해주세요.')),
      );
      return;
    }
    final ok = await showDialog<_DeleteRoundChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${round.year}년 ${round.round}차 삭제'),
        content: const Text(
          '라운드를 삭제하면 되돌릴 수 없습니다.\n\n'
          '이 라운드에 속한 실사가 있다면 옵션:\n'
          ' • 일반 삭제: 실사가 있으면 거부\n'
          ' • 강제 삭제: 실사들을 라운드에서 분리(round_id=NULL) 후 삭제',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _DeleteRoundChoice.cancel),
            child: const Text('취소'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, _DeleteRoundChoice.force),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('강제 삭제'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, _DeleteRoundChoice.normal),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('삭제'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
          ),
        ],
      ),
    );
    if (ok == null || ok == _DeleteRoundChoice.cancel) return;
    setState(() => _isRoundBusy = true);
    try {
      await _api.deleteRound(round.id, force: ok == _DeleteRoundChoice.force);
      await _loadRounds();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${round.year}년 ${round.round}차 삭제됨')),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('삭제 실패: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('삭제 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRoundBusy = false);
    }
  }

  Future<void> _reopenRound(InspectionRound round) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${round.year}년 ${round.round}차 재오픈'),
        content: const Text(
            '종료된 라운드를 다시 활성화합니다. 동시에 1개만 활성화될 수 있습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('재오픈')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _isRoundBusy = true);
    try {
      await _api.reopenRound(round.id);
      await _loadRounds();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRoundBusy = false);
    }
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

// ── 신규 유저 생성 폼 ─────────────────────────────────────────────────────
class _CreateUserForm extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateUserForm({required this.onCreated});

  @override
  State<_CreateUserForm> createState() => _CreateUserFormState();
}

class _CreateUserFormState extends State<_CreateUserForm> {
  final _empIdCtrl = TextEditingController();
  final _empNameCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  String _role = 'user';
  bool _busy = false;
  String? _error;

  static const _roles = [
    ('user', '일반 사용자'),
    ('operator1', '운영자1'),
    ('operator2', '운영자2'),
    ('admin', '관리자'),
  ];

  @override
  void dispose() {
    _empIdCtrl.dispose();
    _empNameCtrl.dispose();
    _deptCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final empId = _empIdCtrl.text.trim();
    final empName = _empNameCtrl.text.trim();
    final dept = _deptCtrl.text.trim();
    if (empId.isEmpty || empName.isEmpty) {
      setState(() => _error = '사번과 이름은 필수입니다.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc(
        'admin_create_user',
        params: {
          'p_employee_id': empId,
          'p_employee_name': empName,
          'p_role': _role,
          'p_org_dept': dept.isEmpty ? null : dept,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$empId 생성됨 (초기비번: $empId' '1234!)')),
      );
      _empIdCtrl.clear();
      _empNameCtrl.clear();
      _deptCtrl.clear();
      setState(() => _role = 'user');
      widget.onCreated();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '생성 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '신규 아이디 생성',
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '초기 비밀번호는 [사번 + 1234!] 패턴으로 자동 부여됩니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _empIdCtrl,
                  decoration: const InputDecoration(
                    labelText: '사번 (employee_id) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _empNameCtrl,
                  decoration: const InputDecoration(
                    labelText: '이름 *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _deptCtrl,
                  decoration: const InputDecoration(
                    labelText: '부서 (선택)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(
                    labelText: '권한 *',
                    border: OutlineInputBorder(),
                  ),
                  items: _roles
                      .map((r) =>
                          DropdownMenuItem(value: r.$1, child: Text(r.$2)))
                      .toList(),
                  onChanged: (v) => setState(() => _role = v ?? 'user'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add),
                  label: const Text('생성'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _DeleteRoundChoice { cancel, normal, force }

class _Role {
  final String code;
  final String label;
  final Color color;
  const _Role(this.code, this.label, this.color);
}

class _Permission {
  final String label;
  final Map<String, bool?> allowed; // value: true=○, false=✗, null=△
  const _Permission(this.label, this.allowed);
}

class _NewRoundInput {
  final int year;
  final int round;
  final String title;
  final bool autoStart;
  const _NewRoundInput({
    required this.year,
    required this.round,
    required this.title,
    required this.autoStart,
  });
}

/// 새 라운드 생성 다이얼로그 — 년도/차수/제목 직접 입력.
class _NewRoundDialog extends StatefulWidget {
  final List<InspectionRound> existingRounds;
  const _NewRoundDialog({required this.existingRounds});

  @override
  State<_NewRoundDialog> createState() => _NewRoundDialogState();
}

class _NewRoundDialogState extends State<_NewRoundDialog> {
  late final TextEditingController _yearCtrl;
  late final TextEditingController _roundCtrl;
  late final TextEditingController _titleCtrl;
  bool _autoStart = true;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().year;
    _yearCtrl = TextEditingController(text: '$now');
    // 현재 년도 max(round)+1, 없으면 1
    final inYear = widget.existingRounds.where((r) => r.year == now).toList();
    final nextRound = inYear.isEmpty
        ? 1
        : inYear.map((r) => r.round).reduce((a, b) => a > b ? a : b) + 1;
    _roundCtrl = TextEditingController(text: '$nextRound');
    _titleCtrl = TextEditingController(text: '$now년 $nextRound차 정기 실사');
    _yearCtrl.addListener(_syncTitle);
    _roundCtrl.addListener(_syncTitle);
  }

  void _syncTitle() {
    final y = int.tryParse(_yearCtrl.text);
    final r = int.tryParse(_roundCtrl.text);
    if (y != null && r != null) {
      final newTitle = '${y}년 ${r}차 정기 실사';
      if (_titleCtrl.text.startsWith(RegExp(r'\d{4}년 \d+차 '))) {
        _titleCtrl.text = newTitle;
      }
    }
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _roundCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  bool _isDuplicate(int year, int round) {
    return widget.existingRounds
        .any((r) => r.year == year && r.round == round);
  }

  void _submit() {
    final year = int.tryParse(_yearCtrl.text.trim());
    final round = int.tryParse(_roundCtrl.text.trim());
    final title = _titleCtrl.text.trim();
    setState(() => _validationError = null);
    if (year == null || year < 2000 || year > 2100) {
      setState(() => _validationError = '년도는 2000~2100 범위로 입력하세요.');
      return;
    }
    if (round == null || round < 0) {
      setState(() => _validationError = '차수는 0 이상 정수로 입력하세요.');
      return;
    }
    if (title.isEmpty) {
      setState(() => _validationError = '제목을 입력하세요.');
      return;
    }
    if (_isDuplicate(year, round)) {
      setState(() => _validationError = '${year}년 ${round}차는 이미 존재합니다.');
      return;
    }
    Navigator.pop(
      context,
      _NewRoundInput(
        year: year,
        round: round,
        title: title,
        autoStart: _autoStart,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('새 라운드 생성'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _yearCtrl,
                    decoration: const InputDecoration(
                      labelText: '년도',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _roundCtrl,
                    decoration: const InputDecoration(
                      labelText: '차수 (0 이상)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('생성 후 즉시 시작'),
              subtitle: const Text('(다른 활성 라운드가 없을 때)'),
              value: _autoStart,
              onChanged: (v) => setState(() => _autoStart = v),
            ),
            if (_validationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _validationError!,
                  style: TextStyle(
                      color: theme.colorScheme.error, fontSize: 12),
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
          onPressed: _submit,
          child: const Text('생성'),
        ),
      ],
    );
  }
}
