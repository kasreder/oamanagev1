import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/asset_info.dart';
import '../models/inspection.dart';
import '../models/user_info.dart';

/// Simple REST API client for the OA Asset Manager backend.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.username = 'demo',
    this.password = 'demo',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String username;
  final String password;
  final http.Client _httpClient;
  String? _accessToken;
  DateTime? _tokenExpiry;

  Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse('$normalizedBase$path');
    if (query == null || query.isEmpty) {
      return uri;
    }
    final filtered = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null) continue;
      filtered[entry.key] = value.toString();
    }
    return uri.replace(queryParameters: filtered);
  }

  Map<String, String> _headers({bool includeJson = true}) {
    final headers = <String, String>{};
    if (includeJson) {
      headers['Content-Type'] = 'application/json';
    }
    final token = _accessToken;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<void> ensureAuthenticated() async {
    if (_accessToken != null && _tokenExpiry != null && _tokenExpiry!.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return;
    }
    await authenticate(username: username, password: password);
  }

  Future<void> authenticate({required String username, required String password}) async {
    final response = await _httpClient.post(
      _buildUri('/auth/token'),
      headers: _headers(),
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode != 200) {
      throw ApiException('Failed to authenticate (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = decoded['access_token'] as String?;
    final expiresIn = decoded['expires_in'] as int? ?? 3600;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
  }

  Future<List<Inspection>> fetchInspections({int pageSize = 200}) async {
    await ensureAuthenticated();
    final response = await _httpClient.get(
      _buildUri('/inspections', {'pageSize': pageSize}),
      headers: _headers(includeJson: false),
    );
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (decoded['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Inspection.fromJson)
        .toList();
    return items;
  }

  Future<Inspection> createInspection(Inspection inspection) async {
    await ensureAuthenticated();
    final response = await _httpClient.post(
      _buildUri('/inspections'),
      headers: _headers(),
      body: jsonEncode(inspection.toJson()),
    );
    _ensureSuccess(response, expected: 201);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return Inspection.fromJson(decoded);
  }

  Future<Inspection> updateInspection(Inspection inspection) async {
    await ensureAuthenticated();
    final response = await _httpClient.patch(
      _buildUri('/inspections/${inspection.id}'),
      headers: _headers(),
      body: jsonEncode({
        'status': inspection.status,
        'memo': inspection.memo,
        'scannedAt': inspection.scannedAt.toUtc().toIso8601String(),
        'synced': inspection.synced,
      }),
    );
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return Inspection.fromJson(decoded);
  }

  Future<void> deleteInspection(String id) async {
    await ensureAuthenticated();
    final response = await _httpClient.delete(
      _buildUri('/inspections/$id'),
      headers: _headers(includeJson: false),
    );
    if (response.statusCode == 404) {
      throw ApiException('Inspection not found');
    }
    if (response.statusCode != 204) {
      throw ApiException('Failed to delete inspection (${response.statusCode})');
    }
  }

  Future<List<AssetInfo>> fetchAssets({int pageSize = 500}) async {
    await ensureAuthenticated();
    final response = await _httpClient.get(
      _buildUri('/assets', {'pageSize': pageSize}),
      headers: _headers(includeJson: false),
    );
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (decoded['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(AssetInfo.fromJson)
        .toList();
    return items;
  }

  Future<AssetInfo?> fetchAsset(String uid) async {
    await ensureAuthenticated();
    final response = await _httpClient.get(
      _buildUri('/assets/$uid'),
      headers: _headers(includeJson: false),
    );
    if (response.statusCode == 404) {
      return null;
    }
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return AssetInfo.fromJson(decoded);
  }

  Future<void> upsertAsset(AssetInfo asset) async {
    await ensureAuthenticated();
    final response = await _httpClient.post(
      _buildUri('/assets'),
      headers: _headers(),
      body: jsonEncode(asset.toApiPayload()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException('Failed to save asset (${response.statusCode})');
    }
  }

  Future<List<UserInfo>> fetchUsers() async {
    await ensureAuthenticated();
    final response = await _httpClient.get(
      _buildUri('/references/users'),
      headers: _headers(includeJson: false),
    );
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (decoded['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(UserInfo.fromJson)
        .toList();
    return items;
  }

  Future<Map<String, dynamic>?> fetchVerificationDetail(String assetUid) async {
    await ensureAuthenticated();
    final response = await _httpClient.get(
      _buildUri('/verifications/$assetUid'),
      headers: _headers(includeJson: false),
    );
    if (response.statusCode == 404) {
      return null;
    }
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadSignature({
    required String assetUid,
    required Uint8List bytes,
    String? fileName,
    String? userId,
    String? userName,
  }) async {
    await ensureAuthenticated();
    final uri = _buildUri('/verifications/$assetUid/signatures');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers(includeJson: false));
    final resolvedFileName = fileName ?? 'signature-${DateTime.now().millisecondsSinceEpoch}.png';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: resolvedFileName,
        contentType: MediaType('image', 'png'),
      ),
    );
    if (userId != null) {
      request.fields['userId'] = userId;
    }
    if (userName != null) {
      request.fields['userName'] = userName;
    }
    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 201) {
      throw ApiException('Failed to upload signature (${response.statusCode})');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Uint8List?> downloadSignature(String assetUid) async {
    await ensureAuthenticated();
    final response = await _httpClient.get(
      _buildUri('/verifications/$assetUid/signatures'),
      headers: _headers(includeJson: false),
    );
    if (response.statusCode == 404) {
      return null;
    }
    _ensureSuccess(response);
    return response.bodyBytes;
  }

  void close() {
    _httpClient.close();
  }

  void _ensureSuccess(http.Response response, {int expected = 200}) {
    if (response.statusCode != expected) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      throw ApiException('Request failed (${response.statusCode}): ${response.body}');
    }
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => 'ApiException: $message';
}
