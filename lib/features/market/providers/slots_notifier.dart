// ────────────────────────────────────────────────────────────────────────────
//  SLOTS NOTIFIER
//
//  StateNotifier для управления списком слотов с пагинацией
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_service.dart';
import '../models/market_models.dart';
import 'slots_state.dart';

/// Параметры для фильтрации слотов
class SlotsFilter {
  final String? search;
  final Gender? gender;
  final String? status; // 'available', 'reserved', 'sold'
  final int? eventId; // Фильтр по ID события
  final int? userId; // Фильтр по ID пользователя (для "Мои")

  const SlotsFilter({
    this.search,
    this.gender,
    this.status,
    this.eventId,
    this.userId,
  });

  SlotsFilter copyWith({
    String? search,
    Gender? gender,
    String? status,
    int? eventId,
    int? userId,
  }) {
    return SlotsFilter(
      search: search ?? this.search,
      gender: gender ?? this.gender,
      status: status ?? this.status,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
    );
  }

  // ──── Равенство для правильной работы family provider ────
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SlotsFilter &&
        other.search == search &&
        other.gender == gender &&
        other.status == status &&
        other.eventId == eventId &&
        other.userId == userId;
  }

  @override
  int get hashCode => Object.hash(search, gender, status, eventId, userId);
}

/// StateNotifier для управления списком слотов
class SlotsNotifier extends StateNotifier<SlotsState> {
  final ApiService _api;
  SlotsFilter _filter; // Теперь изменяемый, чтобы можно было обновлять без пересоздания provider
  static const int _pageSize = 10;

  SlotsNotifier({
    required ApiService api,
    SlotsFilter? filter,
  })  : _api = api,
        _filter = filter ?? const SlotsFilter(),
        super(SlotsState.initial()) {
    // Автоматическая загрузка при создании
    loadInitial();
  }

  /// Загрузка начальной страницы (сброс списка)
  Future<void> loadInitial() async {
    if (state.isLoading) return; // Защита от повторных вызовов

    state = SlotsState.loading();

    try {
      final response = await _fetchSlots(offset: 0, limit: _pageSize);

      state = SlotsState(
        items: response['slots'] as List<MarketItem>,
        isLoading: false,
        hasMore: response['hasMore'] as bool,
        total: response['total'] as int,
      );
    } catch (e) {
      debugPrint('❌ Ошибка загрузки слотов: $e');
      state = SlotsState.error(e.toString());
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
      final response = await _fetchSlots(offset: currentOffset, limit: _pageSize);

      final newSlots = response['slots'] as List<MarketItem>;
      final updatedItems = [...state.items, ...newSlots];

      state = state.copyWith(
        items: updatedItems,
        isLoadingMore: false,
        hasMore: response['hasMore'] as bool,
        total: response['total'] as int,
      );
    } catch (e) {
      debugPrint('❌ Ошибка загрузки дополнительных слотов: $e');
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  /// Обновление фильтра и перезагрузка данных
  Future<void> updateFilter(SlotsFilter newFilter) async {
    // Если фильтр не изменился, ничего не делаем
    if (_filter == newFilter) return;

    // Обновляем внутренний фильтр
    _filter = newFilter;
    
    // Перезагружаем данные с новым фильтром
    await loadInitial();
  }

  /// Загрузка слотов с API
  Future<Map<String, dynamic>> _fetchSlots({
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
    if (_filter.gender != null) {
      params['gender'] = _filter.gender == Gender.male ? 'male' : 'female';
    }
    if (_filter.status != null && _filter.status!.isNotEmpty) {
      params['status'] = _filter.status;
    }
    // Фильтр по ID события
    if (_filter.eventId != null && _filter.eventId! > 0) {
      params['event_id'] = _filter.eventId;
    }
    // Фильтр по ID пользователя (для "Мои")
    if (_filter.userId != null && _filter.userId! > 0) {
      params['user_id'] = _filter.userId;
    }

    // Выполняем запрос к API
    final response = await _api.post('/get_slots.php', body: params);

    // Проверяем успешность ответа
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Ошибка загрузки слотов');
    }

    // Парсим список слотов
    final List<dynamic> slotsData = response['slots'] ?? [];
    final slots = slotsData.map((slot) => _parseSlot(slot)).toList();

    return {
      'slots': slots,
      'hasMore': response['has_more'] ?? false,
      'total': response['total'] ?? 0,
    };
  }

  /// Парсит данные слота из API в модель MarketItem
  MarketItem _parseSlot(Map<String, dynamic> data) {
    // Парсим gender
    final genderStr = data['gender'] ?? 'male';
    final gender = genderStr == 'female' ? Gender.female : Gender.male;

    // Получаем URL изображения
    final imageUrl = data['image_url'] ?? '';

    return MarketItem(
      id: data['id'] ?? 0,
      title: data['title'] ?? '',
      distance: data['distance'] ?? '',
      price: data['price'] ?? 0,
      gender: gender,
      buttonEnabled: data['button_enabled'] ?? true,
      buttonText: data['button_text'] ?? 'Купить',
      locked: data['locked'] ?? false,
      imageUrl: imageUrl,
      dateText: data['date_text'],
      placeText: data['place_text'],
      typeText: data['type_text'],
      description: data['description'],
      sellerId: data['seller_id'] ?? 0,
      eventId: data['event_id'],
      chatId: data['chat_id'],
    );
  }
}

