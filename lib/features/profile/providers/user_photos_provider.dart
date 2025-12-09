// ────────────────────────────────────────────────────────────────────────────
//  USER PHOTOS PROVIDER
//
//  StateNotifierProvider для управления фотографиями пользователя
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/services/api_provider.dart';
import 'user_photos_notifier.dart';
import 'user_photos_state.dart';

/// Provider для фотографий пользователя (зависит от userId)
///
/// Использование:
/// ```dart
/// final photosState = ref.watch(userPhotosProvider(userId));
///
/// // Загрузка данных
/// ref.read(userPhotosProvider(userId).notifier).load();
///
/// // Обновление
/// ref.read(userPhotosProvider(userId).notifier).refresh();
/// ```
final userPhotosProvider = StateNotifierProvider.family<
    UserPhotosNotifier, UserPhotosState, int>((ref, userId) {
  final api = ref.watch(apiServiceProvider);
  final notifier = UserPhotosNotifier(
    api: api,
    userId: userId,
  );

  // Автоматическая загрузка при создании провайдера
  Future.microtask(() => notifier.load());

  return notifier;
});

