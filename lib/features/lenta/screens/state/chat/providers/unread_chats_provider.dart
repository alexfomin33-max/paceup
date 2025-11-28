// ────────────────────────────────────────────────────────────────────────────
//  UNREAD CHATS PROVIDER
//
//  StateNotifierProvider для управления количеством непрочитанных чатов
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../providers/services/api_provider.dart';
import 'unread_chats_notifier.dart';
import 'unread_chats_state.dart';

/// Provider для количества непрочитанных чатов (зависит от userId)
///
/// Использование:
/// ```dart
/// final unreadState = ref.watch(unreadChatsProvider(userId));
///
/// // Загрузка количества непрочитанных чатов
/// ref.read(unreadChatsProvider(userId).notifier).loadUnreadCount();
///
/// // Сброс счетчика
/// ref.read(unreadChatsProvider(userId).notifier).reset();
/// ```
final unreadChatsProvider =
    StateNotifierProvider.family<UnreadChatsNotifier, UnreadChatsState, int>((
      ref,
      userId,
    ) {
      final api = ref.watch(apiServiceProvider);
      return UnreadChatsNotifier(api: api, userId: userId);
    });
