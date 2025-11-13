// ────────────────────────────────────────────────────────────────────────────
//  LENTA NOTIFIER
//
//  StateNotifier для управления лентой активностей
//  Возможности:
//  • Начальная загрузка с кэша (мгновенно) + фоновое обновление
//  • Pull-to-refresh
//  • Пагинация (загрузка следующей страницы)
//  • Дедупликация по ID
//  • Удаление активности/поста
//  • Обновление счётчика лайков
//  • Offline-first кэширование (работа без интернета)
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../service/api_service.dart';
import '../../service/cache_service.dart';
import '../../models/activity_lenta.dart';
import 'lenta_state.dart';

class LentaNotifier extends StateNotifier<LentaState> {
  final ApiService _api;
  final CacheService _cache;
  final int userId;
  final int limit;

  LentaNotifier({
    required ApiService api,
    required CacheService cache,
    required this.userId,
    this.limit = 5,
  }) : _api = api,
       _cache = cache,
       super(LentaState.initial());

  /// ID активности для дедупликации
  int _getId(Activity a) => a.lentaId;

  // ────────────────────────── ПРИВАТНЫЕ МЕТОДЫ ──────────────────────────

  /// Загрузка активностей через API
  /// 
  /// Возвращает список, отсортированный по дате из таблицы lenta (новые сверху)
  /// API уже возвращает данные отсортированными по lenta.dates DESC
  Future<List<Activity>> _loadActivities({
    required int page,
    required int limit,
  }) async {
    final data = await _api.post(
      '/activities_lenta.php',
      body: {'userId': '$userId', 'limit': '$limit', 'page': '$page'},
      timeout: const Duration(seconds: 15),
    );

    final List rawList = data['data'] as List? ?? const [];
    final activities = rawList
        .whereType<Map<String, dynamic>>()
        .map(Activity.fromApi)
        .toList();
    
    // ✅ Сортируем по lentaDate (дата из таблицы lenta) - новые сверху
    // Это обеспечивает единую сортировку для активностей и постов
    activities.sort((a, b) {
      final dateA = a.lentaDate;
      final dateB = b.lentaDate;
      
      // Если даты отсутствуют, помещаем в конец
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      
      // Сортировка по убыванию (новые сверху)
      return dateB.compareTo(dateA);
    });
    
    return activities;
  }

  // ────────────────────────── ЗАГРУЗКА ──────────────────────────

  /// Начальная загрузка (первая страница)
  ///
  /// ✅ КЕШ ОТКЛЮЧЕН (можно быстро вернуть, раскомментировав блок ниже)
  /// OFFLINE-FIRST ПОДХОД (отключен):
  /// 1. Сразу показываем кэш (0.05 сек) — пользователь видит контент мгновенно
  /// 2. В фоне загружаем свежие данные с сервера (1-3 сек)
  /// 3. Плавно обновляем UI и сохраняем в кэш
  /// 4. Если ошибка сети — показываем кэш (работа без интернета)
  Future<void> loadInitial() async {
    try {
      // ────────── ШАГ 1: Показываем кэш (мгновенно) ──────────
      // ✅ ОТКЛЮЧЕНО: раскомментировать для включения кеша
      /*
      final cachedItems = await _cache.getCachedActivities(
        userId: userId,
        limit: limit,
      );

      if (cachedItems.isNotEmpty) {
        final cachedSeenIds = cachedItems.map(_getId).toSet();
        state = state.copyWith(
          items: cachedItems,
          currentPage: 1,
          hasMore: true, // предполагаем что есть ещё
          seenIds: cachedSeenIds,
          isRefreshing: false,
        );
      } else {
        // Если кэша нет — показываем индикатор загрузки
        state = state.copyWith(isRefreshing: true, error: null);
      }
      */

      // Показываем индикатор загрузки
      state = state.copyWith(isRefreshing: true, error: null);

      // ────────── ШАГ 2: Загружаем свежие данные ──────────
      final freshItems = await _loadActivities(page: 1, limit: limit);

      // Сохраняем в кэш (для возможного использования в будущем)
      await _cache.cacheActivities(freshItems, userId: userId);

      final newSeenIds = freshItems.map(_getId).toSet();

      state = state.copyWith(
        items: freshItems,
        currentPage: 1,
        hasMore: freshItems.length == limit,
        seenIds: newSeenIds,
        isRefreshing: false,
        error: null,
      );
    } catch (e) {
      // ✅ ОТКЛЮЧЕНО: fallback на кеш при ошибке
      /*
      // Если ошибка сети — показываем кэш (offline mode)
      if (state.items.isNotEmpty) {
        state = state.copyWith(
          error: 'Показаны сохранённые данные',
          isRefreshing: false,
        );
      } else {
        state = state.copyWith(error: e.toString(), isRefreshing: false);
      }
      */
      state = state.copyWith(error: e.toString(), isRefreshing: false);
    }
  }

  /// Pull-to-refresh (обновление первой страницы)
  ///
  /// Обновляет данные с сервера и сохраняет в кэш
  /// ✅ Обновляет существующие элементы свежими данными (включая счетчики комментариев)
  Future<void> refresh() async {
    try {
      state = state.copyWith(isRefreshing: true, error: null);

      final freshItems = await _loadActivities(page: 1, limit: limit);

      // Сохраняем в кэш
      await _cache.cacheActivities(freshItems, userId: userId);

      // Создаем Map для быстрого поиска свежих элементов по lentaId
      final freshItemsMap = {
        for (var item in freshItems) _getId(item): item
      };

      // Обновляем существующие элементы свежими данными и добавляем новые
      final updatedItems = <Activity>[];
      final updatedSeenIds = <int>{};

      // Сначала добавляем свежие элементы (новые и обновленные)
      for (final freshItem in freshItems) {
        final itemId = _getId(freshItem);
        updatedItems.add(freshItem); // Используем свежие данные с сервера
        updatedSeenIds.add(itemId);
      }

      // Затем добавляем старые элементы, которых нет в свежих данных
      for (final oldItem in state.items) {
        final itemId = _getId(oldItem);
        if (!freshItemsMap.containsKey(itemId)) {
          updatedItems.add(oldItem);
          updatedSeenIds.add(itemId);
        }
      }

      state = state.copyWith(
        items: updatedItems,
        seenIds: updatedSeenIds,
        hasMore: freshItems.length == limit,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isRefreshing: false);
    }
  }

  /// Принудительное обновление после создания/редактирования поста
  ///
  /// Очищает кэш и полностью перезагружает первую страницу
  /// Используется после создания нового поста для гарантированного
  /// отображения обновленных данных
  Future<void> forceRefresh() async {
    try {
      state = state.copyWith(isRefreshing: true, error: null);

      // Очищаем кэш активностей перед обновлением
      await _cache.clearActivitiesCache(userId: userId);

      // Загружаем свежие данные с сервера
      final freshItems = await _loadActivities(page: 1, limit: limit);

      // Сохраняем в кэш
      await _cache.cacheActivities(freshItems, userId: userId);

      // Полностью заменяем список (новые посты должны быть в начале)
      final newSeenIds = freshItems.map(_getId).toSet();

      state = state.copyWith(
        items: freshItems,
        currentPage: 1,
        seenIds: newSeenIds,
        hasMore: freshItems.length == limit,
        isRefreshing: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isRefreshing: false);
    }
  }

  /// Загрузка следующей страницы (пагинация)
  ///
  /// Загружает новые данные и сохраняет в кэш
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;

    try {
      state = state.copyWith(isLoadingMore: true, error: null);

      final nextPage = state.currentPage + 1;
      final moreItems = await _loadActivities(page: nextPage, limit: limit);

      // Сохраняем новые данные в кэш
      await _cache.cacheActivities(moreItems, userId: userId);

      // Дедупликация
      final newItems = moreItems.where((item) {
        return !state.seenIds.contains(_getId(item));
      }).toList();

      final updatedItems = [...state.items, ...newItems];
      final updatedSeenIds = {...state.seenIds, ...newItems.map(_getId)};

      state = state.copyWith(
        items: updatedItems,
        currentPage: nextPage,
        seenIds: updatedSeenIds,
        hasMore: moreItems.length == limit,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoadingMore: false);
    }
  }

  // ────────────────────────── МУТАЦИИ ──────────────────────────

  /// Удаление активности/поста из ленты
  /// Также удаляет из кэша
  Future<void> removeItem(int lentaId) async {
    final updatedItems = state.items.where((item) {
      return _getId(item) != lentaId;
    }).toList();

    final updatedSeenIds = Set<int>.from(state.seenIds)..remove(lentaId);

    state = state.copyWith(items: updatedItems, seenIds: updatedSeenIds);

    // Удаляем из кэша
    await _cache.removeCachedActivity(lentaId: lentaId);
  }

  /// Обновление счётчика лайков для активности
  /// Также обновляет кэш
  Future<void> updateLikes(int lentaId, int newLikesCount) async {
    final updatedItems = state.items.map((item) {
      if (_getId(item) == lentaId) {
        return item.copyWithLikes(newLikesCount);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);

    // Обновляем кэш
    await _cache.updateCachedActivityLikes(
      lentaId: lentaId,
      newLikes: newLikesCount,
    );
  }

  /// Обновление счётчика комментариев
  /// Также обновляет кэш
  Future<void> updateComments(int lentaId, int newCommentsCount) async {
    final updatedItems = state.items.map((item) {
      if (_getId(item) == lentaId) {
        return item.copyWithComments(newCommentsCount);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);

    // Обновляем кэш
    await _cache.updateCachedActivityComments(
      lentaId: lentaId,
      newComments: newCommentsCount,
    );
  }

  /// Обновление счётчика уведомлений
  void setUnreadCount(int count) {
    state = state.copyWith(unreadCount: count);
  }
}
