import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  ApiException(this.statusCode, this.code, this.message);

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

class ApiClient {
  static const String _baseUrl = 'http://localhost:3000/api/v1';

  String? _accessToken;
  Future<String?> Function()? refreshAccessToken;

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  Map<String, String> _headers({bool auth = false}) {
    final headers = {'Content-Type': 'application/json'};
    if (auth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response res) async {
    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }

    final err = body['error'] as Map<String, dynamic>?;
    throw ApiException(
      res.statusCode,
      err?['code'] as String? ?? 'ERROR_DESCONOCIDO',
      err?['message'] as String? ?? 'Error sin mensaje',
    );
  }

  Future<Map<String, dynamic>> _requestWithRetry(
    Future<http.Response> Function() request, {
    bool auth = false,
  }) async {
    final res = await request();

    if (res.statusCode == 401 && auth && refreshAccessToken != null) {
      final newToken = await refreshAccessToken!();
      if (newToken != null) {
        setAccessToken(newToken);
        final retryRes = await request();
        return _handleResponse(retryRes);
      }
    }

    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    return _requestWithRetry(
      () => http.post(
        Uri.parse('$_baseUrl$path'),
        headers: _headers(auth: auth),
        body: body == null ? null : jsonEncode(body),
      ),
      auth: auth,
    );
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = false,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
    );
    return _requestWithRetry(
      () => http.get(uri, headers: _headers(auth: auth)),
      auth: auth,
    );
  }
}
