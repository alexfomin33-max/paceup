// ────────────────────────────────────────────────────────────────────────────
//  MY EVENTS NOTIFIER
//
//  StateNotifier для управления списком событий пользователя
//  Возможности:
//  • Начальная загрузка событий
//  • Pull-to-refresh
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../service/api_service.dart';
import '../../models/event.dart';
import 'my_events_state.dart';

class MyEventsNotifier extends StateNotifier<MyEventsState> {
  final ApiService _api;
  final int userId;

  MyEventsNotifier({
    required ApiService api,
    required this.userId,
  })  : _api = api,
        super(MyEventsState.initial());

  /// Загрузка событий через API
  Future<List<Event>> _loadEvents() async {
    final data = await _api.post(
      '/get_my_events.php',
      timeout: const Duration(seconds: 15),
    );

    final List rawList = data['events'] as List? ?? const [];
    
    final events = rawList
        .whereType<Map<String, dynamic>>()
        .map(Event.fromApi)
        .toList();

    return events;
  }

  /// Начальная загрузка событий
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
}

