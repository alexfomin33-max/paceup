// ────────────────────────────────────────────────────────────────────────────
//  FRIENDS SEARCH PROVIDER
//
//  Провайдеры для поиска друзей и получения рекомендованных друзей
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_service.dart';
import '../../../../providers/services/api_provider.dart';
import '../../../../providers/services/auth_provider.dart';

/// Модель пользователя для поиска друзей
class FriendUser {
  final int id;
  final String name;
  final String surname;
  final String fullName;
  final int age;
  final String city;
  final String avatar;
  final bool
  isSubscribed; // Статус подписки текущего пользователя на этого пользователя

  FriendUser({
    required this.id,
    required this.name,
    required this.surname,
    required this.fullName,
    required this.age,
    required this.city,
    required this.avatar,
    this.isSubscribed = false,
  });

  /// Создает копию с обновленным статусом подписки
  FriendUser copyWith({bool? isSubscribed}) {
    return FriendUser(
      id: id,
      name: name,
      surname: surname,
      fullName: fullName,
      age: age,
      city: city,
      avatar: avatar,
      isSubscribed: isSubscribed ?? this.isSubscribed,
    );
  }

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      surname: json['surname'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      age: json['age'] as int? ?? 0,
      city: json['city'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '1.webp',
      isSubscribed: json['is_subscribed'] as bool? ?? false,
    );
  }

  /// Формирование URL для аватара
  String get avatarUrl {
    if (avatar.isEmpty) {
      return 'http://uploads.paceup.ru/images/users/avatars/def.png';
    }
    if (avatar.startsWith('http')) return avatar;
    return 'http://uploads.paceup.ru/images/users/avatars/$id/$avatar';
  }
}

/// Провайдер для получения рекомендованных друзей (рандомные пользователи)
/// Использует AutoDisposeFutureProvider для автоматической инвалидации при dispose
/// и добавляет параметр _t для обхода кэша и получения новых рандомных пользователей
final recommendedFriendsProvider = FutureProvider.autoDispose<List<FriendUser>>(
  (ref) async {
    final api = ref.watch(apiServiceProvider);
    final auth = ref.watch(authServiceProvider);

    final userId = await auth.getUserId();
    if (userId == null) {
      // Если userId не получен, возвращаем пустой список
      return [];
    }

    try {
      // ────────────────────────────────────────────────────────────────
      // 🎲 ОБХОД КЭША: добавляем параметр _t (timestamp) для получения
      // новых рандомных пользователей при каждом запросе
      // ────────────────────────────────────────────────────────────────
      // Параметр _t игнорируется на сервере, но заставляет Flutter
      // делать новый запрос вместо использования кэшированного результата
      final response = await api.get(
        '/get_recommended_friends.php',
        queryParams: {
          'limit': '6', // Запрашиваем сразу 6 друзей
          '_t': DateTime.now().millisecondsSinceEpoch
              .toString(), // Параметр для обхода кэша
        },
      );

      // Проверяем успешность ответа
      if (response['success'] == true) {
        final users =
            (response['users'] as List<dynamic>?)
                ?.map((e) => FriendUser.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];

        // Бэкенд уже фильтрует пользователей, на которых не подписан
        // и возвращает их в случайном порядке (ORDER BY RAND())
        // Просто берем первые 6 элементов
        final result = users.take(6).toList();

        return result;
      }

      // Если success != true, логируем сообщение об ошибке
      final errorMessage =
          response['message'] as String? ?? 'Неизвестная ошибка';
      debugPrint('❌ API вернул ошибку: $errorMessage');
      return [];
    } catch (e, stackTrace) {
      // В случае ошибки логируем подробности
      debugPrint('❌ Ошибка загрузки рекомендованных друзей: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  },
);

/// Провайдер для поиска друзей по запросу
final searchFriendsProvider = FutureProvider.family<List<FriendUser>, String>((
  ref,
  query,
) async {
  if (query.trim().isEmpty) {
    return [];
  }

  final api = ref.watch(apiServiceProvider);
  final auth = ref.watch(authServiceProvider);

  final userId = await auth.getUserId();
  if (userId == null) {
    return [];
  }

  try {
    final response = await api.get(
      '/search_friends.php',
      queryParams: {'query': query.trim(), 'limit': '50'},
    );

    if (response['success'] == true) {
      final users =
          (response['users'] as List<dynamic>?)
              ?.map((e) => FriendUser.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      // Загружаем статусы подписок для всех пользователей
      if (users.isNotEmpty) {
        final usersWithSubscriptions = await _loadSubscriptionStatuses(
          api: api,
          users: users,
        );
        return usersWithSubscriptions;
      }

      return users;
    }
    return [];
  } catch (e) {
    // В случае ошибки возвращаем пустой список
    return [];
  }
});

/// Вспомогательная функция для загрузки статусов подписок
Future<List<FriendUser>> _loadSubscriptionStatuses({
  required ApiService api,
  required List<FriendUser> users,
}) async {
  try {
    final userIds = users.map((u) => u.id).toList();

    final response = await api.post(
      '/check_subscription.php',
      body: {'user_ids': userIds},
    );

    if (response['success'] == true) {
      final subscriptions =
          response['subscriptions'] as Map<String, dynamic>? ?? {};

      // Обновляем статус подписки для каждого пользователя
      return users.map((user) {
        final isSubscribed = subscriptions['${user.id}'] as bool? ?? false;
        return user.copyWith(isSubscribed: isSubscribed);
      }).toList();
    }

    return users;
  } catch (e) {
    debugPrint('❌ Ошибка загрузки статусов подписок: $e');
    return users; // Возвращаем пользователей без статусов подписки
  }
}

/// Провайдер для подписки/отписки на пользователя
///
/// ⚡ PERFORMANCE & RELIABILITY:
/// - Использует autoDispose для автоматической очистки после использования
/// - Каждый запрос уникален (не кэшируется) благодаря timestamp в параметрах
/// - Правильная обработка ошибок с пробросом исключений
final toggleSubscribeProvider = FutureProvider.autoDispose
    .family<bool, ToggleSubscribeParams>((ref, params) async {
      final api = ref.watch(apiServiceProvider);

      try {
        final response = await api.post(
          '/toggle_subscribe.php',
          body: {
            'target_user_id': params.targetUserId,
            'action': params.isSubscribed ? 'unsubscribe' : 'subscribe',
          },
        );

        if (response['success'] == true) {
          final isSubscribed = response['is_subscribed'] as bool? ?? false;
          return isSubscribed;
        }

        throw Exception(response['message'] as String? ?? 'Ошибка подписки');
      } catch (e) {
        debugPrint('❌ Ошибка подписки/отписки: $e');
        rethrow;
      }
    });

/// Параметры для провайдера подписки
class ToggleSubscribeParams {
  final int targetUserId;
  final bool isSubscribed;

  ToggleSubscribeParams({
    required this.targetUserId,
    required this.isSubscribed,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToggleSubscribeParams &&
          runtimeType == other.runtimeType &&
          targetUserId == other.targetUserId &&
          isSubscribed == other.isSubscribed;

  @override
  int get hashCode => targetUserId.hashCode ^ isSubscribed.hashCode;
}

// ────────────────────────────────────────────────────────────────────────────
//  SUBSCRIPTION STATE CACHE
//
//  Провайдер для кэширования состояния подписок, чтобы оно сохранялось
//  при прокрутке списка и пересоздании виджетов
// ────────────────────────────────────────────────────────────────────────────

/// Notifier для управления кэшем состояния подписок
///
/// Хранит актуальное состояние подписки для каждого пользователя,
/// чтобы оно не терялось при прокрутке списка
class SubscriptionStateNotifier extends StateNotifier<Map<int, bool>> {
  SubscriptionStateNotifier() : super({});

  /// Обновить состояние подписки для пользователя
  void updateSubscription(int userId, bool isSubscribed) {
    state = {...state, userId: isSubscribed};
  }

  /// Получить состояние подписки для пользователя
  /// Возвращает null, если состояние не было установлено
  bool? getSubscription(int userId) {
    return state[userId];
  }

  /// Очистить кэш для конкретного пользователя
  void clearSubscription(int userId) {
    final newState = {...state};
    newState.remove(userId);
    state = newState;
  }

  /// Очистить весь кэш
  void clearAll() {
    state = {};
  }
}

/// Provider для кэша состояния подписок
///
/// Использование:
/// ```dart
/// // Обновить состояние после подписки
/// ref.read(subscriptionStateProvider.notifier).updateSubscription(userId, true);
///
/// // Получить состояние (или null, если не установлено)
/// final isSubscribed = ref.read(subscriptionStateProvider.notifier).getSubscription(userId);
/// ```
final subscriptionStateProvider =
    StateNotifierProvider<SubscriptionStateNotifier, Map<int, bool>>(
      (ref) => SubscriptionStateNotifier(),
    );
