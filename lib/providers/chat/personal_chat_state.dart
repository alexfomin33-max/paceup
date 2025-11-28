// ────────────────────────────────────────────────────────────────────────────
//  PERSONAL CHAT STATE
//
//  Модель состояния для экрана персонального чата
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import '../../screens/lenta/state/chat/personal_chat_screen.dart';

/// Состояние экрана персонального чата
@immutable
class PersonalChatState {
  /// Список сообщений
  final List<ChatMessage> messages;

  /// Идет ли загрузка начальных сообщений
  final bool isLoading;

  /// Идет ли загрузка старых сообщений (при прокрутке вверх)
  final bool isLoadingMore;

  /// Есть ли еще сообщения для загрузки
  final bool hasMore;

  /// Смещение для пагинации
  final int offset;

  /// ID текущего пользователя
  final int? currentUserId;

  /// ID последнего сообщения (для polling)
  final int? lastMessageId;

  /// Ошибка (если есть)
  final String? error;

  /// Реальный chatId (создается если widget.chatId = 0)
  final int? actualChatId;

  const PersonalChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.offset = 0,
    this.currentUserId,
    this.lastMessageId,
    this.error,
    this.actualChatId,
  });

  /// Начальное состояние
  static PersonalChatState initial() => const PersonalChatState();

  /// Копирование состояния с обновлением полей
  PersonalChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? offset,
    int? currentUserId,
    int? lastMessageId,
    String? error,
    int? actualChatId,
    bool clearError = false,
    bool clearMessages = false,
  }) {
    return PersonalChatState(
      messages: clearMessages ? const [] : (messages ?? this.messages),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
      currentUserId: currentUserId ?? this.currentUserId,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      error: clearError ? null : (error ?? this.error),
      actualChatId: actualChatId ?? this.actualChatId,
    );
  }
}

