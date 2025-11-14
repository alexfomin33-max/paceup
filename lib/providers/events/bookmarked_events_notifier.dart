// ────────────────────────────────────────────────────────────────────────────
//  BOOKMARKED EVENTS NOTIFIER
//
//  StateNotifier для управления списком событий из закладок пользователя
//  Возможности:
//  • Начальная загрузка событий из закладок
//  • Pull-to-refresh
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../service/api_service.dart';
import '../../models/event.dart';
import 'bookmarked_events_state.dart';

class BookmarkedEventsNotifier extends StateNotifier<BookmarkedEventsState> {
  final ApiService _api;
  final int userId;

  BookmarkedEventsNotifier({
    required ApiService api,
    required this.userId,
  })  : _api = api,
        super(BookmarkedEventsState.initial());

  /// Загрузка событий из закладок через API
  Future<List<Event>> _loadEvents() async {
    final data = await _api.post(
      '/get_bookmarked_events.php',
      timeout: const Duration(seconds: 15),
    );

    final List rawList = data['events'] as List? ?? const [];
    
    final events = rawList
        .whereType<Map<String, dynamic>>()
        .map(Event.fromApi)
        .toList();

    return events;
  }

  /// Начальная загрузка событий из закладок
  Future<void> loadInitial() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final events = await _loadEvents();

      state = state.copyWith(
        events: events,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  /// Pull-to-refresh (обновление списка)
  Future<void> refresh() async {
    try {
      state = state.copyWith(isRefreshing: true, error: null);

      final events = await _loadEvents();

      state = state.copyWith(
        events: events,
        isRefreshing: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isRefreshing: false,
      );
    }
  }

  /// Удаление события из закладок
  /// Удаляет событие через API и динамически убирает его из списка
  Future<bool> removeBookmark(int eventId) async {
    try {
      // Вызываем API для удаления из закладок
      final data = await _api.post(
        '/toggle_event_bookmark.php',
        body: {'event_id': eventId},
        timeout: const Duration(seconds: 15),
      );

      if (data['success'] == true) {
        // Удаляем событие из локального списка динамически
        final updatedEvents = state.events
            .where((event) => event.id != eventId)
            .toList();

        state = state.copyWith(
          events: updatedEvents,
          error: null,
        );

        return true;
      } else {
        state = state.copyWith(
          error: data['message']?.toString() ?? 'Ошибка удаления из закладок',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
      );
      return false;
    }
  }
}

