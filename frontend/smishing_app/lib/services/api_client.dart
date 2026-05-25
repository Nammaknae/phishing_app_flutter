import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_storage.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// 공통 HTTP 클라이언트 — 인증이 필요한 요청에 Bearer 토큰을 자동 첨부합니다.
class ApiClient {
  static Uri _uri(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${ApiConfig.baseUrl}$normalized');
  }

  static Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (withAuth) {
      final token = await TokenStorage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static String _extractMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final message = body['message'];
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {}
    return response.body.isNotEmpty ? response.body : 'Request failed';
  }

  static Future<Map<String, dynamic>> get(
    String path, {
    bool withAuth = true,
  }) async {
    final response = await http.get(
      _uri(path),
      headers: await _headers(withAuth: withAuth),
    );
    return _parseJsonResponse(response);
  }

  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool withAuth = true,
  }) async {
    final response = await http.post(
      _uri(path),
      headers: await _headers(withAuth: withAuth),
      body: body == null ? null : jsonEncode(body),
    );
    return _parseJsonResponse(response);
  }
  static Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool withAuth = true,
  }) async {
    final response = await http.patch(
      _uri(path),
      headers: await _headers(withAuth: withAuth),
      body: body == null ? null : jsonEncode(body),
    );
    return _parseJsonResponse(response);
  }
  static Future<Map<String, dynamic>> delete(
    String path, {
    bool withAuth = true,
  }) async {
    final response = await http.delete(
      _uri(path),
      headers: await _headers(withAuth: withAuth),
    );
    return _parseJsonResponse(response);
  }

  static Map<String, dynamic> _parseJsonResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{'data': decoded};
    }

    throw ApiException(response.statusCode, _extractMessage(response));
  }
}
