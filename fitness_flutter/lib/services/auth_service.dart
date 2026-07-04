import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Handles authentication state: login, register, token storage, auto-refresh.
/// When AUTH_ENABLED=false on backend, the app works without tokens.
class AuthService {
  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _userIdKey = 'auth_user_id';
  static const _emailKey = 'auth_email';

  static String? _accessToken;
  static String? _refreshToken;
  static int? _userId;
  static String? _email;
  static bool _authEnabled = false;
  static Future<bool>? _refreshFuture; // single-flight mutex

  static bool get isLoggedIn => _accessToken != null;
  static bool get authEnabled => _authEnabled;
  static int? get userId => _userId;
  static String? get email => _email;
  static String? get accessToken => _accessToken;

  /// Load persisted tokens on app start.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_accessTokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
    _userId = prefs.getInt(_userIdKey);
    _email = prefs.getString(_emailKey);

    // Check if backend has auth enabled — preserve last-known state on failure
    try {
      final resp = await ApiConfig.dio.get('/auth/status');
      _authEnabled = resp.data['auth_enabled'] ?? false;
    } catch (_) {
      // Preserve previous state (from tokens being present)
      _authEnabled = _accessToken != null;
    }
  }

  /// Register a new account.
  static Future<String?> register(String email, String password, {String? name}) async {
    try {
      final resp = await ApiConfig.dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        if (name != null) 'name': name,
      });
      await _saveTokens(resp.data);
      return null; // success
    } on DioException catch (e) {
      return e.response?.data?['detail'] ?? 'Registration failed';
    }
  }

  /// Login with email/password.
  static Future<String?> login(String email, String password) async {
    try {
      final resp = await ApiConfig.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      await _saveTokens(resp.data);
      return null; // success
    } on DioException catch (e) {
      return e.response?.data?['detail'] ?? 'Login failed';
    }
  }

  /// Refresh the access token using a bare Dio (no interceptors) to avoid recursion.
  static Future<bool> refreshTokens() {
    // Single-flight: if a refresh is already in progress, piggyback on it
    _refreshFuture ??= _doRefresh().whenComplete(() => _refreshFuture = null);
    return _refreshFuture!;
  }

  static Future<bool> _doRefresh() async {
    if (_refreshToken == null) return false;
    try {
      // Use a bare Dio instance without interceptors to avoid infinite 401 loop
      final bare = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ));
      final resp = await bare.post('/auth/refresh', data: {
        'refresh_token': _refreshToken,
      });
      await _saveTokens(resp.data);
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  /// Clear tokens and log out.
  static Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _email = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_emailKey);
  }

  static Future<void> _saveTokens(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    final uid = data['user_id'];
    final email = data['email'] as String?;

    if (access != null) {
      _accessToken = access;
      await prefs.setString(_accessTokenKey, access);
    }
    if (refresh != null) {
      _refreshToken = refresh;
      await prefs.setString(_refreshTokenKey, refresh);
    }
    if (uid != null) {
      _userId = (uid is int) ? uid : int.tryParse(uid.toString());
      if (_userId != null) await prefs.setInt(_userIdKey, _userId!);
    }
    if (email != null) {
      _email = email;
      await prefs.setString(_emailKey, email);
    }
  }
}
