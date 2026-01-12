// ────────────────────────────────────────────────────────────────────────────
//  API RESPONSE FIXTURES
//
//  Фикстуры для создания тестовых API ответов
//  Используются в unit тестах для моков ApiService
// ────────────────────────────────────────────────────────────────────────────

/// Фикстуры для создания тестовых API ответов
class ApiResponseFixtures {
  /// Создаёт успешный ответ API
  static Map<String, dynamic> success({
    Map<String, dynamic>? data,
    String? message,
  }) {
    return {
      'success': true,
      if (message != null) 'message': message,
      if (data != null) ...data,
    };
  }

  /// Создаёт ответ с ошибкой
  static Map<String, dynamic> error({
    String? message,
    String? error,
    int? code,
  }) {
    return {
      'success': false,
      'ok': false,
      if (message != null) 'message': message,
      if (error != null) 'error': error,
      if (code != null) 'code': code,
    };
  }

  /// Создаёт ответ с данными в поле 'data'
  static Map<String, dynamic> withData({
    required dynamic data,
    bool success = true,
  }) {
    return {
      'success': success,
      'data': data,
    };
  }

  /// Создаёт ответ с массивом данных
  static Map<String, dynamic> withList({
    required List<dynamic> items,
    bool success = true,
  }) {
    return {
      'success': success,
      'data': items,
    };
  }

  /// Создаёт ответ для проверки токена
  static Map<String, dynamic> tokenCheck({
    bool valid = true,
  }) {
    return {
      'valid': valid,
    };
  }

  /// Создаёт ответ для обновления токена
  static Map<String, dynamic> tokenRefresh({
    String? accessToken,
    bool success = true,
  }) {
    return {
      'success': success,
      if (accessToken != null) 'access_token': accessToken,
    };
  }

  /// Создаёт пустой успешный ответ
  static Map<String, dynamic> empty() {
    return {
      'success': true,
    };
  }
}
