// ────────────────────────────────────────────────────────────────────────────
//  ERROR HANDLER
//
//  Единая обработка ошибок для всего приложения
//  Форматирует различные типы ошибок в понятные сообщения для пользователя
//
//  Возможности:
//  • Форматирование всех типов ошибок (API, сеть, парсинг, валидация)
//  • Определение типа ошибки (сетевая, API, клиентская)
//  • Проверка возможности повторной попытки
//  • Единый формат сообщений для пользователя
// ────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

/// Утилита для обработки и форматирования ошибок
class ErrorHandler {
  /// Форматирует ошибку в понятное сообщение для пользователя
  ///
  /// Поддерживает:
  /// • ApiException — ошибки API
  /// • SocketException — проблемы с сетью
  /// • TimeoutException — таймауты
  /// • FormatException — ошибки парсинга
  /// • HttpException — HTTP ошибки
  /// • PlatformException — ошибки платформы
  /// • Общие Exception — универсальная обработка
  /// • String — строковые ошибки
  static String format(dynamic error) {
    if (error == null) {
      return 'Произошла неизвестная ошибка';
    }

    // ────────── ApiException ──────────
    if (error is ApiException) {
      return error.message;
    }

    // ────────── Сетевые ошибки ──────────
    if (error is SocketException) {
      return 'Нет подключения к интернету. Проверьте соединение и попробуйте ещё раз';
    }

    if (error is TimeoutException) {
      return 'Превышено время ожидания. Попробуйте ещё раз';
    }

    if (error is HttpException) {
      return 'Ошибка соединения с сервером. Попробуйте позже';
    }

    // ────────── Ошибки парсинга ──────────
    if (error is FormatException) {
      return 'Ошибка обработки данных. Попробуйте обновить страницу';
    }

    // ────────── Платформенные ошибки ──────────
    if (error is PlatformException) {
      final message = error.message ?? 'Ошибка платформы';
      // Специфичные сообщения для известных ошибок
      if (message.contains('permission') || message.contains('разрешение')) {
        return 'Недостаточно прав доступа. Проверьте настройки приложения';
      }
      if (message.contains('network') || message.contains('сеть')) {
        return 'Проблема с сетью. Проверьте подключение';
      }
      return message;
    }

    // ────────── Общие Exception ──────────
    if (error is Exception) {
      final message = error.toString();
      // Убираем префикс "Exception: " или "ApiException: "
      final cleaned = message
          .replaceAll(RegExp(r'^(\w+Exception|Exception):\s*'), '')
          .trim();

      // Если сообщение пустое или слишком техническое, возвращаем общее
      if (cleaned.isEmpty || cleaned.startsWith('Instance of')) {
        return 'Произошла ошибка. Попробуйте ещё раз';
      }

      return cleaned;
    }

    // ────────── String ошибки ──────────
    if (error is String) {
      // Убираем технические префиксы
      final cleaned = error
          .replaceAll(RegExp(r'^(\w+Exception|Exception):\s*'), '')
          .trim();
      return cleaned.isEmpty ? 'Произошла ошибка' : cleaned;
    }

    // ────────── Для всех остальных случаев ──────────
    final stringError = error.toString();
    if (stringError.startsWith('Instance of')) {
      return 'Произошла неизвестная ошибка. Попробуйте ещё раз';
    }

    // Если это уже строка, возвращаем как есть
    return stringError;
  }

  /// Проверяет, является ли ошибка сетевой (требует повторной попытки)
  ///
  /// Сетевые ошибки обычно можно исправить повторной попыткой
  static bool isNetworkError(dynamic error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is HttpException ||
        (error is String &&
            (error.contains('connection') ||
                error.contains('соединен') ||
                error.contains('network') ||
                error.contains('сеть') ||
                error.contains('timeout') ||
                error.contains('таймаут')));
  }

  /// Проверяет, является ли ошибка ошибкой API
  static bool isApiError(dynamic error) {
    return error is ApiException ||
        (error is String && error.contains('API')) ||
        (error is String && error.contains('сервер'));
  }

  /// Проверяет, является ли ошибка ошибкой валидации (клиентская ошибка)
  ///
  /// Ошибки валидации не требуют повторной попытки, нужно исправить данные
  static bool isValidationError(dynamic error) {
    if (error is String) {
      final lower = error.toLowerCase();
      return lower.contains('validation') ||
          lower.contains('валидац') ||
          lower.contains('неверн') ||
          lower.contains('некорректн') ||
          lower.contains('required') ||
          lower.contains('обязател');
    }
    return false;
  }

  /// Проверяет, можно ли повторить операцию при этой ошибке
  ///
  /// Сетевые ошибки можно повторить, ошибки валидации — нет
  static bool canRetry(dynamic error) {
    return isNetworkError(error) && !isValidationError(error);
  }

  /// Получает код ошибки, если он есть (для API ошибок)
  ///
  /// В будущем можно расширить, если API будет возвращать коды ошибок
  static int? getErrorCode(dynamic error) {
    // TODO: Добавить парсинг кодов ошибок из ApiException, если они появятся
    return null;
  }

  /// Логирует ошибку для отладки (только в debug режиме)
  ///
  /// В production не логирует, чтобы не засорять логи
  static void logError(dynamic error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('❌ Error: ${format(error)}');
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  /// Получает пользовательское сообщение с учетом контекста
  ///
  /// Параметры:
  /// • error — ошибка для форматирования
  /// • context — контекст операции (для более точных сообщений)
  ///
  /// Пример:
  /// ```dart
  /// ErrorHandler.formatWithContext(
  ///   error,
  ///   context: 'загрузка профиля',
  /// );
  /// // → "Ошибка при загрузке профиля: Нет подключения к интернету"
  /// ```
  static String formatWithContext(dynamic error, {String? context}) {
    final message = format(error);
    if (context != null && context.isNotEmpty) {
      return 'Ошибка при $context: $message';
    }
    return message;
  }
}
