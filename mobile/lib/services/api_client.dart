import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  ApiException(this.statusCode, this.code, this.message);

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

class ApiClient {
  // Host del backend. 'origin' sirve para construir URLs de imágenes (/uploads/...).
  static const String origin = 'http://localhost:3000';
  static const String _baseUrl = '$origin/api/v1';

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

  // Subida de archivos (multipart). No lleva Content-Type manual:
  // MultipartRequest pone el suyo con el 'boundary' correcto.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required List<int> bytes,
    required String filename,
    required String field,
    String? contentType,
    Map<String, String>? fields,
    bool auth = false,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');

    Future<http.Response> doRequest() async {
      final req = http.MultipartRequest('POST', uri);
      if (auth && _accessToken != null) {
        req.headers['Authorization'] = 'Bearer $_accessToken';
      }
      fields?.forEach((k, v) => req.fields[k] = v);
      req.files.add(
        http.MultipartFile.fromBytes(
          field,
          bytes,
          filename: filename,
          // Etiqueta el tipo (p.ej. image/jpeg) para que el backend no lo rechace.
          contentType: contentType != null ? MediaType.parse(contentType) : null,
        ),
      );
      final streamed = await req.send();
      return http.Response.fromStream(streamed);
    }

    final res = await doRequest();
    if (res.statusCode == 401 && auth && refreshAccessToken != null) {
      final newToken = await refreshAccessToken!();
      if (newToken != null) {
        setAccessToken(newToken);
        return _handleResponse(await doRequest());
      }
    }
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
    return _requestWithRetry(
      () => http.get(uri, headers: _headers(auth: auth)),
      auth: auth,
    );
  }

Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final res = await http.patch(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    return _handleResponse(res);
  }

  Future<void> delete(String path, {bool auth = false}) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(auth: auth),
    );
    if (res.statusCode == 204) return;
    await _handleResponse(res);
  }

}
