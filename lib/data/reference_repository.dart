import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 단순 자산/사용자 참조 데이터.
class ReferenceDataRepository {
  final Map<String, AssetInfo> _assets = {};
  final Map<String, UserInfo> _users = {};

  Future<void> loadFromAssets() async {
    await Future.wait<void>([
      _loadAssets(),
      _loadUsers(),
    ]);
  }

  AssetInfo? findAsset(String uid) => _assets[uid];

  UserInfo? findUser(String id) => _users[id];

  Future<void> _loadAssets() async {
    try {
      final raw = await rootBundle.loadString('assets/mock/assets.json');
      final decoded = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
      _assets
        ..clear()
        ..addEntries(decoded.map(
          (item) => MapEntry(
            item['uid'] as String,
            AssetInfo(
              uid: item['uid'] as String,
              name: item['name'] as String? ?? '',
              model: item['model'] as String? ?? '',
              serial: item['serial'] as String? ?? '',
              vendor: item['vendor'] as String? ?? '',
              location: item['location'] as String? ?? '',
            ),
          ),
        ));
    } on FlutterError {
      _assets.clear();
    }
  }

  Future<void> _loadUsers() async {
    try {
      final raw = await rootBundle.loadString('assets/mock/users.json');
      final decoded = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
      _users
        ..clear()
        ..addEntries(decoded.map(
          (item) => MapEntry(
            item['id'] as String,
            UserInfo(
              id: item['id'] as String,
              name: item['name'] as String? ?? '',
              department: item['department'] as String? ?? '',
            ),
          ),
        ));
    } on FlutterError {
      _users.clear();
    }
  }
}

class AssetInfo {
  const AssetInfo({
    required this.uid,
    required this.name,
    required this.model,
    required this.serial,
    required this.vendor,
    required this.location,
  });

  final String uid;
  final String name;
  final String model;
  final String serial;
  final String vendor;
  final String location;
}

class UserInfo {
  const UserInfo({
    required this.id,
    required this.name,
    required this.department,
  });

  final String id;
  final String name;
  final String department;
}
