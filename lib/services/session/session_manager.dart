import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Session lifecycle states for account authentication.
enum SessionStatus { unknown, loggedOut, loggedIn }

class LoginResult {
  final bool success;
  final String message;

  const LoginResult({required this.success, required this.message});
}

/// Handles xc_session cookie persistence and sync secret caching.
class SessionManager {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  static const _prefsBaseUrlKey = 'session.baseUrl';
  static const _prefsCookieKey = 'session.cookie';
  static const _prefsSecretKey = 'session.syncSecret';
  static const _prefsUserKey = 'session.username';

  final ValueNotifier<SessionStatus> status =
      ValueNotifier<SessionStatus>(SessionStatus.unknown);
  final ValueNotifier<String?> currentUser = ValueNotifier<String?>(null);
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);
  final ValueNotifier<bool> loading = ValueNotifier<bool>(false);
  final ValueNotifier<String> baseUrl =
      ValueNotifier<String>('https://account.svc.plus');

  String? _cookie;
  Uint8List? _syncSecret;

  bool get isLoggedIn => status.value == SessionStatus.loggedIn;
  Uint8List? get syncSecret => _syncSecret;
  String? get cookie => _cookie;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final storedBaseUrl = prefs.getString(_prefsBaseUrlKey);
    if (storedBaseUrl != null && storedBaseUrl.isNotEmpty) {
      baseUrl.value = storedBaseUrl;
    }

    final storedCookie = prefs.getString(_prefsCookieKey);
    final storedSecret = prefs.getString(_prefsSecretKey);
    final username = prefs.getString(_prefsUserKey);

    if (storedCookie != null && storedSecret != null) {
      try {
        _syncSecret = base64Decode(storedSecret);
        _cookie = storedCookie;
        currentUser.value = username;
        status.value = SessionStatus.loggedIn;
      } catch (_) {
        await _clearPrefs();
        status.value = SessionStatus.loggedOut;
      }
    } else {
      status.value = SessionStatus.loggedOut;
    }
  }

  Future<void> setBaseUrl(String url) async {
    final normalized = _normalizeBaseUrl(url);
    baseUrl.value = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsBaseUrlKey, normalized);
  }

  String _normalizeBaseUrl(String url) {
    var value = url.trim();
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    return value;
  }

  Uri buildEndpoint(String path) {
    final root = baseUrl.value;
    return Uri.parse('$root$path');
  }

  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    loading.value = true;
    lastError.value = null;
    try {
      final response = await http.post(
        buildEndpoint('/api/auth/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode >= 500) {
        lastError.value = '服务器错误 (${response.statusCode})';
        return LoginResult(success: false, message: lastError.value!);
      }

      if (response.statusCode == 404) {
        lastError.value = '登录接口未启用，请确认部署配置。';
        return LoginResult(success: false, message: lastError.value!);
      }

      final Map<String, dynamic> payload = _parseBody(response.body);
      final success = payload['success'] == true || response.statusCode == 200;
      if (!success) {
        final message = payload['message'] as String? ?? '账号或密码错误';
        lastError.value = message;
        return LoginResult(success: false, message: message);
      }

      final syncSecret = _extractSyncSecret(payload);
      if (syncSecret == null) {
        lastError.value = '缺少同步密钥，无法完成登录';
        return LoginResult(success: false, message: lastError.value!);
      }

      final cookie = _extractSessionCookie(response.headers);
      if (cookie == null) {
        lastError.value = '未返回会话 Cookie';
        return LoginResult(success: false, message: lastError.value!);
      }

      _syncSecret = syncSecret;
      _cookie = cookie;
      currentUser.value = username;
      status.value = SessionStatus.loggedIn;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsCookieKey, cookie);
      await prefs.setString(_prefsSecretKey, base64Encode(syncSecret));
      await prefs.setString(_prefsUserKey, username);

      return const LoginResult(success: true, message: '登录成功');
    } catch (e) {
      final message = '登录失败: $e';
      lastError.value = message;
      return LoginResult(success: false, message: message);
    } finally {
      loading.value = false;
    }
  }

  Future<void> logout() async {
    _cookie = null;
    _syncSecret = null;
    currentUser.value = null;
    status.value = SessionStatus.loggedOut;
    lastError.value = null;
    await _clearPrefs();
  }

  Future<void> _clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsCookieKey);
    await prefs.remove(_prefsSecretKey);
    await prefs.remove(_prefsUserKey);
  }

  Map<String, dynamic> _parseBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Uint8List? _extractSyncSecret(Map<String, dynamic> payload) {
    dynamic candidate;
    if (payload.containsKey('syncSecret')) {
      candidate = payload['syncSecret'];
    } else if (payload['data'] is Map<String, dynamic>) {
      final data = payload['data'] as Map<String, dynamic>;
      candidate = data['syncSecret'];
    }
    if (candidate is String && candidate.isNotEmpty) {
      try {
        return base64Decode(candidate);
      } catch (_) {
        // Some deployments may store plain hex or uuid, fall back to utf8.
        return Uint8List.fromList(candidate.codeUnits);
      }
    }
    return null;
  }

  String? _extractSessionCookie(Map<String, String> headers) {
    final setCookie = headers['set-cookie'];
    if (setCookie == null) return null;

    final cookies = setCookie.split(',');
    for (final cookie in cookies) {
      final match = RegExp(r'xc_session=([^;]+)').firstMatch(cookie);
      if (match != null) {
        return 'xc_session=${match.group(1)}';
      }
    }
    return null;
  }
}
