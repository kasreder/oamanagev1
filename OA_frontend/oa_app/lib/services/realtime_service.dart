import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/asset.dart';
import '../notifiers/asset_notifier.dart';
import '../notifiers/agent_presence_notifier.dart';
import '../notifiers/agent_alert_notifier.dart';
import 'api_service.dart';

/// Supabase Realtime 구독 총괄 관리
///
/// 인증 후 [subscribeAll]을 호출하여 Postgres Changes, Presence, Broadcast
/// 채널을 구독하고, 로그아웃 시 [unsubscribeAll]로 해제합니다.
class RealtimeService {
  RealtimeService(this._ref);

  final Ref _ref;
  final SupabaseClient _client = Supabase.instance.client;

  RealtimeChannel? _assetsChannel;
  RealtimeChannel? _inspectionsChannel;
  RealtimeChannel? _presenceChannel;
  RealtimeChannel? _alertsChannel;

  // ---------------------------------------------------------------------------
  // 전체 구독 관리
  // ---------------------------------------------------------------------------

  /// 모든 Realtime 채널 구독 시작
  void subscribeAll() {
    _subscribePostgresChanges();
    _subscribePresence();
    _subscribeAlerts();
  }

  /// 모든 Realtime 채널 구독 해제
  Future<void> unsubscribeAll() async {
    await _assetsChannel?.unsubscribe();
    await _inspectionsChannel?.unsubscribe();
    await _presenceChannel?.unsubscribe();
    await _alertsChannel?.unsubscribe();
    _assetsChannel = null;
    _inspectionsChannel = null;
    _presenceChannel = null;
    _alertsChannel = null;
  }

  // ---------------------------------------------------------------------------
  // Postgres Changes — assets, asset_inspections
  // ---------------------------------------------------------------------------

  void _subscribePostgresChanges() {
    // assets 테이블 UPDATE/INSERT/DELETE 이벤트
    _assetsChannel = _client
        .channel('assets-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'assets',
          callback: (payload) {
            try {
              final updated = Asset.fromJson(payload.newRecord);
              _ref.read(assetNotifierProvider.notifier).updateLocal(updated);
              ApiService.invalidateAssetsCache();
            } catch (_) {
              // JSON 파싱 실패 시 무시
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'assets',
          callback: (payload) {
            // 새 자산은 현재 필터/페이지에 맞춰 재fetch가 가장 안전
            ApiService.invalidateAssetsCache();
            final notifier = _ref.read(assetNotifierProvider.notifier);
            final state = _ref.read(assetNotifierProvider);
            notifier.fetchAssets(page: state.page);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'assets',
          callback: (payload) {
            try {
              final deletedUid = payload.oldRecord['asset_uid'] as String?;
              if (deletedUid != null) {
                _ref.read(assetNotifierProvider.notifier).removeLocal(deletedUid);
              }
              ApiService.invalidateAssetsCache();
            } catch (_) {}
          },
        )
        .subscribe();

    // asset_inspections INSERT 이벤트
    _inspectionsChannel = _client
        .channel('inspections-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'asset_inspections',
          callback: (payload) {
            // 실사 목록 갱신은 InspectionNotifier에서 처리
          },
        )
        .subscribe();
  }

  // ---------------------------------------------------------------------------
  // Presence — 에이전트 접속 상태
  // ---------------------------------------------------------------------------

  void _subscribePresence() {
    _presenceChannel = _client.channel('agent-presence:global');
    _presenceChannel!
        .onPresenceSync((payload) {
          final presences = _presenceChannel!.presenceState();
          _ref
              .read(agentPresenceNotifierProvider.notifier)
              .syncAll(presences);
        })
        .onPresenceJoin((payload) {
          _ref
              .read(agentPresenceNotifierProvider.notifier)
              .addAgents(payload.newPresences);
        })
        .onPresenceLeave((payload) {
          _ref
              .read(agentPresenceNotifierProvider.notifier)
              .removeAgents(payload.leftPresences);
        })
        .subscribe();
  }

  // ---------------------------------------------------------------------------
  // Broadcast — 에이전트 알림 수신
  // ---------------------------------------------------------------------------

  void _subscribeAlerts() {
    _alertsChannel = _client
        .channel('agent-alerts:global')
        .onBroadcast(
          event: 'alert',
          callback: (payload) {
            _ref.read(agentAlertNotifierProvider.notifier).addAlert(payload);
          },
        )
        .subscribe();
  }

  // ---------------------------------------------------------------------------
  // Broadcast — 관리자 명령 전송
  // ---------------------------------------------------------------------------

  /// 특정 기기 에이전트에 명령 전송
  Future<void> sendCommand(
    String assetUid,
    String command, {
    Map<String, dynamic>? params,
  }) async {
    final channel = _client.channel('agent-commands:$assetUid');
    await channel.sendBroadcastMessage(
      event: 'command',
      payload: {
        'command': command,
        'requested_by': _client.auth.currentUser?.email ?? '',
        'requested_at': DateTime.now().toUtc().toIso8601String(),
        'params': params ?? {},
      },
    );
    await channel.unsubscribe();
  }
}

/// RealtimeService Provider
final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  return RealtimeService(ref);
});
