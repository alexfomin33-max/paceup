// ────────────────────────────────────────────────────────────────────────────
//  CHAT PARTNER IDS PROVIDER
//
//  Возвращает множество user_id пользователей, с которыми у текущего
//  пользователя уже есть личный (regular) чат. Используется на экране
//  «Начать общение» для клиентской фильтрации (дополнение к серверной).
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../providers/services/api_provider.dart';
import '../../../../../../providers/services/auth_provider.dart';

/// Множество ID пользователей, с которыми уже есть личный чат.
/// Загружает get_chats.php и извлекает user_id из чатов с chat_type == 'regular'.
final chatPartnerIdsProvider = FutureProvider<Set<int>>((ref) async {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) return <int>{};

  final api = ref.watch(apiServiceProvider);
  final response = await api.get(
    '/get_chats.php',
    queryParams: {
      'user_id': userId.toString(),
      'offset': '0',
      'limit': '100',
    },
  );

  if (response['success'] != true) return <int>{};

  final List<dynamic> chats = response['chats'] as List<dynamic>? ?? [];
  final Set<int> partnerIds = {};
  for (final c in chats) {
    if (c is! Map<String, dynamic>) continue;
    final chatType = c['chat_type'] as String? ?? '';
    if (chatType != 'regular') continue;
    final uid = c['user_id'];
    if (uid != null) {
      partnerIds.add((uid is num) ? uid.toInt() : int.tryParse(uid.toString()) ?? 0);
    }
  }
  return partnerIds;
});
