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
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(Activity.fromApi)
        .toList();
  }

  // ────────────────────────── ЗАГРУЗКА ──────────────────────────

  /// Начальная загрузка (первая страница)
  ///
  /// OFFLINE-FIRST ПОДХОД:
  /// 1. Сразу показываем кэш (0.05 сек) — пользователь видит контент мгновенно
  /// 2. В фоне загружаем свежие данные с сервера (1-3 сек)
  /// 3. Плавно обновляем UI и сохраняем в кэш
  /// 4. Если ошибка сети — показываем кэш (работа без интернета)
  Future<void> loadInitial() async {
    try {
      // ────────── ШАГ 1: Показываем кэш (мгновенно) ──────────
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

      // ────────── ШАГ 2: Загружаем свежие данные (фон) ──────────
      state = state.copyWith(isRefreshing: true);

      final freshItems = await _loadActivities(page: 1, limit: limit);

      // Сохраняем в кэш
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
      // Если ошибка сети — показываем кэш (offline mode)
      if (state.items.isNotEmpty) {
        state = state.copyWith(
          error: 'Показаны сохранённые данные',
          isRefreshing: false,
        );
      } else {
        state = state.copyWith(error: e.toString(), isRefreshing: false);
      }
    }
  }

  /// Pull-to-refresh (обновление первой страницы)
  ///
  /// Обновляет данные с сервера и сохраняет в кэш
  Future<void> refresh() async {
    try {
      state = state.copyWith(isRefreshing: true, error: null);

      final freshItems = await _loadActivities(page: 1, limit: limit);

      // Сохраняем в кэш
      await _cache.cacheActivities(freshItems, userId: userId);

      // Обновляем только новые элементы, сохраняя старые внизу
      final existingIds = state.seenIds;
      final newItems = freshItems.where((item) {
        return !existingIds.contains(_getId(item));
      }).toList();

      final updatedItems = [...newItems, ...state.items];
      final updatedSeenIds = {...state.seenIds, ...newItems.map(_getId)};

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
