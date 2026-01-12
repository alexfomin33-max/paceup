// ────────────────────────────────────────────────────────────────────────────
//  MOCK API SERVICE
//
//  Мок для ApiService для использования в тестах
//  Использует mocktail для создания моков без code generation
// ────────────────────────────────────────────────────────────────────────────

import 'package:mocktail/mocktail.dart';
import 'package:paceup/core/services/api_service.dart';

/// Мок для ApiService
class MockApiService extends Mock implements ApiService {}

/// Хелперы для создания MockApiService
class MockApiServiceFactory {
  /// Создаёт мок с предустановленными ответами
  static MockApiService withDefaults({
    Map<String, dynamic>? defaultGetResponse,
    Map<String, dynamic>? defaultPostResponse,
  }) {
    final mock = MockApiService();
    
    // Настраиваем дефолтные ответы
    when(() => mock.get(any(), queryParams: any(named: 'queryParams'), headers: any(named: 'headers'), timeout: any(named: 'timeout')))
        .thenAnswer((_) async => defaultGetResponse ?? {'success': true});
    
    when(() => mock.post(any(), body: any(named: 'body'), headers: any(named: 'headers'), timeout: any(named: 'timeout')))
        .thenAnswer((_) async => defaultPostResponse ?? {'success': true});
    
    when(() => mock.put(any(), body: any(named: 'body'), headers: any(named: 'headers'), timeout: any(named: 'timeout')))
        .thenAnswer((_) async => {'success': true});
    
    when(() => mock.delete(any(), headers: any(named: 'headers'), timeout: any(named: 'timeout')))
        .thenAnswer((_) async => {'success': true});
    
    when(() => mock.patch(any(), body: any(named: 'body'), headers: any(named: 'headers'), timeout: any(named: 'timeout')))
        .thenAnswer((_) async => {'success': true});
    
    return mock;
  }

  /// Создаёт мок, который возвращает успешный ответ
  static MockApiService successful() {
    return withDefaults();
  }

  /// Создаёт мок, который выбрасывает ApiException
  static MockApiService withError(String errorMessage) {
    final mock = MockApiService();
    
    when(() => mock.get(any(), queryParams: any(named: 'queryParams'), headers: any(named: 'headers'), timeout: any(named: 'timeout')))
        .thenThrow(ApiException(errorMessage));
    
    when(() => mock.post(any(), body: any(named: 'body'), headers: any(named: 'headers'), timeout: any(named: 'timeout')))
        .thenThrow(ApiException(errorMessage));
    
    when(() => mock.put(any(), body: any(named: 'body'), headers: any(named: 'headers'), timeout: any(named: 'timeout')))
        .thenThrow(ApiException(errorMessage));
    
    when(() => mock.delete(any(), headers: any(named: 'headers'), timeout: any(named: 'timeout')))
        .thenThrow(ApiException(errorMessage));
    
    when(() => mock.patch(any(), body: any(named: 'body'), headers: any(named: 'headers'), timeout: any(named: 'timeout')))
        .thenThrow(ApiException(errorMessage));
    
    return mock;
  }

  /// Создаёт мок, который возвращает конкретный ответ для GET запроса
  static MockApiService withGetResponse(Map<String, dynamic> response) {
    return withDefaults(defaultGetResponse: response);
  }

  /// Создаёт мок, который возвращает конкретный ответ для POST запроса
  static MockApiService withPostResponse(Map<String, dynamic> response) {
    return withDefaults(defaultPostResponse: response);
  }
}
