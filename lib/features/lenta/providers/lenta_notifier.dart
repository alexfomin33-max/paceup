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
import '../../../core/services/api_service.dart';
import '../../../core/services/cache_service.dart';
import '../../../domain/models/activity_lenta.dart';
import '../../../core/utils/error_handler.dart';
import 'lenta_state.dart';

class LentaNotifier extends StateNotifier<LentaState> {
  final ApiService _api;
  final CacheService _cache;
  final int userId;
  final int limit;

  // ────────────────────────────────────────────────────────────────────────────
  // 🔒 ЗАЩИТА ОТ ОДНОВРЕМЕННОГО ВЫПОЛНЕНИЯ
  // ────────────────────────────────────────────────────────────────────────────
  // Флаг для предотвращения race condition при одновременном вызове
  // loadInitial(), refresh() и forceRefresh()
  bool _isLoading = false;

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

  /// Дедупликация списка активностей по lentaId
  ///
  /// Удаляет дубликаты, сохраняя порядок (первые вхождения остаются)
  /// Используется для защиты от дубликатов, которые могут вернуться из API
  List<Activity> _deduplicateItems(List<Activity> items) {
    final seenIds = <int>{};
    final result = <Activity>[];

    for (final item in items) {
      final itemId = _getId(item);
      if (!seenIds.contains(itemId)) {
        seenIds.add(itemId);
        result.add(item);
      }
    }

    return result;
  }

  /// Загрузка активностей через API
  ///
  /// Возвращает список, отсортированный по дате из таблицы lenta (новые сверху)
  /// API уже возвращает данные отсортированными по lenta.dates DESC
  Future<List<Activity>> _loadActivities({
    required int page,
    required int limit,
  }) async {
    final response = await _api.post(
      '/activities_lenta.php',
      body: {'userId': '$userId', 'limit': '$limit', 'page': '$page'},
      timeout: const Duration(seconds: 15),
    );

    // PHP API возвращает массив напрямую, а не в поле 'data'
    List<dynamic> rawList;
    if (response is List<dynamic>) {
      rawList = List<dynamic>.from(response as List);
    } else if (response is Map<String, dynamic>) {
      if (response.containsKey('data')) {
        final dataValue = response['data'];
        if (dataValue is List) {
          rawList = List<dynamic>.from(dataValue);
        } else {
          rawList = const <dynamic>[];
        }
      } else {
        rawList = const <dynamic>[];
      }
    } else {
      rawList = const <dynamic>[];
    }
    
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
    // 🔒 Защита от одновременного выполнения
    if (_isLoading) return;

    try {
      _isLoading = true;

      // Показываем индикатор загрузки
      state = state.copyWith(isRefreshing: true, error: null);

      // ────────── ШАГ 2: Загружаем свежие данные ──────────
      final freshItems = await _loadActivities(page: 1, limit: limit);

      // ✅ Дедупликация на случай, если API вернет дубликаты
      final deduplicatedItems = _deduplicateItems(freshItems);

      // Сохраняем в кэш (для возможного использования в будущем)
      await _cache.cacheActivities(deduplicatedItems, userId: userId);

      final newSeenIds = deduplicatedItems.map(_getId).toSet();

      // ✅ hasMore должен быть true, если вернулось больше 0 элементов
      // Останавливаемся только если вернулось 0 элементов (значит больше нет данных)
      // Это позволяет загружать дополнительные страницы, даже если на текущей странице меньше limit элементов
      final itemsCount = deduplicatedItems.length;
      final hasMore = itemsCount > 0;
      
      state = state.copyWith(
        items: deduplicatedItems,
        currentPage: 1,
        hasMore: hasMore,
        seenIds: newSeenIds,
        isRefreshing: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: ErrorHandler.format(e),
        isRefreshing: false,
      );
    } finally {
      _isLoading = false;
    }
  }

  /// Pull-to-refresh (обновление первой страницы)
  ///
  /// Обновляет данные с сервера и сохраняет в кэш
  /// ✅ Обновляет существующие элементы свежими данными (включая счетчики комментариев)
  Future<void> refresh() async {
    // 🔒 Защита от одновременного выполнения
    if (_isLoading) return;

    try {
      _isLoading = true;
      state = state.copyWith(isRefreshing: true, error: null);

      final freshItems = await _loadActivities(page: 1, limit: limit);

      // ✅ Дедупликация на случай, если API вернет дубликаты
      final deduplicatedFreshItems = _deduplicateItems(freshItems);

      // Сохраняем в кэш
      await _cache.cacheActivities(deduplicatedFreshItems, userId: userId);

      // Создаем Map для быстрого поиска свежих элементов по lentaId
      final freshItemsMap = {
        for (var item in deduplicatedFreshItems) _getId(item): item,
      };

      // Обновляем существующие элементы свежими данными и добавляем новые
      final updatedItems = <Activity>[];
      final updatedSeenIds = <int>{};

      // Сначала добавляем свежие элементы (новые и обновленные)
      for (final freshItem in deduplicatedFreshItems) {
        final itemId = _getId(freshItem);
        // ✅ Дополнительная проверка на дубликаты
        if (!updatedSeenIds.contains(itemId)) {
          updatedItems.add(freshItem);
          updatedSeenIds.add(itemId);
        }
      }

      // Затем добавляем старые элементы, которых нет в свежих данных
      for (final oldItem in state.items) {
        final itemId = _getId(oldItem);
        // ✅ Проверяем, что элемент не в свежих данных И не добавлен уже
        if (!freshItemsMap.containsKey(itemId) &&
            !updatedSeenIds.contains(itemId)) {
          updatedItems.add(oldItem);
          updatedSeenIds.add(itemId);
        }
      }

      // ✅ hasMore должен быть true, если свежих элементов больше 0
      // Останавливаемся только если вернулось 0 элементов (значит больше нет данных)
      // Но также учитываем, что если до refresh были загружены дополнительные страницы,
      // то возможно есть еще данные на следующих страницах (которые мы еще не проверили)
      final freshItemsCount = deduplicatedFreshItems.length;
      final hadMorePagesBeforeRefresh = state.currentPage > 1 && state.hasMore;
      final hasMore = freshItemsCount > 0 || hadMorePagesBeforeRefresh;

      state = state.copyWith(
        items: updatedItems,
        seenIds: updatedSeenIds,
        currentPage: 1, // ✅ Сбрасываем currentPage на 1 после refresh
        hasMore: hasMore,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: ErrorHandler.format(e),
        isRefreshing: false,
      );
    } finally {
      _isLoading = false;
    }
  }

  /// Принудительное обновление после создания/редактирования поста
  ///
  /// Очищает кэш и полностью перезагружает первую страницу
  /// Используется после создания нового поста для гарантированного
  /// отображения обновленных данных
  Future<void> forceRefresh() async {
    // 🔒 Защита от одновременного выполнения
    if (_isLoading) return;

    try {
      _isLoading = true;
      state = state.copyWith(isRefreshing: true, error: null);

      // Очищаем кэш активностей перед обновлением
      await _cache.clearActivitiesCache(userId: userId);

      // Загружаем свежие данные с сервера
      final freshItems = await _loadActivities(page: 1, limit: limit);

      // ✅ Дедупликация на случай, если API вернет дубликаты
      final deduplicatedItems = _deduplicateItems(freshItems);

      // Сохраняем в кэш
      await _cache.cacheActivities(deduplicatedItems, userId: userId);

      // Полностью заменяем список (новые посты должны быть в начале)
      final newSeenIds = deduplicatedItems.map(_getId).toSet();

      state = state.copyWith(
        items: deduplicatedItems,
        currentPage: 1,
        seenIds: newSeenIds,
        hasMore: deduplicatedItems.length == limit,
        isRefreshing: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: ErrorHandler.format(e),
        isRefreshing: false,
      );
    } finally {
      _isLoading = false;
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

      // ✅ hasMore должен быть true, если вернулось больше 0 элементов
      // Останавливаемся только если вернулось 0 элементов (значит больше нет данных)
      // Это позволяет загружать дополнительные страницы, даже если на текущей странице меньше limit элементов
      // Проверяем на основе исходного количества элементов с сервера (moreItems.length),
      // а не после дедупликации (newItems.length), потому что сервер может вернуть дубликаты
      final hasMore = moreItems.length > 0;
      
      state = state.copyWith(
        items: updatedItems,
        currentPage: nextPage,
        seenIds: updatedSeenIds,
        hasMore: hasMore,
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

  /// Удаление всех записей пользователя по типу контента
  /// Используется при скрытии постов/тренировок пользователя
  /// Не сбрасывает пагинацию, чтобы не ломать загрузку следующих страниц
  Future<void> removeUserContent({
    required int hiddenUserId,
    required String contentType, // 'activity' или 'post'
  }) async {
    // Сначала собираем ID элементов, которые нужно удалить
    final removedIds = <int>{};
    
    // Фильтруем элементы: оставляем только те, которые НЕ от скрытого пользователя
    // или имеют другой тип контента
    final updatedItems = state.items.where((item) {
      // Если это запись от скрытого пользователя
      if (item.userId == hiddenUserId) {
        bool shouldHide = false;
        
        // Проверяем тип контента
        if (contentType == 'activity') {
          // Скрываем тренировки (все, кроме постов)
          shouldHide = item.type != 'post';
        } else if (contentType == 'post') {
          // Скрываем посты
          shouldHide = item.type == 'post';
        }
        
        if (shouldHide) {
          removedIds.add(_getId(item));
          return false; // Удаляем этот элемент
        }
      }
      // Оставляем все остальные записи
      return true;
    }).toList();

    final updatedSeenIds = Set<int>.from(state.seenIds)..removeAll(removedIds);

    // ✅ Важно: НЕ сбрасываем currentPage и hasMore
    // Это позволяет продолжить загрузку следующих страниц
    state = state.copyWith(
      items: updatedItems,
      seenIds: updatedSeenIds,
      // Пагинация сохраняется
    );

    // Удаляем из кэша скрытые элементы
    for (final lentaId in removedIds) {
      await _cache.removeCachedActivity(lentaId: lentaId);
    }
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

  /// Обновляет список фотографий для активности и кэша
  /// Использует lentaId для точной идентификации элемента в ленте
  Future<void> updateActivityMedia({
    required int lentaId,
    required List<String> mediaImages,
  }) async {
    final updatedItems = state.items.map((item) {
      if (_getId(item) == lentaId) {
        return item.copyWithMedia(images: mediaImages);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);

    await _cache.updateCachedActivityMedia(
      lentaId: lentaId,
      mediaImages: mediaImages,
    );
  }
}
