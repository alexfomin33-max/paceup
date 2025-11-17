// ────────────────────────────────────────────────────────────────────────────
//  UNREAD CHATS STATE
//
//  Состояние для отслеживания количества непрочитанных чатов
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

/// Состояние непрочитанных чатов
@immutable
class UnreadChatsState {
  /// Количество непрочитанных чатов
  final int unreadCount;

  /// Идет ли загрузка
  final bool isLoading;

  /// Ошибка загрузки (если есть)
  final String? error;

  const UnreadChatsState({
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  /// Начальное состояние
  factory UnreadChatsState.initial() => const UnreadChatsState(
        unreadCount: 0,
        isLoading: false,
      );

  /// Состояние загрузки
  factory UnreadChatsState.loading() => const UnreadChatsState(
        unreadCount: 0,
        isLoading: true,
      );

  /// Состояние с ошибкой
  factory UnreadChatsState.error(String message) => UnreadChatsState(
        unreadCount: 0,
        isLoading: false,
        error: message,
      );

  /// Копирование состояния
  UnreadChatsState copyWith({
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) {
    return UnreadChatsState(
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnreadChatsState &&
          runtimeType == other.runtimeType &&
          unreadCount == other.unreadCount &&
          isLoading == other.isLoading &&
          error == other.error;

  @override
  int get hashCode => Object.hash(unreadCount, isLoading, error);
}

