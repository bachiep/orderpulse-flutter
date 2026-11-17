import 'package:equatable/equatable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Immutable JWT token pair managed by [TokenStorage] and [AuthInterceptor].
class AuthTokens extends Equatable {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.expiresAt,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final expiresRaw = json['expiresAt'] as String?;
    return AuthTokens(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresAt: expiresRaw != null ? DateTime.tryParse(expiresRaw) : null,
    );
  }

  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      };

  @override
  List<Object?> get props => [accessToken, refreshToken, expiresAt];
}

/// Abstract persistence boundary for sensitive JWT credentials.
abstract interface class TokenStorage {
  Future<AuthTokens?> readTokens();
  Future<void> saveTokens(AuthTokens tokens);
  Future<void> clearTokens();
}

/// Production token storage backed by platform Keychain/Keystore via [FlutterSecureStorage].
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'orderpulse_access_token';
  static const _refreshKey = 'orderpulse_refresh_token';
  static const _expiresKey = 'orderpulse_expires_at';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokens?> readTokens() async {
    final accessToken = await _storage.read(key: _accessKey);
    final refreshToken = await _storage.read(key: _refreshKey);
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return null;
    }
    final expiresRaw = await _storage.read(key: _expiresKey);
    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresRaw != null ? DateTime.tryParse(expiresRaw) : null,
    );
  }

  @override
  Future<void> saveTokens(AuthTokens tokens) async {
    await Future.wait([
      _storage.write(key: _accessKey, value: tokens.accessToken),
      _storage.write(key: _refreshKey, value: tokens.refreshToken),
      if (tokens.expiresAt != null)
        _storage.write(
          key: _expiresKey,
          value: tokens.expiresAt!.toIso8601String(),
        )
      else
        _storage.delete(key: _expiresKey),
    ]);
  }

  @override
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
      _storage.delete(key: _expiresKey),
    ]);
  }
}

/// In-memory token storage for standalone demo sessions and automated tests.
class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage({AuthTokens? initialTokens}) : _tokens = initialTokens;

  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> readTokens() async => _tokens;

  @override
  Future<void> saveTokens(AuthTokens tokens) async {
    _tokens = tokens;
  }

  @override
  Future<void> clearTokens() async {
    _tokens = null;
  }
}
