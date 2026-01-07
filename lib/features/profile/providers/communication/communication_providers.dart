import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../providers/services/api_provider.dart';

// Импортируем ApiException из api_service
export '../../../../core/services/api_service.dart' show ApiException;

/// ────────────────────────────────────────────────────────────────────────────
///                             Типы и модели
/// ────────────────────────────────────────────────────────────────────────────

/// Тип вкладки в экране «Связи».
enum CommunicationTab { subscriptions, subscribers }

/// Аргументы для провайдера списка (учитываем тип вкладки, строку поиска и userId).
@immutable
class CommunicationListArgs {
  const CommunicationListArgs({
    required this.tab,
    required String query,
    this.userId,
  }) : rawQuery = query;

  final CommunicationTab tab;
  final String rawQuery;
  final int? userId; // Если null, используется авторизованный пользователь

  String get sanitizedQuery => rawQuery.trim();
  String get normalizedQuery => sanitizedQuery.toLowerCase();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CommunicationListArgs) return false;
    return tab == other.tab &&
        normalizedQuery == other.normalizedQuery &&
        userId == other.userId;
  }

  @override
  int get hashCode => Object.hash(tab, normalizedQuery, userId);
}

/// Модель пользователя для вкладок подписок/подписчиков.
@immutable
class CommunicationUser {
  const CommunicationUser({
    required this.id,
    required this.name,
    required this.surname,
    required this.fullName,
    required this.age,
    required this.city,
    required this.avatar,
    required this.avatarUrl,
    required this.isSubscribedByMe,
    required this.isFollower,
  });

  final int id;
  final String name;
  final String surname;
  final String fullName;
  final int age;
  final String city;
  final String avatar;
  final String avatarUrl;
  final bool isSubscribedByMe;
  final bool isFollower;

  factory CommunicationUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    final avatar = (json['avatar'] as String?) ?? '';
    final remoteAvatar = (json['avatar_url'] as String?) ?? '';

    return CommunicationUser(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      surname: (json['surname'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ??
          _buildFullName(
            (json['name'] as String?) ?? '',
            (json['surname'] as String?) ?? '',
          ),
      age: _intFromJson(json['age']),
      city: (json['city'] as String?) ?? '',
      avatar: avatar,
      avatarUrl: _resolveAvatarUrl(id, avatar, remoteAvatar),
      isSubscribedByMe: _boolFromJson(json['is_subscribed']),
      isFollower: _boolFromJson(json['is_follower']),
    );
  }

  CommunicationUser copyWith({bool? isSubscribedByMe}) {
    return CommunicationUser(
      id: id,
      name: name,
      surname: surname,
      fullName: fullName,
      age: age,
      city: city,
      avatar: avatar,
      avatarUrl: avatarUrl,
      isSubscribedByMe: isSubscribedByMe ?? this.isSubscribedByMe,
      isFollower: isFollower,
    );
  }

  static String _buildFullName(String name, String surname) {
    final composed = '$name $surname'.trim();
    return composed.isEmpty ? (name.isEmpty ? 'Пользователь' : name) : composed;
  }
}

bool _boolFromJson(dynamic value) {
  if (value is bool) return value;
  if (value is int) return value == 1;
  if (value is String) {
    return value == '1' || value.toLowerCase() == 'true';
  }
  return false;
}

int _intFromJson(dynamic value) {
  if (value is int) return value;
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

String _resolveAvatarUrl(int userId, String avatar, String remote) {
  if (remote.isNotEmpty) return remote;
  if (avatar.isEmpty) {
    return 'https://uploads.paceup.ru/images/users/avatars/def.png';
  }
  if (avatar.startsWith('http')) return avatar;
  return 'https://uploads.paceup.ru/images/users/avatars/$userId/$avatar';
}

/// Состояние списка с пагинацией.
@immutable
class CommunicationListState {
  const CommunicationListState({
    required this.users,
    required this.hasMore,
    required this.isLoadingMore,
    required this.query,
    this.lastError,
  });

  final List<CommunicationUser> users;
  final bool hasMore;
  final bool isLoadingMore;
  final String query;
  final String? lastError;

  CommunicationListState copyWith({
    List<CommunicationUser>? users,
    bool? hasMore,
    bool? isLoadingMore,
    String? query,
    String? lastError,
    bool clearError = false,
  }) {
    return CommunicationListState(
      users: users ?? this.users,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      query: query ?? this.query,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

/// Ответ репозитория (страница пользователей).
class CommunicationPage {
  const CommunicationPage({
    required this.users,
    required this.hasMore,
    required this.total,
  });

  final List<CommunicationUser> users;
  final bool hasMore;
  final int total;
}

/// ────────────────────────────────────────────────────────────────────────────
///                              Репозиторий
/// ────────────────────────────────────────────────────────────────────────────

class CommunicationRepository {
  CommunicationRepository(this._api);

  final ApiService _api;

  static const int pageSize = 20;

  Future<CommunicationPage> fetchUsers({
    required CommunicationTab tab,
    required int offset,
    required int limit,
    required String query,
    int? userId,
  }) async {
    final endpoint = tab == CommunicationTab.subscriptions
        ? '/get_subscribed_users.php'
        : '/get_subscribers.php';

    final params = <String, String>{
      'offset': '$offset',
      'limit': '$limit',
    };
    if (query.isNotEmpty) {
      params['query'] = query;
    }
    // Если передан userId, добавляем его в параметры запроса
    // API будет использовать этот userId вместо авторизованного пользователя
    if (userId != null) {
      params['user_id'] = '$userId';
    }

    final response = await _api.get(
      endpoint,
      queryParams: params,
    );

    final usersRaw = response['users'] as List<dynamic>? ?? [];
    final users = usersRaw
        .map((e) => CommunicationUser.fromJson(e as Map<String, dynamic>))
        .toList();

    final hasMore = response['has_more'] as bool? ?? false;
    final total = response['total'] is int
        ? response['total'] as int
        : (response['total'] ?? users.length) as int;

    return CommunicationPage(users: users, hasMore: hasMore, total: total);
  }

  Future<bool> toggleSubscription({
    required int targetUserId,
    required bool shouldUnsubscribe,
  }) async {
    final response = await _api.post(
      '/toggle_subscribe.php',
      body: {
        'target_user_id': targetUserId,
        'action': shouldUnsubscribe ? 'unsubscribe' : 'subscribe',
      },
    );

    if (response['success'] == true) {
      return response['is_subscribed'] as bool? ?? !shouldUnsubscribe;
    }

    throw ApiException(
      response['message']?.toString() ?? 'Ошибка подписки/отписки',
    );
  }
}

final communicationRepositoryProvider =
    Provider<CommunicationRepository>((ref) {
  final api = ref.watch(apiServiceProvider);
  return CommunicationRepository(api);
});

/// ────────────────────────────────────────────────────────────────────────────
///                              Провайдер списка
/// ────────────────────────────────────────────────────────────────────────────

final communicationListProvider = AutoDisposeAsyncNotifierProviderFamily<
    CommunicationListNotifier,
    CommunicationListState,
    CommunicationListArgs>(CommunicationListNotifier.new);

class CommunicationListNotifier extends AutoDisposeFamilyAsyncNotifier<
    CommunicationListState, CommunicationListArgs> {
  CommunicationListArgs? _args;
  final Set<int> _knownUserIds = <int>{};
  bool _isLoadingMore = false;

  CommunicationRepository get _repository =>
      ref.read(communicationRepositoryProvider);

  @override
  Future<CommunicationListState> build(CommunicationListArgs args) async {
    _args = args;
    ref.onDispose(_knownUserIds.clear);
    return _loadInitial();
  }

  Future<CommunicationListState> _loadInitial() async {
    final args = _args!;
    _knownUserIds.clear();

    final page = await _repository.fetchUsers(
      tab: args.tab,
      offset: 0,
      limit: CommunicationRepository.pageSize,
      query: args.sanitizedQuery,
      userId: args.userId,
    );

    final users = _filterUnique(page.users);

    return CommunicationListState(
      users: users,
      hasMore: page.hasMore,
      isLoadingMore: false,
      query: args.sanitizedQuery,
      lastError: null,
    );
  }

  List<CommunicationUser> _filterUnique(List<CommunicationUser> users) {
    final filtered = <CommunicationUser>[];
    for (final user in users) {
      if (_knownUserIds.add(user.id)) {
        filtered.add(user);
      }
    }
    return filtered;
  }

  Future<void> refresh() async {
    try {
      state = const AsyncLoading();
      final freshState = await _loadInitial();
      state = AsyncData(freshState);
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }

  Future<void> loadMore() async {
    final args = _args;
    final current = state.valueOrNull;
    if (args == null ||
        current == null ||
        !current.hasMore ||
        _isLoadingMore) {
      return;
    }

    _isLoadingMore = true;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, clearError: true),
    );

    try {
      final page = await _repository.fetchUsers(
        tab: args.tab,
        offset: current.users.length,
        limit: CommunicationRepository.pageSize,
        query: args.sanitizedQuery,
        userId: args.userId,
      );

      final updatedUsers = [
        ...current.users,
        ..._filterUnique(page.users),
      ];

      state = AsyncData(
        current.copyWith(
          users: updatedUsers,
          hasMore: page.hasMore,
          isLoadingMore: false,
          clearError: true,
        ),
      );
    } catch (error) {
      final message = ErrorHandler.format(error);
      state = AsyncData(
        current.copyWith(
          isLoadingMore: false,
          lastError: message,
        ),
      );

      if (kDebugMode) {
        debugPrint('⚠️ Ошибка пагинации: $message');
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> toggleSubscription(int userId) async {
    final args = _args;
    final current = state.valueOrNull;
    if (args == null || current == null) return;

    final index = current.users.indexWhere((user) => user.id == userId);
    if (index == -1) return;

    final originalUser = current.users[index];
    final isUnsubscribing = originalUser.isSubscribedByMe;
    
    // Сохраняем исходное состояние для возможного отката
    final originalState = current;
    
    // Если это отписка на вкладке подписок, сразу удаляем карточку оптимистично
    final shouldRemoveOptimistically = args.tab == CommunicationTab.subscriptions &&
        isUnsubscribing &&
        args.sanitizedQuery.isEmpty;

    if (shouldRemoveOptimistically) {
      // Оптимистично удаляем пользователя из списка
      final optimisticUsers = [...current.users];
      optimisticUsers.removeAt(index);
      state = AsyncData(
        current.copyWith(users: optimisticUsers, clearError: true),
      );
    } else {
      // Для остальных случаев меняем состояние подписки
      final desiredState = !originalUser.isSubscribedByMe;
      final optimisticUsers = [...current.users];
      optimisticUsers[index] =
          originalUser.copyWith(isSubscribedByMe: desiredState);
      state = AsyncData(
        current.copyWith(users: optimisticUsers, clearError: true),
      );
    }

    try {
      final confirmedState = await _repository.toggleSubscription(
        targetUserId: userId,
        shouldUnsubscribe: isUnsubscribing,
      );

      if (shouldRemoveOptimistically) {
        // Если карточка уже удалена оптимистично, просто обновляем список
        // для синхронизации (на случай, если есть еще данные)
        unawaited(_softRefresh());
      } else {
        // Обновляем состояние подписки после подтверждения
        final currentAfterOptimistic = state.valueOrNull;
        if (currentAfterOptimistic != null) {
          final syncedUsers = [...currentAfterOptimistic.users];
          final updatedIndex = syncedUsers.indexWhere((user) => user.id == userId);
          if (updatedIndex != -1 && updatedIndex < syncedUsers.length) {
            syncedUsers[updatedIndex] =
                syncedUsers[updatedIndex].copyWith(isSubscribedByMe: confirmedState);
          }

          state = AsyncData(
            currentAfterOptimistic.copyWith(users: syncedUsers, clearError: true),
          );

          // Проверяем, нужно ли удалить карточку после подтверждения
          final shouldDropFromList =
              args.tab == CommunicationTab.subscriptions &&
                  !confirmedState &&
                  args.sanitizedQuery.isEmpty;

          if (shouldDropFromList) {
            unawaited(_softRefresh());
          }
        }
      }
    } catch (error) {
      // Откатываем изменения при ошибке к исходному состоянию
      final message = ErrorHandler.format(error);
      state = AsyncData(
        originalState.copyWith(lastError: message),
      );
    }
  }

  Future<void> _softRefresh() async {
    try {
      final freshState = await _loadInitial();
      state = AsyncData(freshState);
    } catch (_) {
      // Тихо игнорируем ошибку фонового обновления.
    }
  }
}

