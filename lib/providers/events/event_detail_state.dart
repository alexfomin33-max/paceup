// ────────────────────────────────────────────────────────────────────────────
//  EVENT DETAIL STATE
//
//  Модель состояния для экрана детальной информации о событии
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

/// Состояние экрана детальной информации о событии
@immutable
class EventDetailState {
  /// Данные события (JSON из API)
  final Map<String, dynamic>? eventData;

  /// Идет ли загрузка данных
  final bool isLoading;

  /// Ошибка загрузки (если есть)
  final String? error;

  /// Права на редактирование (только создатель может редактировать)
  final bool canEdit;

  /// Является ли текущий пользователь участником события
  final bool isParticipant;

  /// Идет ли процесс присоединения/выхода из события
  final bool isTogglingParticipation;

  /// Находится ли событие в закладках
  final bool isBookmarked;

  /// Идет ли процесс добавления/удаления закладки
  final bool isTogglingBookmark;

  /// Текущая вкладка (0 — Описание, 1 — Участники)
  final int tab;

  const EventDetailState({
    this.eventData,
    this.isLoading = true,
    this.error,
    this.canEdit = false,
    this.isParticipant = false,
    this.isTogglingParticipation = false,
    this.isBookmarked = false,
    this.isTogglingBookmark = false,
    this.tab = 0,
  });

  /// Начальное состояние
  static EventDetailState initial() => const EventDetailState();

  /// Копирование состояния с обновлением полей
  EventDetailState copyWith({
    Map<String, dynamic>? eventData,
    bool? isLoading,
    String? error,
    bool? canEdit,
    bool? isParticipant,
    bool? isTogglingParticipation,
    bool? isBookmarked,
    bool? isTogglingBookmark,
    int? tab,
    bool clearError = false,
  }) {
    return EventDetailState(
      eventData: eventData ?? this.eventData,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      canEdit: canEdit ?? this.canEdit,
      isParticipant: isParticipant ?? this.isParticipant,
      isTogglingParticipation:
          isTogglingParticipation ?? this.isTogglingParticipation,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isTogglingBookmark: isTogglingBookmark ?? this.isTogglingBookmark,
      tab: tab ?? this.tab,
    );
  }
}

