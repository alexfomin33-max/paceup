// lib/providers/chat/users_search_provider.dart
// ────────────────────────────────────────────────────────────────────────────
// Провайдер для поиска пользователей в чатах
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_user.dart';
import '../../../../../../core/services/api_service.dart';
import '../../../../../../core/utils/error_handler.dart';
import '../../../../../../providers/services/api_provider.dart';

/// Состояние поиска пользователей
class UsersSearchState {
  final List<ChatUser> users;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int currentOffset;

  const UsersSearchState({
    this.users = const [],
    this.isLoading = false,
    this.hasMore = false,
    this.error,
    this.currentOffset = 0,
  });

  UsersSearchState copyWith({
    List<ChatUser>? users,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? currentOffset,
  }) {
    return UsersSearchState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      currentOffset: currentOffset ?? this.currentOffset,
    );
  }
}

/// Notifier для управления поиском пользователей
class UsersSearchNotifier extends StateNotifier<UsersSearchState> {
  final ApiService _api;
  final int limit = 25;

  UsersSearchNotifier({required ApiService api})
    : _api = api,
      super(const UsersSearchState());

  /// Загрузка подписчиков (начальный список)
  Future<void> loadSubscribedUsers() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await _api.get(
        '/get_subscribed_users.php',
        queryParams: {'offset': '0', 'limit': limit.toString()},
      );

      final List rawList = data['users'] as List? ?? const [];
      final users = rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => ChatUser.fromJson(j))
          .toList();

      state = state.copyWith(
        users: users,
        isLoading: false,
        hasMore: data['has_more'] == true,
        currentOffset: users.length,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ErrorHandler.format(e));
    }
  }

  /// Загрузка следующей страницы подписчиков
  Future<void> loadMoreSubscribedUsers() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final data = await _api.get(
        '/get_subscribed_users.php',
        queryParams: {
          'offset': state.currentOffset.toString(),
          'limit': limit.toString(),
        },
      );

      final List rawList = data['users'] as List? ?? const [];
      final newUsers = rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => ChatUser.fromJson(j))
          .toList();

      state = state.copyWith(
        users: [...state.users, ...newUsers],
        isLoading: false,
        hasMore: data['has_more'] == true,
        currentOffset: state.currentOffset + newUsers.length,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ErrorHandler.format(e));
    }
  }

  /// Поиск пользователей по запросу
  Future<void> searchUsers(String query) async {
    if (query.trim().isEmpty) {
      // Если запрос пустой, загружаем подписчиков
      await loadSubscribedUsers();
      return;
    }

    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null, users: []);

    try {
      final data = await _api.get(
        '/search_users.php',
        queryParams: {
          'query': query.trim(),
          'offset': '0',
          'limit': limit.toString(),
        },
      );

      final List rawList = data['users'] as List? ?? const [];
      final users = rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => ChatUser.fromJson(j))
          .toList();

      state = state.copyWith(
        users: users,
        isLoading: false,
        hasMore: data['has_more'] == true,
        currentOffset: users.length,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ErrorHandler.format(e));
    }
  }

  /// Загрузка следующей страницы результатов поиска
  Future<void> loadMoreSearchResults(String query) async {
    if (query.trim().isEmpty || state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final data = await _api.get(
        '/search_users.php',
        queryParams: {
          'query': query.trim(),
          'offset': state.currentOffset.toString(),
          'limit': limit.toString(),
        },
      );

      final List rawList = data['users'] as List? ?? const [];
      final newUsers = rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => ChatUser.fromJson(j))
          .toList();

      state = state.copyWith(
        users: [...state.users, ...newUsers],
        isLoading: false,
        hasMore: data['has_more'] == true,
        currentOffset: state.currentOffset + newUsers.length,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ErrorHandler.format(e));
    }
  }

  /// Сброс состояния
  void reset() {
    state = const UsersSearchState();
  }
}

/// Provider для поиска пользователей
final usersSearchProvider =
    StateNotifierProvider<UsersSearchNotifier, UsersSearchState>((ref) {
      final api = ref.watch(apiServiceProvider);

      return UsersSearchNotifier(api: api);
    });
