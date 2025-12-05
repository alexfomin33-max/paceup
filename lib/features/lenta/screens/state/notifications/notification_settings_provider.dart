// ─────────────────────────────────────────────────────────────────────────────
// ПРОВАЙДЕР ДЛЯ НАСТРОЕК УВЕДОМЛЕНИЙ
//
// Управляет получением и сохранением настроек уведомлений пользователя
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../../../providers/services/auth_provider.dart';

/// Модель настроек уведомлений пользователя
class NotificationSettings {
  final bool workouts;
  final bool likes;
  final bool comments;
  final bool posts;
  final bool events;
  final bool registrations;
  final bool followers;

  const NotificationSettings({
    required this.workouts,
    required this.likes,
    required this.comments,
    required this.posts,
    required this.events,
    required this.registrations,
    required this.followers,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    final settings = json['settings'] as Map<String, dynamic>? ?? {};
    return NotificationSettings(
      workouts: settings['workouts'] ?? true,
      likes: settings['likes'] ?? true,
      comments: settings['comments'] ?? true,
      posts: settings['posts'] ?? true,
      events: settings['events'] ?? true,
      registrations: settings['registrations'] ?? true,
      followers: settings['followers'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workouts': workouts,
      'likes': likes,
      'comments': comments,
      'posts': posts,
      'events': events,
      'registrations': registrations,
      'followers': followers,
    };
  }

  NotificationSettings copyWith({
    bool? workouts,
    bool? likes,
    bool? comments,
    bool? posts,
    bool? events,
    bool? registrations,
    bool? followers,
  }) {
    return NotificationSettings(
      workouts: workouts ?? this.workouts,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      posts: posts ?? this.posts,
      events: events ?? this.events,
      registrations: registrations ?? this.registrations,
      followers: followers ?? this.followers,
    );
  }
}

/// Провайдер для получения настроек уведомлений пользователя
final notificationSettingsProvider =
    FutureProvider<NotificationSettings>((ref) async {
  final authService = ref.read(authServiceProvider);
  final userId = await authService.getUserId();
  if (userId == null) {
    throw Exception('Пользователь не авторизован');
  }

  final api = ref.read(apiServiceProvider);
  final data = await api.post(
    '/get_notification_settings.php',
    body: {'user_id': userId},
  );

  return NotificationSettings.fromJson(data);
});

/// Функция для сохранения настроек уведомлений
Future<void> saveNotificationSettings(
  WidgetRef ref,
  NotificationSettings settings,
) async {
  final authService = ref.read(authServiceProvider);
  final userId = await authService.getUserId();
  if (userId == null) {
    throw Exception('Пользователь не авторизован');
  }

  final api = ref.read(apiServiceProvider);
  await api.post(
    '/update_notification_settings.php',
    body: {
      'user_id': userId,
      ...settings.toJson(),
    },
  );

  // Инвалидируем провайдер для обновления данных
  ref.invalidate(notificationSettingsProvider);
}

