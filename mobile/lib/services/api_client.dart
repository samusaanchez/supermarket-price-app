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

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = false,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
    );
    final res = await http.get(uri, headers: _headers(auth: auth));
    return _handleResponse(res);
  }
}
