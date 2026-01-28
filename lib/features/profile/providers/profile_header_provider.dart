// ────────────────────────────────────────────────────────────────────────────
//  PROFILE HEADER PROVIDER
//
//  StateNotifierProvider для управления header'ом профиля
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/models/user_profile_header.dart';
import '../../../../providers/services/api_provider.dart';
import '../../../../providers/services/auth_provider.dart';
import '../../../../providers/services/cache_provider.dart';
import 'profile_header_notifier.dart';
import 'profile_header_state.dart';

/// Provider для ProfileHeader (зависит от userId)
///
/// Использование:
/// ```dart
/// final profileState = ref.watch(profileHeaderProvider(userId));
///
/// // Загрузка данных
/// ref.read(profileHeaderProvider(userId).notifier).load();
///
/// // Перезагрузка после редактирования
/// ref.read(profileHeaderProvider(userId).notifier).reload();
/// ```
final profileHeaderProvider = StateNotifierProvider.family<
    ProfileHeaderNotifier, ProfileHeaderState, int>((ref, userId) {
  final api = ref.watch(apiServiceProvider);
  final cache = ref.watch(cacheServiceProvider);
  final notifier = ProfileHeaderNotifier(
    api: api,
    cache: cache,
    userId: userId,
    ref: ref,
  );
  
  // Автоматическая загрузка при создании провайдера
  Future.microtask(() => notifier.load());
  
  return notifier;
});

/// Индекс вида спорта по умолчанию для текущего пользователя (для экранов
/// Статистика и Лидерборд): 0 бег, 1 вело, 2 плавание, 3 лыжи.
/// Берётся из users.sport через profileHeaderProvider.
final defaultSportIndexProvider = Provider<int>((ref) {
  final userId = ref.watch(currentUserIdProvider).valueOrNull;
  if (userId == null) return 0;
  final state = ref.watch(profileHeaderProvider(userId));
  return sportStringToIndex(state.profile?.sport);
});

