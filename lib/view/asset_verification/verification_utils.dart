// lib/view/asset_verification/verification_utils.dart

import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/inspection.dart';
import '../../providers/inspection_provider.dart';

String normalizeTeamName(String? team) {
  final name = team?.trim();
  if (name == null || name.isEmpty) {
    return '미지정 팀';
  }
  return name;
}

String resolveTeamName(Inspection? inspection, AssetInfo? asset) {
  final assetOrganization = (asset?.organization ?? '').trim();
  if (assetOrganization.isNotEmpty) {
    return normalizeTeamName(assetOrganization);
  }

  final inspectionTeam = inspection?.userTeam?.trim() ?? '';
  if (inspectionTeam.isNotEmpty) {
    return normalizeTeamName(inspectionTeam);
  }

  final metadataTeam = asset?.metadata['organization_team']?.trim() ?? '';
  return normalizeTeamName(metadataTeam);
}

UserInfo? resolveUser(
  InspectionProvider provider,
  Inspection? inspection,
  AssetInfo? asset,
) {
  final lookupCandidates = <String?>[
    inspection?.userId,
    asset?.metadata['user_id'],
    asset?.metadata['employee_id'],
  ];
  for (final id in lookupCandidates) {
    if (id == null) continue;
    final user = provider.userOf(id);
    if (user != null) {
      return user;
    }
  }

  if (asset == null) {
    return null;
  }

  final fallbackName = _firstNonEmpty(_assetLinkedUserNames(asset));
  if (fallbackName == null) {
    return null;
  }

  final fallbackId =
      _firstNonEmpty(<String?>[
            inspection?.userId,
            asset.metadata['user_id'],
            asset.metadata['employee_id'],
            asset.metadata['id'],
            asset.uid,
          ]) ??
          _normalizeOrNull(asset.uid);

  if (fallbackId == null) {
    return null;
  }

  final department = _firstNonEmpty(<String?>[
        asset.organization,
        inspection?.userTeam,
        asset.metadata['organization_team'],
        asset.metadata['team_name'],
      ]) ??
      '';

  return UserInfo(
    id: fallbackId,
    name: fallbackName,
    department: department,
  );
}

String resolveUserNameLabel(UserInfo? user, AssetInfo? asset) {
  final resolvedUserName = _normalizeOrNull(user?.name);
  if (resolvedUserName != null) {
    return resolvedUserName;
  }

  if (asset == null) {
    return '';
  }

  return _firstNonEmpty(_assetLinkedUserNames(asset)) ?? '';
}

String resolveAssetType(Inspection? inspection, AssetInfo? asset) {
  final fromInspection = inspection?.assetType?.trim();
  if (fromInspection != null && fromInspection.isNotEmpty) {
    return fromInspection;
  }
  final fromAsset = asset?.assets_types.trim();
  if (fromAsset != null && fromAsset.isNotEmpty) {
    return fromAsset;
  }
  return '';
}

String resolveManager(AssetInfo? asset) {
  final manager = asset?.metadata['member_name']?.trim();
  if (manager == null || manager.isEmpty) {
    return '';
  }
  return manager;
}

String resolveLocation(AssetInfo? asset) {
  if (asset == null) return '';
  final parts = <String?>[
    asset.metadata['building1'],
    asset.metadata['building'],
    asset.metadata['floor'],
  ].whereType<String>().map((value) => value.trim()).where((value) => value.isNotEmpty);
  final joined = parts.join(' ');
  if (joined.isNotEmpty) {
    return joined;
  }
  return asset.location.trim();
}

class BarcodePhotoRegistry {
  static Map<String, String>? _cachedPaths;

  static Future<Set<String>> loadCodes() async {
    final paths = await _loadPaths();
    return paths.keys.toSet();
  }

  static Future<String?> pathFor(String assetCode) async {
    final paths = await _loadPaths();
    final normalized = _normalize(assetCode);
    if (normalized.isEmpty) {
      return null;
    }
    return paths[normalized];
  }

  static Future<Map<String, String>> loadAllPaths() async {
    final paths = await _loadPaths();
    return Map.unmodifiable(paths);
  }

  static Future<bool> hasPhoto(String assetCode) async {
    final paths = await _loadPaths();
    final normalized = _normalize(assetCode);
    if (normalized.isEmpty) {
      return false;
    }
    return paths.containsKey(normalized);
  }

  static Future<Map<String, String>> _loadPaths() async {
    if (_cachedPaths != null) {
      return _cachedPaths!;
    }

    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent) as Map<String, dynamic>;

    final paths = <String, String>{};

    for (final key in manifestMap.keys) {
      if (!key.startsWith('assets/dummy/images/')) {
        continue;
      }
      final fileName = key.split('/').last;
      final dotIndex = fileName.lastIndexOf('.');
      final baseName = dotIndex == -1 ? fileName : fileName.substring(0, dotIndex);
      final normalized = _normalize(baseName);
      if (normalized.isEmpty) {
        continue;
      }
      paths[normalized] = key;
    }

    _cachedPaths = paths;
    return _cachedPaths!;
  }

  static String _normalize(String input) => input.trim().toLowerCase();
}

Iterable<String?> _assetLinkedUserNames(AssetInfo asset) {
  return <String?>[
    asset.name,
    asset.metadata['name'],
    asset.metadata['employee_name'],
    asset.metadata['member_name'],
    asset.metadata['user_name'],
    asset.metadata['user'],
    asset.metadata['owner_name'],
    asset.metadata['owner'],
    asset.metadata['manager_name'],
  ];
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final normalized = _normalizeOrNull(value);
    if (normalized != null) {
      return normalized;
    }
  }
  return null;
}

String? _normalizeOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
