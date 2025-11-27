// ────────────────────────────────────────────────────────────────────────────
//  MY EVENTS STATE
//
//  Модель состояния для списка событий пользователя
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import '../../core/models/event.dart';

/// Состояние списка событий пользователя
@immutable
class MyEventsState {
  /// Список событий
  final List<Event> events;

  /// Идет ли загрузка
  final bool isLoading;

  /// Идет ли обновление (refresh)
  final bool isRefreshing;

  /// Ошибка загрузки (если есть)
  final String? error;

  const MyEventsState({
    this.events = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  });

  /// Начальное состояние
  factory MyEventsState.initial() => const MyEventsState(
    events: [],
    isLoading: true, // начинаем с loading state
    isRefreshing: false,
  );

  /// Состояние загрузки
  MyEventsState copyWith({
    List<Event>? events,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
  }) {
    return MyEventsState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MyEventsState &&
          runtimeType == other.runtimeType &&
          listEquals(events, other.events) &&
          isLoading == other.isLoading &&
          isRefreshing == other.isRefreshing &&
          error == other.error;

  @override
  int get hashCode => Object.hash(events, isLoading, isRefreshing, error);
}
