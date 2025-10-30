// ────────────────────────────────────────────────────────────────────────────
//  PROFILE HEADER PROVIDER
//
//  StateNotifierProvider для управления header'ом профиля
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_provider.dart';
import '../services/cache_provider.dart';
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
  );
  
  // Автоматическая загрузка при создании провайдера
  Future.microtask(() => notifier.load());
  
  return notifier;
});

