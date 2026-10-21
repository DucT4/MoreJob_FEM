import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, this.status);
  final String message;
  final int status;
  @override
  String toString() => message;
}

class MoreJobApi {
  MoreJobApi({http.Client? client}) : _client = client ?? http.Client();
  static const _storage = FlutterSecureStorage();
  final http.Client _client;
  final String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api/v1',
  );
  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? user;

  Future<bool> restore() async {
    _accessToken = await _storage.read(key: 'access_token');
    _refreshToken = await _storage.read(key: 'refresh_token');
    if (_accessToken == null) return false;
    try {
      user = await get('/auth/me') as Map<String, dynamic>;
      if (user?['role'] != 'USER') {
        await logout();
        return false;
      }
      await post('/student-profiles/me/initialize', {});
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<void> login(String email, String password) async {
    final data = await post('/auth/login', {
      'email': email,
      'password': password,
    }, authenticated: false);
    await _saveSession(data as Map<String, dynamic>);
    await post('/student-profiles/me/initialize', {});
  }

  Future<void> register(String name, String email, String password) async {
    await post('/auth/register', {
      'fullName': name,
      'email': email,
      'password': password,
      'role': 'USER',
    }, authenticated: false);
    await login(email, password);
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final account = Map<String, dynamic>.from(data['user'] as Map);
    if (account['role'] != 'USER') {
      throw const ApiException('Ứng dụng này dành cho sinh viên.', 403);
    }
    _accessToken = data['accessToken'] as String?;
    _refreshToken = data['refreshToken'] as String?;
    user = account;
    await _storage.write(key: 'access_token', value: _accessToken);
    await _storage.write(key: 'refresh_token', value: _refreshToken);
  }

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    user = null;
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _request('GET', path, query: query);
  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) => _request('POST', path, body: body, authenticated: authenticated);
  Future<dynamic> patch(String path, Map<String, dynamic> body) =>
      _request('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _request('DELETE', path);

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode == 401 &&
        authenticated &&
        retry &&
        await _refresh()) {
      return _request(method, path, body: body, query: query, retry: false);
    }
    return _decode(response);
  }

  Future<bool> _refresh() async {
    if (_refreshToken == null) return false;
    try {
      final data = await post('/auth/refresh', {
        'refreshToken': _refreshToken,
      }, authenticated: false);
      await _saveSession(data as Map<String, dynamic>);
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  dynamic _decode(http.Response response) {
    Map<String, dynamic> json;
    try {
      json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Máy chủ trả dữ liệu không hợp lệ.',
        response.statusCode,
      );
    }
    if (response.statusCode >= 400 || json['success'] == false) {
      throw ApiException(
        (json['message'] ?? 'Yêu cầu thất bại.').toString(),
        response.statusCode,
      );
    }
    return json['data'];
  }

  Future<int> uploadCv(PlatformFile file, String title) async {
    if (file.extension?.toLowerCase() != 'pdf' || file.path == null) {
      throw const ApiException('Vui lòng chọn tệp PDF trên thiết bị.', 400);
    }
    Future<http.Response> send() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/students/me/cvs/upload-artifact'),
      );
      request.headers['Authorization'] = 'Bearer $_accessToken';
      request.fields['title'] = title;
      request.files.add(await http.MultipartFile.fromPath('file', file.path!));
      return http.Response.fromStream(await _client.send(request));
    }

    var response = await send();
    if (response.statusCode == 401 && await _refresh()) response = await send();
    final data = _decode(response) as Map<String, dynamic>;
    return (data['artifactId'] as num).toInt();
  }
}
