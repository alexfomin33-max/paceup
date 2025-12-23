// ────────────────────────────────────────────────────────────────────────────
//  LENTA PROVIDER
//
//  StateNotifierProvider для управления лентой активностей
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/services/api_provider.dart';
import '../../../providers/services/cache_provider.dart';
import '../../../domain/models/activity_lenta.dart';
import 'lenta_notifier.dart';
import 'lenta_state.dart';

// ────────────────────────────────────────────────────────────────────────────
//  КЛЮЧ ДЛЯ ПОИСКА ОДНОГО ЭЛЕМЕНТА ЛЕНТЫ
// ────────────────────────────────────────────────────────────────────────────
typedef LentaItemKey = ({int userId, int lentaId});

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
        limit: 10, // количество элементов на странице
        // Оптимальный баланс для мобильной ленты:
        // - Достаточно контента для комфортного скролла (2-3 экрана)
        // - Приемлемый размер JSON (~30-50KB без медиа)
        // - Меньше сетевых запросов при активном использовании
        // - Быстрая первая загрузка даже на 3G
      );
    });

// ────────────────────────────────────────────────────────────────────────────
//  ПРОВАЙДЕР ОДНОГО ЭЛЕМЕНТА ЛЕНТЫ
//  Используем select, чтобы перестраивать только карточку с изменившимся ID.
// ────────────────────────────────────────────────────────────────────────────
final lentaItemProvider =
    Provider.family<Activity?, LentaItemKey>((ref, key) {
      return ref.watch(
        lentaProvider(key.userId).select((state) {
          final index = state.items.indexWhere(
            (a) => a.lentaId == key.lentaId,
          );
          if (index == -1) return null;
          return state.items[index];
        }),
      );
    });
