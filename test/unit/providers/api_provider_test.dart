// ────────────────────────────────────────────────────────────────────────────
//  UNIT TESTS: ApiProvider
//
//  Тесты для провайдера API сервиса:
//  • Создание провайдера
//  • Получение ApiService
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';

import 'package:paceup/providers/services/api_provider.dart';
import 'package:paceup/core/services/api_service.dart';
import '../../helpers/provider_helpers.dart';

void main() {
  group('apiServiceProvider', () {
    test('создаёт экземпляр ApiService', () {
      // Arrange
      final container = ProviderTestHelpers.createTestContainer();

      // Act
      final apiService = container.read(apiServiceProvider);

      // Assert
      expect(apiService, isA<ApiService>());

      container.dispose();
    });

    test('возвращает тот же экземпляр при повторном чтении', () {
      // Arrange
      final container = ProviderTestHelpers.createTestContainer();

      // Act
      final apiService1 = container.read(apiServiceProvider);
      final apiService2 = container.read(apiServiceProvider);

      // Assert
      expect(apiService1, same(apiService2));

      container.dispose();
    });

    test('провайдер доступен через container', () {
      // Arrange
      final container = ProviderTestHelpers.createTestContainer();

      // Act & Assert
      expect(() => container.read(apiServiceProvider), returnsNormally);

      container.dispose();
    });
  });
}
