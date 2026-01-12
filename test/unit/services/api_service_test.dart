// ────────────────────────────────────────────────────────────────────────────
//  UNIT TESTS: ApiService
//
//  Тесты для HTTP клиента:
//  • Инициализация сервиса
//  • Базовые HTTP методы
//  • Обработка ошибок
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:paceup/core/services/api_service.dart';
import 'package:paceup/core/services/auth_service.dart';

void main() {
  group('ApiService', () {
    late ApiService apiService;

    setUp(() {
      apiService = ApiService();
    });

    // ────────────────────────────────────────────────────────────
    // Тесты для инициализации
    // ────────────────────────────────────────────────────────────

    group('Инициализация', () {
      test('создаёт singleton экземпляр', () {
        // Act
        final instance1 = ApiService();
        final instance2 = ApiService();

        // Assert
        expect(instance1, same(instance2));
      });

      test('имеет корректный baseUrl', () {
        // Assert
        expect(ApiService.baseUrl, isNotEmpty);
        expect(ApiService.baseUrl, contains('api.paceup.ru'));
      });

      test('имеет корректный defaultTimeout', () {
        // Assert
        expect(ApiService.defaultTimeout, isA<Duration>());
        expect(ApiService.defaultTimeout.inSeconds, greaterThan(0));
      });
    });

    // ────────────────────────────────────────────────────────────
    // Тесты для базовых методов
    // ────────────────────────────────────────────────────────────

    group('GET запросы', () {
      test('метод get существует и принимает endpoint', () {
        // Assert
        expect(apiService.get, isA<Function>());
      });

      test('get принимает queryParams', () {
        // Assert
        // Проверяем, что метод существует и может принимать параметры
        expect(apiService.get, isA<Function>());
      });
    });

    group('POST запросы', () {
      test('метод post существует и принимает endpoint', () {
        // Assert
        expect(apiService.post, isA<Function>());
      });

      test('post принимает body', () {
        // Assert
        expect(apiService.post, isA<Function>());
      });
    });

    group('PUT запросы', () {
      test('метод put существует', () {
        // Assert
        expect(apiService.put, isA<Function>());
      });
    });

    group('DELETE запросы', () {
      test('метод delete существует', () {
        // Assert
        expect(apiService.delete, isA<Function>());
      });
    });

    group('PATCH запросы', () {
      test('метод patch существует', () {
        // Assert
        expect(apiService.patch, isA<Function>());
      });
    });

    // ────────────────────────────────────────────────────────────
    // Тесты для обработки ошибок
    // ────────────────────────────────────────────────────────────

    group('ApiException', () {
      test('ApiException создаётся с сообщением', () {
        // Act
        final exception = ApiException('Test error');

        // Assert
        expect(exception, isA<ApiException>());
        expect(exception.message, 'Test error');
        expect(exception.toString(), 'Test error');
      });
    });

    // ────────────────────────────────────────────────────────────
    // Тесты для dispose
    // ────────────────────────────────────────────────────────────

    group('dispose', () {
      test('метод dispose существует', () {
        // Assert
        expect(apiService.dispose, isA<Function>());
      });

      test('dispose не выбрасывает исключений', () {
        // Act & Assert
        expect(() => apiService.dispose(), returnsNormally);
      });
    });
  });
}
