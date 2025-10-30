// ────────────────────────────────────────────────────────────────────────────
//  PROFILE HEADER NOTIFIER
//
//  StateNotifier для управления данными header'а профиля
//  Возможности:
//  • Загрузка данных профиля с offline-first кэшированием
//  • Обновление профиля
//  • Работа без интернета
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../service/api_service.dart';
import '../../service/cache_service.dart';
import '../../models/user_profile_header.dart';
import 'profile_header_state.dart';

class ProfileHeaderNotifier extends StateNotifier<ProfileHeaderState> {
  final ApiService _api;
  final CacheService _cache;
  final int userId;

  ProfileHeaderNotifier({
    required ApiService api,
    required CacheService cache,
    required this.userId,
  }) : _api = api,
       _cache = cache,
       super(ProfileHeaderState.initial());

  /// Загрузка данных профиля
  ///
  /// OFFLINE-FIRST ПОДХОД:
  /// 1. Сначала показываем кэш (если есть)
  /// 2. В фоне загружаем свежие данные
  /// 3. Обновляем UI и кэш
  /// 4. Если ошибка сети — показываем кэш
  Future<void> load() async {
    try {
      // ────────── ШАГ 1: Показываем кэш (мгновенно) ──────────
      final cached = await _cache.getCachedProfile(userId: userId);

      if (cached != null) {
        // Конвертируем кэш в UserProfileHeader
        // Используем все доступные данные из кэша, включая город, возраст и подписки
        final cachedProfile = UserProfileHeader(
          id: cached.userId,
          firstName: cached.name.split(' ').first,
          lastName: cached.name.split(' ').skip(1).join(' '),
          avatar: cached.avatar.isEmpty ? null : cached.avatar,
          city: cached.city,
          age: cached.age,
          followers: cached.followers,
          following: cached.following,
          status: null,
        );

        state = state.copyWith(profile: cachedProfile, isLoading: false);
      } else {
        state = state.copyWith(isLoading: true, error: null);
      }

      // ────────── ШАГ 2: Загружаем свежие данные (фон) ──────────
      state = state.copyWith(isLoading: true);

      final map = await _api.post(
        '/user_profile_header.php',
        body: {'user_id': '$userId'},
        timeout: const Duration(seconds: 12),
      );

      // Сервер может вернуть данные в разных ключах
      final dynamic raw = map['profile'] ?? map['data'] ?? map;

      if (raw is! Map) {
        throw const FormatException('Bad payload: not a JSON object');
      }

      final profile = UserProfileHeader.fromJson(
        Map<String, dynamic>.from(raw),
      );

      // Сохраняем в кэш (включая город, возраст и подписки)
      await _cache.cacheProfile(
        userId: profile.id,
        name: '${profile.firstName} ${profile.lastName}',
        avatar: profile.avatar ?? '',
        userGroup: 0,
        totalDistance: 0,
        totalActivities: 0,
        totalTime: 0,
        city: profile.city,
        age: profile.age,
        followers: profile.followers,
        following: profile.following,
      );

      state = state.copyWith(profile: profile, isLoading: false, error: null);
    } catch (e) {
      // Если ошибка сети — показываем кэш (offline mode)
      if (state.profile != null) {
        state = state.copyWith(
          error: 'Показаны сохранённые данные',
          isLoading: false,
        );
      } else {
        state = state.copyWith(error: e.toString(), isLoading: false);
      }
    }
  }

  /// Обновление данных профиля (после редактирования)
  Future<void> reload() async {
    await load();
  }
}
