// ────────────────────────────────────────────────────────────────────────────
//  LENTA PROVIDER
//
//  StateNotifierProvider для управления лентой активностей
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_provider.dart';
import '../services/cache_provider.dart';
import 'lenta_notifier.dart';
import 'lenta_state.dart';

/// Provider для Lenta (зависит от userId)
///
/// Использование:
/// ```dart
/// final lentaState = ref.watch(lentaProvider(userId));
///
/// // Загрузка данных
/// ref.read(lentaProvider(userId).notifier).loadInitial();
///
/// // Refresh
/// ref.read(lentaProvider(userId).notifier).refresh();
///
/// // Загрузка следующей страницы
/// ref.read(lentaProvider(userId).notifier).loadMore();
///
/// // Удаление поста
/// ref.read(lentaProvider(userId).notifier).removeItem(lentaId);
/// ```
final lentaProvider =
    StateNotifierProvider.family<LentaNotifier, LentaState, int>((ref, userId) {
      final api = ref.watch(apiServiceProvider);
      final cache = ref.watch(cacheServiceProvider);
      return LentaNotifier(
        api: api,
        cache: cache,
        userId: userId,
        limit: 5, // количество элементов на странице
      );
    });
