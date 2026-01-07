// ────────────────────────────────────────────────────────────────────────────
//  THINGS NOTIFIER
//
//  StateNotifier для управления списком вещей с пагинацией
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_service.dart';
import '../models/market_models.dart';
import 'things_state.dart';

/// Параметры для фильтрации вещей
class ThingsFilter {
  final String? search;
  final String? category; // 'Кроссовки', 'Часы', 'Одежда', 'Аксессуары'
  final Gender? gender;
  final int? sellerId; // ID продавца для фильтрации "Мои объявления"

  const ThingsFilter({
    this.search,
    this.category,
    this.gender,
    this.sellerId,
  });

  ThingsFilter copyWith({
    String? search,
    String? category,
    Gender? gender,
    int? sellerId,
  }) {
    return ThingsFilter(
      search: search ?? this.search,
      category: category ?? this.category,
      gender: gender ?? this.gender,
      sellerId: sellerId ?? this.sellerId,
    );
  }

  // ──── Равенство для правильной работы provider ────
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ThingsFilter &&
        other.search == search &&
        other.category == category &&
        other.gender == gender &&
        other.sellerId == sellerId;
  }

  @override
  int get hashCode => Object.hash(search, category, gender, sellerId);
}

/// StateNotifier для управления списком вещей
class ThingsNotifier extends StateNotifier<ThingsState> {
  final ApiService _api;
  ThingsFilter _filter;
  static const int _pageSize = 10;

  ThingsNotifier({
    required ApiService api,
    ThingsFilter? filter,
  })  : _api = api,
        _filter = filter ?? const ThingsFilter(),
        super(ThingsState.initial()) {
    // Автоматическая загрузка при создании
    loadInitial();
  }

  /// Загрузка начальной страницы (сброс списка)
  Future<void> loadInitial() async {
    if (state.isLoading) return; // Защита от повторных вызовов

    state = ThingsState.loading();

    try {
      final response = await _fetchThings(offset: 0, limit: _pageSize);

      state = ThingsState(
        items: response['things'] as List<GoodsItem>,
        isLoading: false,
        hasMore: response['hasMore'] as bool,
        total: response['total'] as int,
      );
    } catch (e) {
      debugPrint('❌ Ошибка загрузки вещей: $e');
      state = ThingsState.error(e.toString());
    }
  }

  /// Загрузка следующей страницы (добавление к существующему списку)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) {
      return; // Уже загружается или нет больше данных
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      final currentOffset = state.items.length;
      final response = await _fetchThings(offset: currentOffset, limit: _pageSize);

      final newThings = response['things'] as List<GoodsItem>;
      final updatedItems = [...state.items, ...newThings];

      state = state.copyWith(
        items: updatedItems,
        isLoadingMore: false,
        hasMore: response['hasMore'] as bool,
        total: response['total'] as int,
      );
    } catch (e) {
      debugPrint('❌ Ошибка загрузки дополнительных вещей: $e');
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  /// Обновление фильтра и перезагрузка данных
  Future<void> updateFilter(ThingsFilter newFilter) async {
    // Если фильтр не изменился, ничего не делаем
    if (_filter == newFilter) return;

    // Обновляем внутренний фильтр
    _filter = newFilter;
    
    // Перезагружаем данные с новым фильтром
    await loadInitial();
  }

  /// Загрузка вещей с API
  Future<Map<String, dynamic>> _fetchThings({
    required int offset,
    required int limit,
  }) async {
    // Формируем параметры запроса
    final Map<String, dynamic> params = {
      'offset': offset,
      'limit': limit,
    };

    if (_filter.search != null && _filter.search!.isNotEmpty) {
      params['search'] = _filter.search;
    }
    if (_filter.category != null && _filter.category!.isNotEmpty) {
      params['category'] = _filter.category;
    }
    if (_filter.gender != null) {
      params['gender'] = _filter.gender == Gender.male ? 'male' : 'female';
    }
    if (_filter.sellerId != null) {
      params['seller_id'] = _filter.sellerId;
    }

    // Выполняем запрос к API
    final response = await _api.post('/get_things.php', body: params);

    // Проверяем успешность ответа
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Ошибка загрузки вещей');
    }

    // Парсим список вещей
    final List<dynamic> thingsData = response['things'] ?? [];
    final things = thingsData.map((thing) => _parseThing(thing)).toList();

    return {
      'things': things,
      'hasMore': response['has_more'] ?? false,
      'total': response['total'] ?? 0,
    };
  }

  /// Парсит данные вещи из API в модель GoodsItem
  GoodsItem _parseThing(Map<String, dynamic> data) {
    // ── парсим gender (может быть null, 'male' или 'female')
    Gender? gender;
    final genderStr = data['gender'];
    if (genderStr == 'male') {
      gender = Gender.male;
    } else if (genderStr == 'female') {
      gender = Gender.female;
    } else {
      // Если gender не указан (выбрано "Любой"), оставляем null
      gender = null;
    }

    // ── парсим изображения (массив URL)
    final List<dynamic> imagesData = data['images'] ?? [];
    final images = imagesData.map((img) => img.toString()).toList();

    // ── если изображений нет, используем заглушку
    if (images.isEmpty) {
      images.add('https://uploads.paceup.ru/defaults/thing_placeholder.png');
    }

    return GoodsItem(
      id: data['id'] ?? 0,
      title: data['title'] ?? '',
      images: images,
      price: data['price'] ?? 0,
      gender: gender,
      city: data['city'] ?? 'Не указано',
      description: data['description'],
      sellerId: data['seller_id'] ?? 0,
      chatId: data['chat_id'],
    );
  }
}

