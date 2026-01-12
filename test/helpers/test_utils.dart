// ────────────────────────────────────────────────────────────────────────────
//  TEST UTILITIES
//
//  Общие утилиты для всех тестов:
//  • Создание тестового окружения
//  • Хелперы для работы с датами
//  • Утилиты для работы с JSON
//  • Общие константы для тестов
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';

/// Общие утилиты для тестов
class TestUtils {
  /// Создаёт тестовую дату с заданным смещением от текущей
  static DateTime testDate({int daysOffset = 0}) {
    return DateTime.now().add(Duration(days: daysOffset));
  }

  /// Создаёт тестовую дату из строки (SQL формат)
  static DateTime? parseTestDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      // Поддержка SQL формата: "YYYY-MM-DD HH:mm:ss"
      final normalized = dateString.replaceFirst(' ', 'T');
      return DateTime.parse(normalized);
    } catch (_) {
      return null;
    }
  }

  /// Проверяет, что два DateTime равны (игнорируя микросекунды)
  static bool datesEqual(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute &&
        a.second == b.second;
  }

  /// Создаёт тестовый JSON объект
  static Map<String, dynamic> createTestJson({
    Map<String, dynamic>? overrides,
  }) {
    return {
      'id': 1,
      'name': 'Test',
      'value': 'test',
      ...?overrides,
    };
  }

  /// Ожидает завершения всех асинхронных операций
  static Future<void> waitForAsync() async {
    await Future.delayed(Duration(milliseconds: 100));
  }

  /// Ожидает завершения всех асинхронных операций с таймаутом
  static Future<void> waitForAsyncWithTimeout({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await Future.delayed(Duration(milliseconds: 100)).timeout(timeout);
  }
}

/// Расширения для тестирования
extension TestExtensions on DateTime {
  /// Форматирует дату в SQL формат для тестов
  String toSqlString() {
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')} '
        '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:'
        '${second.toString().padLeft(2, '0')}';
  }
}

/// Матчеры для тестов
class TestMatchers {
  /// Проверяет, что значение является валидным ID (положительное число)
  static Matcher isValidId() {
    return predicate<int>(
      (id) => id > 0,
      'is a valid ID (positive number)',
    );
  }

  /// Проверяет, что строка не пустая
  static Matcher isNotEmptyString() {
    return predicate<String>(
      (str) => str.isNotEmpty,
      'is not empty',
    );
  }

  /// Проверяет, что список не пустой
  static Matcher isNotEmptyList() {
    return predicate<List>(
      (list) => list.isNotEmpty,
      'is not empty',
    );
  }
}
