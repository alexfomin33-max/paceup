// ────────────────────────────────────────────────────────────────────────────
//  LENTA STATE
//
//  Модели состояния для ленты активностей
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import '../../models/activity_lenta.dart';

/// Состояние ленты активностей
@immutable
class LentaState {
  /// Список активностей
  final List<Activity> items;

  /// Текущая страница пагинации
  final int currentPage;

  /// Есть ли ещё данные для загрузки
  final bool hasMore;

  /// Идет ли загрузка следующей страницы
  final bool isLoadingMore;

  /// Идет ли полная перезагрузка (refresh)
  final bool isRefreshing;

  /// Уже просмотренные ID (для дедупликации)
  final Set<int> seenIds;

  /// Количество непрочитанных уведомлений
  final int unreadCount;

  /// Ошибка загрузки (если есть)
  final String? error;

  const LentaState({
    this.items = const [],
    this.currentPage = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.seenIds = const {},
    this.unreadCount = 0,
    this.error,
  });

  /// Начальное состояние
  ///
  /// ⚡ ОПТИМИЗАЦИЯ: начинаем с isRefreshing: true
  /// чтобы не мигал пустой экран при первой загрузке
  factory LentaState.initial() => const LentaState(
    items: [],
    currentPage: 1,
    hasMore: true,
    isLoadingMore: false,
    isRefreshing: true, // ← начинаем с loading state
    seenIds: {},
    unreadCount: 3, // по умолчанию 3 непрочитанных
  );

  /// Состояние загрузки
  LentaState copyWith({
    List<Activity>? items,
    int? currentPage,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isRefreshing,
    Set<int>? seenIds,
    int? unreadCount,
    String? error,
  }) {
    return LentaState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      seenIds: seenIds ?? this.seenIds,
      unreadCount: unreadCount ?? this.unreadCount,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LentaState &&
          runtimeType == other.runtimeType &&
          listEquals(items, other.items) &&
          currentPage == other.currentPage &&
          hasMore == other.hasMore &&
          isLoadingMore == other.isLoadingMore &&
          isRefreshing == other.isRefreshing &&
          setEquals(seenIds, other.seenIds) &&
          unreadCount == other.unreadCount &&
          error == other.error;

  @override
  int get hashCode => Object.hash(
    items,
    currentPage,
    hasMore,
    isLoadingMore,
    isRefreshing,
    seenIds,
    unreadCount,
    error,
  );
}
