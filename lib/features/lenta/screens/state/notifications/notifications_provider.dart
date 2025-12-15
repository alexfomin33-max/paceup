// ─────────────────────────────────────────────────────────────────────────────
// ПРОВАЙДЕР ДЛЯ УВЕДОМЛЕНИЙ
//
// Управляет получением, отображением и отметкой уведомлений как прочитанных
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../../../providers/services/auth_provider.dart';

/// Модель уведомления
class NotificationItem {
  final int id;
  final int senderId;
  final String senderName;
  final String senderAvatar;
  final String notificationType;
  final String notificationTypeName;
  final String icon;
  final String color;
  final String objectType;
  final int objectId;
  final String text;
  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.notificationType,
    required this.notificationTypeName,
    required this.icon,
    required this.color,
    required this.objectType,
    required this.objectId,
    required this.text,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as int,
      senderId: json['sender_id'] as int,
      senderName: json['sender_name'] as String,
      senderAvatar: json['sender_avatar'] as String,
      notificationType: json['notification_type'] as String,
      notificationTypeName: json['notification_type_name'] as String,
      icon: json['icon'] as String,
      color: json['color'] as String,
      objectType: json['object_type'] as String,
      objectId: json['object_id'] as int,
      text: json['text'] as String,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Модель состояния списка уведомлений
@immutable
class NotificationsState {
  final List<NotificationItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final int total;
  final int unreadCount;

  const NotificationsState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.total = 0,
    this.unreadCount = 0,
  });

  NotificationsState copyWith({
    List<NotificationItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    int? total,
    int? unreadCount,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      total: total ?? this.total,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationsState &&
          runtimeType == other.runtimeType &&
          listEquals(items, other.items) &&
          isLoading == other.isLoading &&
          isLoadingMore == other.isLoadingMore &&
          hasMore == other.hasMore &&
          error == other.error &&
          total == other.total &&
          unreadCount == other.unreadCount;

  @override
  int get hashCode =>
      items.hashCode ^
      isLoading.hashCode ^
      isLoadingMore.hashCode ^
      hasMore.hashCode ^
      error.hashCode ^
      total.hashCode ^
      unreadCount.hashCode;
}

/// Notifier для управления уведомлениями
class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this._api, this._auth) : super(const NotificationsState());

  final dynamic _api;
  final dynamic _auth;
  int _offset = 0;
  static const int _limit = 25;

  /// Загрузка начальных уведомлений
  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, error: null, items: []);
    _offset = 0;

    try {
      final userId = await _auth.getUserId();
      if (userId == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Пользователь не авторизован',
        );
        return;
      }

      final data = await _api.post(
        '/get_notifications.php',
        body: {
          'user_id': userId,
          'offset': _offset,
          'limit': _limit,
        },
      );

      final notifications = (data['notifications'] as List)
          .map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        items: notifications,
        isLoading: false,
        total: data['total'] as int? ?? 0,
        unreadCount: data['unread_count'] as int? ?? 0,
        hasMore: notifications.length >= _limit,
      );

      _offset = notifications.length;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Загрузка следующих уведомлений (пагинация)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final userId = await _auth.getUserId();
      if (userId == null) {
        state = state.copyWith(isLoadingMore: false);
        return;
      }

      final data = await _api.post(
        '/get_notifications.php',
        body: {
          'user_id': userId,
          'offset': _offset,
          'limit': _limit,
        },
      );

      final notifications = (data['notifications'] as List)
          .map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        items: [...state.items, ...notifications],
        isLoadingMore: false,
        total: data['total'] as int? ?? 0,
        unreadCount: data['unread_count'] as int? ?? 0,
        hasMore: notifications.length >= _limit,
      );

      _offset += notifications.length;
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Обновление уведомлений (pull-to-refresh)
  Future<void> refresh() async {
    await loadInitial();
  }

  /// Отметка уведомлений как прочитанных
  Future<void> markAsRead(List<int>? notificationIds) async {
    try {
      final userId = await _auth.getUserId();
      if (userId == null) return;

      await _api.post(
        '/mark_notifications_read.php',
        body: {
          'user_id': userId,
          if (notificationIds != null) 'notification_ids': notificationIds,
        },
      );

      // Обновляем локальное состояние
      final updatedItems = state.items.map((notif) {
        if (notificationIds == null || notificationIds.contains(notif.id)) {
          return NotificationItem(
            id: notif.id,
            senderId: notif.senderId,
            senderName: notif.senderName,
            senderAvatar: notif.senderAvatar,
            notificationType: notif.notificationType,
            notificationTypeName: notif.notificationTypeName,
            icon: notif.icon,
            color: notif.color,
            objectType: notif.objectType,
            objectId: notif.objectId,
            text: notif.text,
            isRead: true,
            createdAt: notif.createdAt,
          );
        }
        return notif;
      }).toList();

      // Обновляем счетчик непрочитанных с сервера для точности
      try {
        final data = await _api.post(
          '/get_unread_notifications_count.php',
          body: {'user_id': userId},
        );
        final unreadCount = data['unread_count'] as int? ?? 0;

        state = state.copyWith(
          items: updatedItems,
          unreadCount: unreadCount,
        );
      } catch (e) {
        // Если не удалось получить счетчик с сервера, пересчитываем локально
        final unreadCount = updatedItems.where((n) => !n.isRead).length;
        state = state.copyWith(
          items: updatedItems,
          unreadCount: unreadCount,
        );
      }
    } catch (e) {
      // Игнорируем ошибки при отметке как прочитанных
    }
  }

  /// Получение количества непрочитанных уведомлений
  Future<int> getUnreadCount() async {
    try {
      final userId = await _auth.getUserId();
      if (userId == null) return 0;

      final data = await _api.post(
        '/get_unread_notifications_count.php',
        body: {'user_id': userId},
      );

      return data['unread_count'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Обновление только счетчика непрочитанных уведомлений (для polling)
  /// Не загружает все уведомления, только обновляет счетчик
  Future<void> updateUnreadCount() async {
    try {
      final userId = await _auth.getUserId();
      if (userId == null) return;

      final data = await _api.post(
        '/get_unread_notifications_count.php',
        body: {'user_id': userId},
      );

      final unreadCount = data['unread_count'] as int? ?? 0;

      // ✅ Всегда обновляем состояние, чтобы гарантировать обновление UI
      // Это важно для первого вызова и для случаев, когда виджет еще не подписан
      state = state.copyWith(unreadCount: unreadCount);
    } catch (e) {
      // Логируем ошибки для отладки, но не прерываем работу
      debugPrint('⚠️ Ошибка при обновлении счетчика уведомлений: $e');
    }
  }
}

/// Провайдер для уведомлений
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final api = ref.read(apiServiceProvider);
  final auth = ref.read(authServiceProvider);
  return NotificationsNotifier(api, auth);
});

