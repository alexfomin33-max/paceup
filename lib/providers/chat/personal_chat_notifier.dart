// ────────────────────────────────────────────────────────────────────────────
//  PERSONAL CHAT NOTIFIER
//
//  StateNotifier для управления состоянием персонального чата
//  Возможности:
//  • Инициализация чата
//  • Создание нового чата
//  • Загрузка сообщений (начальная и пагинация)
//  • Отправка текстовых сообщений
//  • Отправка изображений
//  • Проверка новых сообщений (polling)
//  • Отметка сообщений как прочитанных
// ────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/error_handler.dart';
import '../../screens/lenta/state/chat/personal_chat_screen.dart';
import 'personal_chat_state.dart';

class PersonalChatNotifier extends StateNotifier<PersonalChatState> {
  final ApiService _api;
  final AuthService _auth;
  final int chatId; // widget.chatId (может быть 0 для нового чата)
  final int userId; // ID собеседника

  PersonalChatNotifier({
    required ApiService api,
    required AuthService auth,
    required this.chatId,
    required this.userId,
  })  : _api = api,
        _auth = auth,
        super(PersonalChatState.initial());

  /// Инициализация чата
  Future<void> initChat() async {
    final currentUserId = await _auth.getUserId();
    if (currentUserId == null) {
      state = state.copyWith(
        error: 'Пользователь не авторизован',
      );
      return;
    }

    state = state.copyWith(currentUserId: currentUserId);

    // Если chatId = 0, создаем новый чат
    if (chatId == 0) {
      await createChat();
    } else {
      state = state.copyWith(actualChatId: chatId);
      await loadInitial();
    }
  }

  /// Создание нового чата
  Future<bool> createChat() async {
    if (state.currentUserId == null) return false;

    state = state.copyWith(isLoading: true, error: null, clearError: true);

    try {
      final response = await _api.post(
        '/create_chat.php',
        body: {'user2_id': userId},
      );

      if (response['success'] == true) {
        final actualChatId = response['chat_id'] as int;

        state = state.copyWith(
          actualChatId: actualChatId,
          isLoading: false,
        );

        // После создания чата загружаем сообщения
        await loadInitial();
        return true;
      } else {
        state = state.copyWith(
          error: response['message'] as String? ?? 'Ошибка создания чата',
          isLoading: false,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        error: ErrorHandler.format(e),
        isLoading: false,
      );
      return false;
    }
  }

  /// Загрузка начальных сообщений
  Future<void> loadInitial() async {
    if (state.isLoading || state.currentUserId == null) return;

    // Если чат еще не создан, не загружаем сообщения
    final actualChatId = state.actualChatId ?? chatId;
    if (actualChatId == 0) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
      clearError: true,
      offset: 0,
    );

    try {
      final response = await _api.get(
        '/get_messages.php',
        queryParams: {
          'chat_id': actualChatId.toString(),
          'user_id': state.currentUserId.toString(),
          'offset': '0',
          'limit': '50',
        },
      );

      if (response['success'] == true) {
        final List<dynamic> messagesJson =
            response['messages'] as List<dynamic>;
        final messages = messagesJson
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();

        // Обновляем last_message_id (берем самый последний ID)
        int? lastMessageId;
        if (messages.isNotEmpty) {
          lastMessageId = messages
              .map((m) => m.id)
              .reduce((a, b) => a > b ? a : b);
        } else {
          lastMessageId = 0;
        }

        state = state.copyWith(
          messages: messages,
          hasMore: response['has_more'] as bool? ?? false,
          offset: messages.length,
          isLoading: false,
          lastMessageId: lastMessageId,
        );
      } else {
        state = state.copyWith(
          error:
              response['message'] as String? ?? 'Ошибка загрузки сообщений',
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

  /// Загрузка старых сообщений (при прокрутке вверх)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.currentUserId == null) {
      return;
    }

    final actualChatId = state.actualChatId ?? chatId;
    if (actualChatId == 0) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await _api.get(
        '/get_messages.php',
        queryParams: {
          'chat_id': actualChatId.toString(),
          'user_id': state.currentUserId.toString(),
          'offset': state.offset.toString(),
          'limit': '50',
        },
      );

      if (response['success'] == true) {
        final List<dynamic> messagesJson =
            response['messages'] as List<dynamic>;
        final newMessages = messagesJson
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();

        final updatedMessages = [...newMessages, ...state.messages];

        state = state.copyWith(
          messages: updatedMessages,
          hasMore: response['has_more'] as bool? ?? false,
          offset: state.offset + newMessages.length,
          isLoadingMore: false,
        );
      } else {
        state = state.copyWith(isLoadingMore: false);
      }
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Отправка текстового сообщения
  Future<bool> sendText(String text) async {
    if (text.trim().isEmpty || state.currentUserId == null) return false;

    final messageText = text.trim();

    // Оптимистичное обновление UI
    final tempMessage = ChatMessage(
      id: -1, // Временный ID
      senderId: state.currentUserId!,
      text: messageText,
      createdAt: DateTime.now(),
      isMine: true,
      isRead: false,
    );

    state = state.copyWith(
      messages: [...state.messages, tempMessage],
    );

    // Если чат еще не создан, создаем его перед отправкой сообщения
    int actualChatId = state.actualChatId ?? chatId;
    if (actualChatId == 0 && state.currentUserId != null) {
      final created = await createChat();
      if (!created) {
        // Удаляем временное сообщение при ошибке
        state = state.copyWith(
          messages: state.messages.where((m) => m.id != -1).toList(),
        );
        return false;
      }
      actualChatId = state.actualChatId ?? 0;
    }

    if (actualChatId == 0) {
      // Удаляем временное сообщение при ошибке
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != -1).toList(),
      );
      return false;
    }

    try {
      final response = await _api.post(
        '/send_message.php',
        body: {
          'chat_id': actualChatId,
          'user_id': state.currentUserId,
          'text': messageText,
        },
      );

      if (response['success'] == true) {
        final messageId = response['message_id'] as int;
        final createdAt = DateTime.parse(response['created_at'] as String);

        // Обновляем временное сообщение с реальными данными
        final updatedMessages = state.messages.map((m) {
          if (m.id == -1) {
            return ChatMessage(
              id: messageId,
              senderId: state.currentUserId!,
              text: messageText,
              createdAt: createdAt,
              isMine: true,
              isRead: false,
            );
          }
          return m;
        }).toList();

        state = state.copyWith(
          messages: updatedMessages,
          lastMessageId: messageId,
        );
        return true;
      } else {
        // Удаляем временное сообщение при ошибке
        state = state.copyWith(
          messages: state.messages.where((m) => m.id != -1).toList(),
        );
        return false;
      }
    } catch (e) {
      // Удаляем временное сообщение при ошибке
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != -1).toList(),
      );
      return false;
    }
  }

  /// Отправка изображения
  Future<bool> sendImage(File imageFile) async {
    if (state.currentUserId == null) return false;

    // Если чат еще не создан, создаем его перед отправкой изображения
    int actualChatId = state.actualChatId ?? chatId;
    if (actualChatId == 0) {
      final created = await createChat();
      if (!created) return false;
      actualChatId = state.actualChatId ?? 0;
    }

    if (actualChatId == 0) return false;

    try {
      // Загружаем изображение на сервер
      final uploadResponse = await _api.postMultipart(
        '/upload_chat_image.php',
        files: {'image': imageFile},
        fields: {
          'chat_id': actualChatId.toString(),
          'user_id': state.currentUserId.toString(),
        },
      );

      if (uploadResponse['success'] == true) {
        final imagePath = uploadResponse['image_path'] as String;

        // Отправляем сообщение с изображением
        final response = await _api.post(
          '/send_message.php',
          body: {
            'chat_id': actualChatId,
            'user_id': state.currentUserId,
            'text': '', // Пустой текст для сообщения с изображением
            'image': imagePath, // Относительный путь к изображению
          },
        );

        if (response['success'] == true) {
          final messageId = response['message_id'] as int;

          // Обновляем last_message_id - polling сам добавит сообщение
          state = state.copyWith(lastMessageId: messageId);
          return true;
        }
        return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Проверка новых сообщений (для polling)
  Future<void> checkNewMessages() async {
    if (state.currentUserId == null) return;

    final actualChatId = state.actualChatId ?? chatId;
    if (actualChatId == 0) return;

    // Если last_message_id еще не установлен, используем 0
    final lastId = state.lastMessageId ?? 0;

    try {
      final response = await _api.get(
        '/check_new_messages.php',
        queryParams: {
          'chat_id': actualChatId.toString(),
          'user_id': state.currentUserId.toString(),
          'last_message_id': lastId.toString(),
        },
      );

      if (response['success'] == true && response['has_new'] == true) {
        final List<dynamic> newMessagesJson =
            response['new_messages'] as List<dynamic>;
        final newMessages = newMessagesJson
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();

        if (newMessages.isNotEmpty) {
          // Обновляем last_message_id на максимальный ID среди новых сообщений
          final maxNewId = newMessages
              .map((m) => m.id)
              .reduce((a, b) => a > b ? a : b);

          // Дедупликация: добавляем только новые сообщения
          final existingIds = state.messages.map((m) => m.id).toSet();
          final uniqueNewMessages = newMessages
              .where((m) => !existingIds.contains(m.id))
              .toList();

          if (uniqueNewMessages.isNotEmpty) {
            state = state.copyWith(
              messages: [...state.messages, ...uniqueNewMessages],
              lastMessageId: maxNewId > lastId ? maxNewId : state.lastMessageId,
            );
          }
        }
      }
    } catch (e) {
      // Игнорируем ошибки polling
    }
  }

  /// Отметка сообщений как прочитанных
  Future<void> markMessagesAsRead() async {
    if (state.currentUserId == null) return;

    final actualChatId = state.actualChatId ?? chatId;
    if (actualChatId == 0) return;

    try {
      await _api.post(
        '/mark_messages_read.php',
        body: {
          'chat_id': actualChatId.toString(),
          'user_id': state.currentUserId.toString(),
        },
      );

      // Обновляем статус сообщений в состоянии
      final updatedMessages = state.messages.map((m) {
        if (!m.isMine && !m.isRead) {
          return ChatMessage(
            id: m.id,
            senderId: m.senderId,
            text: m.text,
            image: m.image,
            createdAt: m.createdAt,
            isMine: m.isMine,
            isRead: true,
          );
        }
        return m;
      }).toList();

      state = state.copyWith(messages: updatedMessages);
    } catch (e) {
      // Игнорируем ошибки
    }
  }
}

