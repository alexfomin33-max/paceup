// ────────────────────────────────────────────────────────────────────────────
//  AUTH SERVICE PROVIDER
//
//  Singleton Provider для AuthService
//  Используется для авторизации, токенов, userId
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';

/// Provider для AuthService (singleton)
///
/// Использование:
/// ```dart
/// final auth = ref.read(authServiceProvider);
/// await auth.login(phone, password);
/// ```
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Provider для проверки авторизации (async)
///
/// Использование:
/// ```dart
/// final isAuthorized = await ref.watch(isAuthorizedProvider.future);
/// ```
final isAuthorizedProvider = FutureProvider<bool>((ref) async {
  final auth = ref.watch(authServiceProvider);
  return await auth.isAuthorized();
});

/// Provider для текущего userId
///
/// Использование:
/// ```dart
/// final userId = ref.watch(currentUserIdProvider);
/// ```
final currentUserIdProvider = FutureProvider<int?>((ref) async {
  final auth = ref.watch(authServiceProvider);
  return await auth.getUserId();
});
