// ────────────────────────────────────────────────────────────────────────────
//  BOOKMARKED EVENTS STATE
//
//  Модель состояния для списка событий из закладок пользователя
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import '../../../../domain/models/event.dart';

/// Состояние списка событий из закладок пользователя
@immutable
class BookmarkedEventsState {
  /// Список событий из закладок
  final List<Event> events;

  /// Идет ли загрузка
  final bool isLoading;

  /// Идет ли обновление (refresh)
  final bool isRefreshing;

  /// Ошибка загрузки (если есть)
  final String? error;

  const BookmarkedEventsState({
    this.events = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  });

  /// Начальное состояние
  factory BookmarkedEventsState.initial() => const BookmarkedEventsState(
    events: [],
    isLoading: true, // начинаем с loading state
    isRefreshing: false,
  );

  /// Состояние загрузки
  BookmarkedEventsState copyWith({
    List<Event>? events,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
  }) {
    return BookmarkedEventsState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookmarkedEventsState &&
          runtimeType == other.runtimeType &&
          listEquals(events, other.events) &&
          isLoading == other.isLoading &&
          isRefreshing == other.isRefreshing &&
          error == other.error;

  @override
  int get hashCode => Object.hash(events, isLoading, isRefreshing, error);
}

