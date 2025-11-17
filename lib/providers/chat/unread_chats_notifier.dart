// ────────────────────────────────────────────────────────────────────────────
//  UNREAD CHATS NOTIFIER
//
//  StateNotifier для управления количеством непрочитанных чатов
//  Загружает список чатов через API и подсчитывает количество с unread: true
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../service/api_service.dart';
import 'unread_chats_state.dart';

class UnreadChatsNotifier extends StateNotifier<UnreadChatsState> {
  final ApiService _api;
  final int userId;

  UnreadChatsNotifier({
    required ApiService api,
    required this.userId,
  })  : _api = api,
        super(UnreadChatsState.initial());

  /// Загрузка количества непрочитанных чатов
  ///
  /// Загружает первую страницу чатов (limit=100 для получения всех)
  /// и подсчитывает количество чатов с unread: true
  ///
  /// ⚡ ANTI-FLICKER: сохраняет предыдущее значение unreadCount во время загрузки,
  /// чтобы индикатор не мигал (не пропадал на время обновления)
  ///
  /// Использует copyWith вместо UnreadChatsState.loading(), чтобы сохранить
  /// предыдущее значение unreadCount (copyWith не меняет unreadCount, если не указан явно)
  Future<void> loadUnreadCount() async {
    // Устанавливаем состояние загрузки, но сохраняем предыдущее значение счетчика
    // copyWith сохраняет текущее значение unreadCount, если не указано новое
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Загружаем список чатов (limit=100 для получения всех чатов)
      // В реальном приложении можно создать отдельный endpoint для получения только количества,
      // но для простоты используем существующий API
      final response = await _api.get(
        '/get_chats.php',
        queryParams: {
          'user_id': userId.toString(),
          'offset': '0',
          'limit': '100', // Достаточно для большинства пользователей
        },
      );

      if (response['success'] == true) {
        final List<dynamic> chatsJson = response['chats'] as List<dynamic>? ?? [];

        // Подсчитываем количество чатов с unread: true
        int unreadCount = 0;
        for (final chatJson in chatsJson) {
          if (chatJson is Map<String, dynamic>) {
            final unread = chatJson['unread'] as bool? ?? false;
            if (unread) {
              unreadCount++;
            }
          }
        }

        state = state.copyWith(
          unreadCount: unreadCount,
          isLoading: false,
          error: null,
        );
      } else {
        // При ошибке сохраняем предыдущее значение счетчика, чтобы индикатор не пропал
        state = state.copyWith(
          isLoading: false,
          error: response['message'] as String? ?? 'Ошибка загрузки чатов',
        );
      }
    } catch (e) {
      // При ошибке сохраняем предыдущее значение счетчика, чтобы индикатор не пропал
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Установка количества непрочитанных чатов вручную
  /// (используется после открытия чата для обновления счетчика)
  void setUnreadCount(int count) {
    state = state.copyWith(unreadCount: count, isLoading: false, error: null);
  }

  /// Сброс счетчика непрочитанных чатов
  void reset() {
    state = UnreadChatsState.initial();
  }
}

