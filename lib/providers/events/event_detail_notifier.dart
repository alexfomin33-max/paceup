// ────────────────────────────────────────────────────────────────────────────
//  EVENT DETAIL NOTIFIER
//
//  StateNotifier для управления состоянием экрана детальной информации о событии
//  Возможности:
//  • Загрузка данных события
//  • Добавление/удаление из закладок
//  • Присоединение/выход из события
//  • Переключение вкладок
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/error_handler.dart';
import 'event_detail_state.dart';

class EventDetailNotifier extends StateNotifier<EventDetailState> {
  final ApiService _api;
  final AuthService _auth;
  final int eventId;

  EventDetailNotifier({
    required ApiService api,
    required AuthService auth,
    required this.eventId,
  })  : _api = api,
        _auth = auth,
        super(EventDetailState.initial());

  /// Загрузка данных события через API
  Future<void> loadEvent() async {
    try {
      state = state.copyWith(isLoading: true, error: null, clearError: true);

      final userId = await _auth.getUserId();

      final data = await _api.get(
        '/get_events.php',
        queryParams: {'event_id': eventId.toString()},
      );

      if (data['success'] == true && data['event'] != null) {
        final event = data['event'] as Map<String, dynamic>;

        // Проверяем права на редактирование: только создатель может редактировать
        final eventUserId = event['user_id'] as int?;
        final canEdit = userId != null && eventUserId == userId;

        // Проверяем, является ли текущий пользователь участником
        final participants = event['participants'] as List<dynamic>? ?? [];
        bool isParticipant = false;
        if (userId != null) {
          for (final p in participants) {
            final pMap = p as Map<String, dynamic>;
            final pUserId = pMap['user_id'] as int?;
            if (pUserId == userId) {
              isParticipant = true;
              break;
            }
          }
        }

        // Проверяем статус закладки
        final isBookmarked = event['is_bookmarked'] as bool? ?? false;

        state = state.copyWith(
          eventData: event,
          canEdit: canEdit,
          isParticipant: isParticipant,
          isBookmarked: isBookmarked,
          isLoading: false,
          error: null,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          error: data['message'] as String? ?? 'Событие не найдено',
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        error: ErrorHandler.format(e),
        isLoading: false,
      );
    }
  }

  /// Добавление/удаление из закладок
  Future<bool> toggleBookmark() async {
    if (state.isTogglingBookmark || state.eventData == null) {
      return false;
    }

    // Проверяем, что userId доступен
    final userId = await _auth.getUserId();
    if (userId == null) {
      state = state.copyWith(
        error: 'Пользователь не авторизован',
      );
      return false;
    }

    state = state.copyWith(isTogglingBookmark: true);

    try {
      final data = await _api.post(
        '/toggle_event_bookmark.php',
        body: {'event_id': eventId},
      );

      if (data['success'] == true) {
        final isBookmarked = data['is_bookmarked'] as bool? ?? false;

        // Обновляем состояние
        state = state.copyWith(
          isBookmarked: isBookmarked,
          isTogglingBookmark: false,
        );

        // Обновляем данные события
        if (state.eventData != null) {
          state = state.copyWith(
            eventData: {
              ...state.eventData!,
              'is_bookmarked': isBookmarked,
            },
          );
        }

        return true;
      } else {
        final errorMessage =
            data['message'] as String? ?? 'Неизвестная ошибка';
        state = state.copyWith(
          isTogglingBookmark: false,
          error: errorMessage,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isTogglingBookmark: false,
        error: ErrorHandler.format(e),
      );
      return false;
    }
  }

  /// Присоединение/выход из события
  Future<bool> toggleParticipation() async {
    if (state.isTogglingParticipation || state.eventData == null) {
      return false;
    }

    // Проверяем, что userId доступен
    final userId = await _auth.getUserId();
    if (userId == null) {
      state = state.copyWith(
        error: 'Пользователь не авторизован',
      );
      return false;
    }

    state = state.copyWith(isTogglingParticipation: true);

    try {
      final action = state.isParticipant ? 'leave' : 'join';

      final data = await _api.post(
        '/join_event.php',
        body: {'event_id': eventId, 'action': action},
      );

      if (data['success'] == true) {
        final isParticipant = data['is_participant'] as bool? ?? false;
        final participantsCount = data['participants_count'] as int? ?? 0;

        // Обновляем состояние
        state = state.copyWith(
          isParticipant: isParticipant,
          isTogglingParticipation: false,
        );

        // Обновляем счетчик участников в данных события
        if (state.eventData != null) {
          state = state.copyWith(
            eventData: {
              ...state.eventData!,
              'participants_count': participantsCount,
            },
          );
        }

        return true;
      } else {
        final errorMessage =
            data['message'] as String? ?? 'Неизвестная ошибка';
        state = state.copyWith(
          isTogglingParticipation: false,
          error: errorMessage,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isTogglingParticipation: false,
        error: ErrorHandler.format(e),
      );
      return false;
    }
  }

  /// Переключение вкладки (0 — Описание, 1 — Участники)
  void setTab(int tab) {
    if (tab == 0 || tab == 1) {
      state = state.copyWith(tab: tab);
    }
  }

  /// Обновление данных события (после редактирования)
  Future<void> reload() async {
    await loadEvent();
  }
}

