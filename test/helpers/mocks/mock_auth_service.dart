// ────────────────────────────────────────────────────────────────────────────
//  MOCK AUTH SERVICE
//
//  Мок для AuthService для использования в тестах
//  Использует mocktail для создания моков без code generation
// ────────────────────────────────────────────────────────────────────────────

import 'package:mocktail/mocktail.dart';
import 'package:paceup/core/services/auth_service.dart';

/// Мок для AuthService
class MockAuthService extends Mock implements AuthService {}

/// Расширения для настройки MockAuthService
extension MockAuthServiceExtensions on MockAuthService {
  /// Настраивает мок с предустановленными значениями
  void setupDefaults({
    String? accessToken,
    String? refreshToken,
    int? userId,
    bool isAuthorized = true,
  }) {
    // Настраиваем возвращаемые значения
    when(() => getAccessToken()).thenAnswer((_) async => accessToken ?? 'test_access_token');
    when(() => getRefreshToken()).thenAnswer((_) async => refreshToken ?? 'test_refresh_token');
    when(() => getUserId()).thenAnswer((_) async => userId ?? 1);
    when(() => this.isAuthorized()).thenAnswer((_) async => isAuthorized);
    when(() => this.refreshToken()).thenAnswer((_) async => isAuthorized);
    
    // Методы без возвращаемого значения
    when(() => saveTokens(any(), any(), any())).thenAnswer((_) async {});
    when(() => logout()).thenAnswer((_) async {});
  }

  /// Настраивает мок с неавторизованным пользователем
  void setupUnauthorized() {
    setupDefaults(
      accessToken: null,
      refreshToken: null,
      userId: null,
      isAuthorized: false,
    );
  }

  /// Настраивает мок с авторизованным пользователем
  void setupAuthorized({int userId = 1}) {
    setupDefaults(
      accessToken: 'test_access_token_$userId',
      refreshToken: 'test_refresh_token_$userId',
      userId: userId,
      isAuthorized: true,
    );
  }
}

/// Хелперы для создания MockAuthService
class MockAuthServiceFactory {
  /// Создаёт мок с предустановленными значениями
  static MockAuthService withDefaults({
    String? accessToken,
    String? refreshToken,
    int? userId,
    bool isAuthorized = true,
  }) {
    final mock = MockAuthService();
    mock.setupDefaults(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      isAuthorized: isAuthorized,
    );
    return mock;
  }

  /// Создаёт мок с неавторизованным пользователем
  static MockAuthService unauthorized() {
    final mock = MockAuthService();
    mock.setupUnauthorized();
    return mock;
  }

  /// Создаёт мок с авторизованным пользователем
  static MockAuthService authorized({int userId = 1}) {
    final mock = MockAuthService();
    mock.setupAuthorized(userId: userId);
    return mock;
  }
}
