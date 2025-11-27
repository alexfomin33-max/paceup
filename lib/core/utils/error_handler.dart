// ────────────────────────────────────────────────────────────────────────────
//  ERROR HANDLER
//
//  Единая обработка ошибок для всего приложения
//  Форматирует различные типы ошибок в понятные сообщения для пользователя
// ────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';
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
  /// • Общие Exception — универсальная обработка
  static String format(dynamic error) {
    if (error is ApiException) {
      return error.message;
    }

    if (error is SocketException) {
      return 'Нет подключения к интернету';
    }

    if (error is TimeoutException) {
      return 'Превышено время ожидания. Попробуйте ещё раз';
    }

    if (error is FormatException) {
      return 'Ошибка обработки данных';
    }

    if (error is Exception) {
      final message = error.toString();
      // Убираем префикс "Exception: " или "ApiException: "
      return message
          .replaceAll(RegExp(r'^(\w+Exception|Exception):\s*'), '')
          .trim();
    }

    // Для всех остальных случаев
    return error?.toString() ?? 'Произошла неизвестная ошибка';
  }

  /// Проверяет, является ли ошибка сетевой (требует повторной попытки)
  static bool isNetworkError(dynamic error) {
    return error is SocketException || error is TimeoutException;
  }

  /// Проверяет, является ли ошибка ошибкой API
  static bool isApiError(dynamic error) {
    return error is ApiException;
  }

  /// Получает код ошибки, если он есть (для API ошибок)
  static int? getErrorCode(dynamic error) {
    // Можно расширить, если API будет возвращать коды ошибок
    return null;
  }
}
