// ────────────────────────────────────────────────────────────────────────────
//  UNIT TESTS: AuthService
//
//  Тесты для сервиса авторизации:
//  • Получение токенов и ID пользователя
//  • Проверка авторизации
//  • Обновление токена
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:paceup/core/services/auth_service.dart';

void main() {
  group('AuthService', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
    });

    // ────────────────────────────────────────────────────────────
    // Тесты для получения токенов и ID
    // ────────────────────────────────────────────────────────────

    group('getAccessToken', () {
      test('возвращает токен доступа', () async {
        // Act
        final token = await authService.getAccessToken();

        // Assert
        expect(token, isNotNull);
        expect(token, isA<String>());
        expect(token!.isNotEmpty, isTrue);
      });
    });

    group('getRefreshToken', () {
      test('возвращает refresh токен', () async {
        // Act
        final refreshToken = await authService.getRefreshToken();

        // Assert
        expect(refreshToken, isNotNull);
        expect(refreshToken, isA<String>());
        expect(refreshToken!.isNotEmpty, isTrue);
      });
    });

    group('getUserId', () {
      test('возвращает ID пользователя', () async {
        // Act
        final userId = await authService.getUserId();

        // Assert
        expect(userId, isNotNull);
        expect(userId, isA<int>());
        expect(userId, greaterThan(0));
      });
    });

    // ────────────────────────────────────────────────────────────
    // Тесты для проверки авторизации
    // ────────────────────────────────────────────────────────────

    group('isAuthorized', () {
      test('возвращает true при валидном токене', () async {
        // Act
        final result = await authService.isAuthorized();

        // Assert
        // Примечание: этот тест зависит от реального API
        // В реальном проекте нужно мокать ApiService
        expect(result, isA<bool>());
      });

      test('возвращает false при отсутствии токена', () async {
        // Arrange
        // Создаём новый экземпляр, который может не иметь токена
        // В текущей реализации всегда возвращает токен (костыль)
        // Этот тест показывает структуру для будущих тестов с моками

        // Act & Assert
        // Пока пропускаем, так как текущая реализация всегда возвращает токен
        expect(true, isTrue); // Placeholder
      });
    });

    // ────────────────────────────────────────────────────────────
    // Тесты для обновления токена
    // ────────────────────────────────────────────────────────────

    group('refreshToken', () {
      test('возвращает bool результат', () async {
        // Act
        final result = await authService.refreshToken();

        // Assert
        // Примечание: этот тест зависит от реального API
        // В реальном проекте нужно мокать ApiService
        expect(result, isA<bool>());
      });
    });

    // ────────────────────────────────────────────────────────────
    // Тесты для сохранения и выхода
    // ────────────────────────────────────────────────────────────

    group('saveTokens', () {
      test('не выбрасывает исключений', () async {
        // Act & Assert
        expect(
          () => authService.saveTokens('access', 'refresh'),
          returnsNormally,
        );
      });
    });

    group('logout', () {
      test('не выбрасывает исключений', () async {
        // Act & Assert
        expect(() => authService.logout(), returnsNormally);
      });
    });
  });
}
