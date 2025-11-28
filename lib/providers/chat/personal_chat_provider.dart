// ────────────────────────────────────────────────────────────────────────────
//  PERSONAL CHAT PROVIDER
//
//  StateNotifierProvider для управления состоянием персонального чата
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_provider.dart';
import '../services/auth_provider.dart';
import 'personal_chat_notifier.dart';
import 'personal_chat_state.dart';

/// Provider для PersonalChat (зависит от chatId и userId)
///
/// Использование:
/// ```dart
/// final chatState = ref.watch(personalChatProvider(chatId: chatId, userId: userId));
///
/// // Инициализация чата
/// ref.read(personalChatProvider(chatId: chatId, userId: userId).notifier).initChat();
///
/// // Отправка сообщения
/// ref.read(personalChatProvider(chatId: chatId, userId: userId).notifier).sendText(text);
/// ```
final personalChatProvider = StateNotifierProvider.family<
    PersonalChatNotifier,
    PersonalChatState,
    PersonalChatArgs>((ref, args) {
  final api = ref.watch(apiServiceProvider);
  final auth = ref.watch(authServiceProvider);
  final notifier = PersonalChatNotifier(
    api: api,
    auth: auth,
    chatId: args.chatId,
    userId: args.userId,
  );

  // Автоматическая инициализация при создании провайдера
  Future.microtask(() => notifier.initChat());

  return notifier;
});

/// Аргументы для PersonalChatProvider
class PersonalChatArgs {
  final int chatId;
  final int userId;

  const PersonalChatArgs({
    required this.chatId,
    required this.userId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonalChatArgs &&
          runtimeType == other.runtimeType &&
          chatId == other.chatId &&
          userId == other.userId;

  @override
  int get hashCode => chatId.hashCode ^ userId.hashCode;
}

