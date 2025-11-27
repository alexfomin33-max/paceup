// ────────────────────────────────────────────────────────────────────────────
//  API SERVICE PROVIDER
//
//  Singleton Provider для ApiService
//  Используется для всех HTTP запросов
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';

/// Provider для ApiService (singleton)
///
/// Использование:
/// ```dart
/// final api = ref.read(apiServiceProvider);
/// final data = await api.get('/users/1');
/// ```
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

/// Provider для dispose ApiService при завершении приложения
///
/// Автоматически очищает ресурсы HTTP клиента
final apiServiceDisposableProvider = Provider<ApiService>((ref) {
  final api = ApiService();

  // Dispose при уничтожении провайдера
  ref.onDispose(() {
    api.dispose();
  });

  return api;
});
