// ────────────────────────────────────────────────────────────────────────────
//  PROVIDER TEST HELPERS
//
//  Утилиты для тестирования Riverpod провайдеров:
//  • Создание ProviderContainer с моками
//  • Переопределение провайдеров для тестов
//  • Хелперы для проверки состояний AsyncValue
// ────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Хелперы для тестирования Riverpod провайдеров
class ProviderTestHelpers {
  /// Создаёт ProviderContainer с переопределёнными провайдерами
  ///
  /// Использование:
  /// ```dart
  /// final container = createTestContainer(
  ///   overrides: [
  ///     apiServiceProvider.overrideWithValue(mockApiService),
  ///   ],
  /// );
  /// ```
  static ProviderContainer createTestContainer({
    List<Override> overrides = const [],
  }) {
    return ProviderContainer(
      overrides: overrides,
    );
  }

  /// Ожидает, что провайдер вернёт данные (не loading, не error)
  static Future<T> expectProviderData<T>(
    ProviderContainer container,
    ProviderListenable<AsyncValue<T>> provider,
  ) async {
    final value = container.read(provider);
    expect(value, isA<AsyncData<T>>());
    return (value as AsyncData<T>).value;
  }

  /// Ожидает, что провайдер находится в состоянии loading
  static void expectProviderLoading<T>(
    ProviderContainer container,
    ProviderListenable<AsyncValue<T>> provider,
  ) {
    final value = container.read(provider);
    expect(value, isA<AsyncLoading<T>>());
  }

  /// Ожидает, что провайдер находится в состоянии error
  static void expectProviderError<T>(
    ProviderContainer container,
    ProviderListenable<AsyncValue<T>> provider,
  ) {
    final value = container.read(provider);
    expect(value, isA<AsyncError<T>>());
  }

  /// Получает значение провайдера или null
  static T? getProviderValueOrNull<T>(
    ProviderContainer container,
    ProviderListenable<T> provider,
  ) {
    try {
      return container.read(provider);
    } catch (_) {
      return null;
    }
  }

  /// Ожидает изменения провайдера
  static Future<T> waitForProviderUpdate<T>(
    ProviderContainer container,
    ProviderListenable<T> provider, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final completer = Completer<T>();

    final subscription = container.listen(
      provider,
      (previous, next) {
        if (!completer.isCompleted) {
          completer.complete(next);
        }
      },
    );

    try {
      return await completer.future.timeout(timeout);
    } finally {
      subscription.close();
    }
  }
}

/// Расширения для ProviderContainer
extension ProviderContainerTestExtensions on ProviderContainer {
  /// Читает провайдер с обработкой ошибок
  T? readOrNull<T>(ProviderListenable<T> provider) {
    try {
      return read(provider);
    } catch (_) {
      return null;
    }
  }

  /// Очищает все провайдеры (для cleanup в тестах)
  void disposeAll() {
    dispose();
  }
}
