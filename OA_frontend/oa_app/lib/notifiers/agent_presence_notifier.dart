import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart' show Presence, SinglePresenceState;

/// 에이전트 Presence 상태 항목
class AgentPresence {
  final String assetUid;
  final String platform;
  final String agentVersion;
  final DateTime connectedAt;

  const AgentPresence({
    required this.assetUid,
    required this.platform,
    required this.agentVersion,
    required this.connectedAt,
  });

  factory AgentPresence.fromPresence(Map<String, dynamic> data) {
    return AgentPresence(
      assetUid: data['asset_uid'] as String? ?? '',
      platform: data['platform'] as String? ?? 'unknown',
      agentVersion: data['agent_version'] as String? ?? '',
      connectedAt: data['connected_at'] != null
          ? DateTime.parse(data['connected_at'] as String)
          : DateTime.now(),
    );
  }
}

/// 에이전트 Presence 상태 관리 Notifier
///
/// Supabase Realtime Presence 채널(`agent-presence:global`)에서 수신한
/// 에이전트 접속 상태를 관리합니다.
/// key: asset_uid, value: AgentPresence
class AgentPresenceNotifier extends Notifier<Map<String, AgentPresence>> {
  @override
  Map<String, AgentPresence> build() => {};

  /// sync 이벤트 — 전체 접속 목록 교체
  void syncAll(List<SinglePresenceState> presences) {
    final map = <String, AgentPresence>{};
    for (final sps in presences) {
      for (final presence in sps.presences) {
        final data = presence.payload;
        final p = AgentPresence.fromPresence(data);
        if (p.assetUid.isNotEmpty) {
          map[p.assetUid] = p;
        }
      }
    }
    state = map;
  }

  /// join 이벤트 — 새 에이전트 접속 추가
  void addAgents(List<Presence> newPresences) {
    final updated = Map<String, AgentPresence>.from(state);
    for (final presence in newPresences) {
      final p = AgentPresence.fromPresence(presence.payload);
      if (p.assetUid.isNotEmpty) {
        updated[p.assetUid] = p;
      }
    }
    state = updated;
  }

  /// leave 이벤트 — 에이전트 접속 제거
  void removeAgents(List<Presence> leftPresences) {
    final updated = Map<String, AgentPresence>.from(state);
    for (final presence in leftPresences) {
      final assetUid = presence.payload['asset_uid'] as String? ?? '';
      updated.remove(assetUid);
    }
    state = updated;
  }

  /// 특정 asset_uid의 Presence 연결 여부
  bool isConnected(String assetUid) => state.containsKey(assetUid);
}

/// AgentPresence Provider
final agentPresenceNotifierProvider =
    NotifierProvider<AgentPresenceNotifier, Map<String, AgentPresence>>(
  AgentPresenceNotifier.new,
);
