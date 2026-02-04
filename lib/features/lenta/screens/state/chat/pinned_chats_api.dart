// lib/features/lenta/screens/state/chat/pinned_chats_api.dart
// ─── API закреплённых чатов (события и клубы) для экрана «Чаты» ───
// Единое хранение в БД (user_pinned_chats): и события, и клубы используют
// один API (get_pinned_chats.php, set_pinned_chat.php) и работают одинаково.

import '../../../../../core/services/api_service.dart';
import '../../../../../core/services/auth_service.dart';

/// Один закреплённый чат (событие или клуб) из API.
class PinnedChatEntry {
  final String chatType; // 'event' | 'club'
  final int referenceId; // event_id или club_id
  final int chatId;
  final String title;
  final String? logoUrl;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final bool lastMessageHasImage;

  const PinnedChatEntry({
    required this.chatType,
    required this.referenceId,
    required this.chatId,
    required this.title,
    this.logoUrl,
    required this.lastMessage,
    this.lastMessageAt,
    this.lastMessageHasImage = false,
  });

  factory PinnedChatEntry.fromJson(Map<String, dynamic> json) {
    DateTime? lastMessageAt;
    final at = json['last_message_at'];
    if (at != null && at.toString().isNotEmpty) {
      try {
        lastMessageAt = DateTime.parse(at.toString());
      } catch (_) {}
    }
    return PinnedChatEntry(
      chatType: json['chat_type'] as String? ?? 'event',
      referenceId: (json['reference_id'] as num).toInt(),
      chatId: (json['chat_id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      logoUrl: json['logo_url'] as String?,
      lastMessage: json['last_message'] as String? ?? '',
      lastMessageAt: lastMessageAt,
      lastMessageHasImage: json['last_message_has_image'] as bool? ?? false,
    );
  }

  bool get isEvent => chatType == 'event';
  bool get isClub => chatType == 'club';
}

/// Запросы к API закреплённых чатов (get_pinned_chats, set_pinned_chat).
class PinnedChatsApi {
  PinnedChatsApi._();

  static final _api = ApiService();
  static final _auth = AuthService();

  /// Список закреплённых чатов пользователя (события и клубы).
  static Future<List<PinnedChatEntry>> getPinnedChats() async {
    final userId = await _auth.getUserId();
    if (userId == null) return [];
    final response = await _api.get(
      '/get_pinned_chats.php',
      queryParams: {'user_id': userId.toString()},
    );
    if (response['success'] != true) return [];
    final list = response['pinned_chats'] as List<dynamic>? ?? [];
    return list
        .map((e) => PinnedChatEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Добавить или обновить закреплённый чат.
  static Future<bool> addPinnedChat({
    required String chatType,
    required int referenceId,
    required int chatId,
    required String title,
    String? logoUrl,
    required String lastMessage,
    required DateTime lastMessageAt,
  }) async {
    final userId = await _auth.getUserId();
    if (userId == null) return false;
    final response = await _api.post(
      '/set_pinned_chat.php',
      body: {
        'action': 'add',
        'chat_type': chatType,
        'reference_id': referenceId,
        'chat_id': chatId,
        'title': title,
        'logo_url': logoUrl,
        'last_message': lastMessage,
        'last_message_at': lastMessageAt.toIso8601String(),
      },
    );
    return response['success'] == true;
  }

  /// Удалить закреплённый чат.
  static Future<bool> removePinnedChat({
    required String chatType,
    required int referenceId,
  }) async {
    final userId = await _auth.getUserId();
    if (userId == null) return false;
    final response = await _api.post(
      '/set_pinned_chat.php',
      body: {
        'action': 'remove',
        'chat_type': chatType,
        'reference_id': referenceId,
      },
    );
    return response['success'] == true;
  }

  /// Закреплён ли чат (по списку с сервера).
  static Future<bool> isPinned({
    required String chatType,
    required int referenceId,
  }) async {
    final list = await getPinnedChats();
    return list.any((e) =>
        e.chatType == chatType && e.referenceId == referenceId);
  }
}
