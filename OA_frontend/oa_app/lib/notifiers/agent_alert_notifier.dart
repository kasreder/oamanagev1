import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 에이전트 Broadcast 알림 항목
class AgentAlert {
  final String assetUid;
  final String alertType;
  final String message;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  bool isRead;

  AgentAlert({
    required this.assetUid,
    required this.alertType,
    required this.message,
    required this.data,
    required this.timestamp,
    this.isRead = false,
  });

  factory AgentAlert.fromPayload(Map<String, dynamic> payload) {
    return AgentAlert(
      assetUid: payload['asset_uid'] as String? ?? '',
      alertType: payload['alert_type'] as String? ?? 'general',
      message: payload['message'] as String? ?? '',
      data: (payload['data'] as Map<String, dynamic>?) ?? {},
      timestamp: payload['timestamp'] != null
          ? DateTime.parse(payload['timestamp'] as String)
          : DateTime.now(),
    );
  }
}

/// 에이전트 Broadcast 알림 관리 Notifier
///
/// `agent-alerts:global` 채널에서 수신한 에이전트 긴급 알림을 관리합니다.
class AgentAlertNotifier extends Notifier<List<AgentAlert>> {
  @override
  List<AgentAlert> build() => [];

  /// 새 알림 추가 (Broadcast 수신 시)
  void addAlert(Map<String, dynamic> payload) {
    final alert = AgentAlert.fromPayload(payload);
    state = [alert, ...state];
  }

  /// 알림 읽음 처리
  void markAsRead(int index) {
    if (index < 0 || index >= state.length) return;
    state[index].isRead = true;
    state = List.from(state);
  }

  /// 전체 읽음 처리
  void markAllAsRead() {
    for (final alert in state) {
      alert.isRead = true;
    }
    state = List.from(state);
  }

  /// 읽지 않은 알림 수
  int get unreadCount => state.where((a) => !a.isRead).length;

  /// 알림 목록 초기화
  void clear() {
    state = [];
  }
}

/// AgentAlert Provider
final agentAlertNotifierProvider =
    NotifierProvider<AgentAlertNotifier, List<AgentAlert>>(
  AgentAlertNotifier.new,
);
