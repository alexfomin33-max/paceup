// ────────────────────────────────────────────────────────────────────────────
//  UNIT TESTS: AuthProvider
//
//  Тесты для провайдера авторизации:
//  • Создание провайдера
//  • Получение AuthService
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paceup/providers/services/auth_provider.dart';
import 'package:paceup/core/services/auth_service.dart';
import '../../helpers/provider_helpers.dart';

void main() {
  group('authServiceProvider', () {
    test('создаёт экземпляр AuthService', () {
      // Arrange
      final container = ProviderTestHelpers.createTestContainer();

      // Act
      final authService = container.read(authServiceProvider);

      // Assert
      expect(authService, isA<AuthService>());

      container.dispose();
    });

    test('возвращает тот же экземпляр при повторном чтении', () {
      // Arrange
      final container = ProviderTestHelpers.createTestContainer();

      // Act
      final authService1 = container.read(authServiceProvider);
      final authService2 = container.read(authServiceProvider);

      // Assert
      expect(authService1, same(authService2));

      container.dispose();
    });

    test('провайдер доступен через container', () {
      // Arrange
      final container = ProviderTestHelpers.createTestContainer();

      // Act & Assert
      expect(() => container.read(authServiceProvider), returnsNormally);

      container.dispose();
    });
  });
}
