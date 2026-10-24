import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, this.status, {this.code});
  final String message;
  final int status;
  final String? code;
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

  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null && user != null;
  String get role => (user?['role'] ?? 'USER').toString();
  bool get isAdmin => role == 'ADMIN';
  bool get isStudent => role == 'USER';

  String get originUrl {
    final uri = Uri.parse(baseUrl);
    return '${uri.scheme}://${uri.authority}';
  }

  Future<bool> restore() async {
    _accessToken = await _storage.read(key: 'access_token');
    _refreshToken = await _storage.read(key: 'refresh_token');
    if (_accessToken == null) return false;
    try {
      user = await get('/auth/me') as Map<String, dynamic>;
      final userRole = user?['role']?.toString();
      if (userRole != 'USER' && userRole != 'ADMIN') {
        await logout();
        return false;
      }
      if (userRole == 'USER') {
        try {
          await post('/student-profiles/me/initialize', body: {});
        } catch (_) {}
      }
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  static List<Map<String, dynamic>> pageItems(dynamic data) {
    if (data is Map && data['content'] is List) {
      return (data['content'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    if (data is List) {
      return data
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> login(String email, String password) async {
    final data = await _request(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
      authenticated: false,
    );
    await _saveSession(data as Map<String, dynamic>);
    if (isStudent) {
      try {
        await post('/student-profiles/me/initialize', body: {});
      } catch (_) {}
    }
  }

  Future<void> register(String name, String email, String password) async {
    await _request(
      'POST',
      '/auth/register',
      body: {
        'fullName': name,
        'email': email,
        'password': password,
        'role': 'USER',
      },
      authenticated: false,
    );
    await login(email, password);
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final account = Map<String, dynamic>.from(data['user'] as Map);
    final accountRole = account['role']?.toString();
    if (accountRole != 'USER' && accountRole != 'ADMIN') {
      throw const ApiException(
        'MoreJob hiện chỉ hỗ trợ ứng viên và quản trị viên.',
        403,
      );
    }
    _accessToken = data['accessToken'] as String?;
    _refreshToken = data['refreshToken'] as String?;
    user = account;
    await _storage.write(key: 'access_token', value: _accessToken);
    await _storage.write(key: 'refresh_token', value: _refreshToken);
  }

  Future<void> logout() async {
    if (_accessToken != null) {
      try {
        await post('/auth/logout', body: {});
      } catch (_) {}
    }
    _accessToken = null;
    _refreshToken = null;
    user = null;
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) => _request('GET', path, query: query, authenticated: authenticated);

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) => _request(
    'POST',
    path,
    body: body,
    query: query,
    authenticated: authenticated,
  );

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) => _request(
    'PUT',
    path,
    body: body,
    query: query,
    authenticated: authenticated,
  );

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) => _request(
    'PATCH',
    path,
    body: body,
    query: query,
    authenticated: authenticated,
  );

  Future<dynamic> delete(String path, {bool authenticated = true}) =>
      _request('DELETE', path, authenticated: authenticated);

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    final fullUrl = path.startsWith('http://') || path.startsWith('https://')
        ? path
        : path.startsWith('/api/')
        ? '$originUrl$path'
        : '$baseUrl$path';
    final filteredQuery = query == null
        ? null
        : Map<String, String>.fromEntries(
            query.entries.where((e) => e.value.isNotEmpty),
          );
    final uri = Uri.parse(fullUrl).replace(
      queryParameters:
          filteredQuery != null && filteredQuery.isNotEmpty
          ? filteredQuery
          : null,
    );
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
      return _request(
        method,
        path,
        body: body,
        query: query,
        authenticated: authenticated,
        retry: false,
      );
    }
    return _decode(response);
  }

  Future<bool> _refresh() async {
    if (_refreshToken == null) return false;
    try {
      final data = await _request(
        'POST',
        '/auth/refresh',
        body: {'refreshToken': _refreshToken},
        authenticated: false,
      );
      await _saveSession(data as Map<String, dynamic>);
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode == 204 || response.bodyBytes.isEmpty) {
      return null;
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ApiException(
        'Máy chủ trả dữ liệu không hợp lệ.',
        response.statusCode,
      );
    }
    if (decoded is Map<String, dynamic>) {
      if (response.statusCode >= 400 || decoded['success'] == false) {
        throw ApiException(
          (decoded['message'] ?? 'Yêu cầu thất bại.').toString(),
          response.statusCode,
          code: decoded['code']?.toString(),
        );
      }
      if (decoded.containsKey('success') && decoded.containsKey('data')) {
        return decoded['data'];
      }
      return decoded;
    }
    if (response.statusCode >= 400) {
      throw ApiException('Yêu cầu thất bại.', response.statusCode);
    }
    return decoded;
  }

  Future<dynamic> uploadMultipart(
    String path, {
    required String fileField,
    required PlatformFile file,
    Map<String, String> fields = const {},
  }) async {
    if (file.path == null) {
      throw const ApiException('Không đọc được tệp trên thiết bị.', 400);
    }
    Future<http.Response> send() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$path'),
      );
      if (_accessToken != null) {
        request.headers['Authorization'] = 'Bearer $_accessToken';
      }
      request.fields.addAll(fields);
      request.files.add(
        await http.MultipartFile.fromPath(
          fileField,
          file.path!,
          filename: file.name,
        ),
      );
      return http.Response.fromStream(await _client.send(request));
    }

    var response = await send();
    if (response.statusCode == 401 && await _refresh()) {
      response = await send();
    }
    return _decode(response);
  }

  Future<int> uploadCv(
    PlatformFile file,
    String title, {
    String? summary,
    bool defaultCv = false,
  }) async {
    final result = await uploadCvArtifact(
      file,
      title,
      summary: summary,
      defaultCv: defaultCv,
    );
    return (result['artifactId'] as num).toInt();
  }

  Future<Map<String, dynamic>> uploadCvArtifact(
    PlatformFile file,
    String title, {
    String? summary,
    bool defaultCv = false,
  }) async {
    if (file.extension?.toLowerCase() != 'pdf' &&
        !file.name.toLowerCase().endsWith('.pdf')) {
      throw const ApiException('Vui lòng chọn tệp PDF trên thiết bị.', 400);
    }
    final fields = <String, String>{
      'title': title,
      'defaultCv': defaultCv.toString(),
    };
    if (summary != null && summary.trim().isNotEmpty) {
      fields['summary'] = summary.trim();
    }
    final data = await uploadMultipart(
      '/students/me/cvs/upload-artifact',
      fileField: 'file',
      file: file,
      fields: fields,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<String> uploadAvatar(PlatformFile file) async {
    final ext = (file.extension ?? '').toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      throw const ApiException(
        'Chỉ hỗ trợ ảnh JPG, PNG hoặc WEBP tối đa 5MB.',
        400,
      );
    }
    final data = await uploadMultipart(
      '/uploads/avatars',
      fileField: 'file',
      file: file,
    ) as Map<String, dynamic>;
    final rawUrl = (data['url'] ?? '').toString();
    if (rawUrl.isEmpty) {
      throw const ApiException('Máy chủ chưa trả về đường dẫn ảnh.', 500);
    }
    return resolveImageUrl(rawUrl);
  }

  String resolveImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$originUrl${url.startsWith('/') ? '' : '/'}$url';
  }

  Future<Map<String, dynamic>> sendConversationAttachment({
    required int conversationId,
    required String clientMessageId,
    required PlatformFile file,
  }) async {
    final data = await uploadMultipart(
      '/conversations/$conversationId/attachments',
      fileField: 'file',
      file: file,
      fields: {'clientMessageId': clientMessageId},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> inspectAdminCvTemplate(PlatformFile file) async {
    final data = await uploadMultipart(
      '/admin/cv-templates/pdf/inspect',
      fileField: 'referenceFile',
      file: file,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> createAdminPdfTemplate({
    required String displayName,
    String? templateKey,
    String? description,
    String? category,
    String? tags,
    bool featured = false,
    bool popular = false,
    int sortOrder = 0,
    required PlatformFile referenceFile,
  }) async {
    final fields = <String, String>{
      'displayName': displayName,
      'featured': featured.toString(),
      'popular': popular.toString(),
      'sortOrder': sortOrder.toString(),
    };
    if (templateKey != null && templateKey.trim().isNotEmpty) {
      fields['templateKey'] = templateKey.trim();
    }
    if (description != null && description.trim().isNotEmpty) {
      fields['description'] = description.trim();
    }
    if (category != null && category.trim().isNotEmpty) {
      fields['category'] = category.trim();
    }
    if (tags != null && tags.trim().isNotEmpty) {
      fields['tags'] = tags.trim();
    }
    final data = await uploadMultipart(
      '/admin/cv-templates/pdf',
      fileField: 'referenceFile',
      file: referenceFile,
      fields: fields,
    );
    return Map<String, dynamic>.from(data as Map);
  }
}

List<Map<String, dynamic>> pageItems(dynamic data) {
  if (data is Map && data['content'] is List) {
    return (data['content'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }
  if (data is List) {
    return data
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }
  return <Map<String, dynamic>>[];
}
