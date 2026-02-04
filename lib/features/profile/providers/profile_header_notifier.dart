// ────────────────────────────────────────────────────────────────────────────
//  PROFILE HEADER NOTIFIER
//
//  StateNotifier для управления данными header'а профиля
//  Возможности:
//  • Загрузка данных профиля с offline-first кэшированием
//  • Обновление профиля
//  • Работа без интернета
//  • Очистка кэша аватарки при обновлении
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/cache_service.dart';
import '../../../domain/models/user_profile_header.dart';
import '../../../core/utils/cache_cleaner.dart';
import '../../../core/utils/error_handler.dart';
import 'profile_header_state.dart';
import '../../../providers/avatar_version_provider.dart';

class ProfileHeaderNotifier extends StateNotifier<ProfileHeaderState> {
  final ApiService _api;
  final CacheService _cache;
  final int userId;
  final Ref _ref;

  ProfileHeaderNotifier({
    required ApiService api,
    required CacheService cache,
    required this.userId,
    required Ref ref,
  }) : _api = api,
       _cache = cache,
       _ref = ref,
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
        // Проверяем, что кэш соответствует запрашиваемому userId
        if (cached.userId != userId) {
          // Очищаем неправильный кэш
          await _cache.clearProfileCache(userId: cached.userId);
          state = state.copyWith(isLoading: true, error: null);
        } else {
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
            totalActivities: cached.totalActivities > 0
                ? cached.totalActivities
                : null,
          );

          state = state.copyWith(profile: cachedProfile, isLoading: false);
        }
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

      // Сохраняем в кэш (включая город, возраст, подписки и число занятий)
      await _cache.cacheProfile(
        userId: profile.id,
        name: '${profile.firstName} ${profile.lastName}',
        avatar: profile.avatar ?? '',
        userGroup: 0,
        totalDistance: 0,
        totalActivities: profile.totalActivities ?? 0,
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
        state = state.copyWith(
          error: ErrorHandler.format(e),
          isLoading: false,
        );
      }
    }
  }

  /// Обновление данных профиля (после редактирования)
  ///
  /// Унифицированная стратегия cache-busting:
  /// Все экраны (профиль, лента, редактирование) используют avatarVersionProvider
  /// для синхронизированного обновления аватарки
  Future<void> reload() async {
    // Сохраняем старый URL для очистки кэша
    final oldAvatar = state.profile?.avatar;
    final oldBackground = state.profile?.background;

    // ШАГ 1: Очищаем кэш профиля для принудительной загрузки свежих данных
    await _cache.clearProfileCache(userId: userId);

    // ШАГ 2: Обновляем глобальную версию аватарки
    // Это обновит аватарку везде: в профиле, ленте и редактировании
    _ref.read(avatarVersionProvider.notifier).bump();

    // ШАГ 3: Загружаем свежие данные с сервера (без показа кэша)
    // Пропускаем показ кэша, сразу загружаем с сервера
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

    final profile = UserProfileHeader.fromJson(Map<String, dynamic>.from(raw));

    // Сохраняем в кэш (включая число занятий для офлайн)
    await _cache.cacheProfile(
      userId: profile.id,
      name: '${profile.firstName} ${profile.lastName}',
      avatar: profile.avatar ?? '',
      userGroup: 0,
      totalDistance: 0,
      totalActivities: profile.totalActivities ?? 0,
      totalTime: 0,
      city: profile.city,
      age: profile.age,
      followers: profile.followers,
      following: profile.following,
    );

    state = state.copyWith(profile: profile, isLoading: false, error: null);

    final newAvatar = state.profile?.avatar;
    final newBackground = state.profile?.background;

    // ШАГ 4: Очистка кэша для принудительной перезагрузки
    // Используем улучшенную функцию clearImageCacheForUrl, которая
    // очищает кэш для всех вариантов URL (с параметрами и без)
    try {
      if (newAvatar != null && newAvatar.isNotEmpty) {
        // Очищаем новый URL (все варианты)
        await clearImageCacheForUrl(newAvatar);

        // Очищаем старый URL (если был другой)
        if (oldAvatar != null && oldAvatar != newAvatar) {
          await clearImageCacheForUrl(oldAvatar);
        }
      }

      // Аналогично пробиваем кэш фоновой картинки, чтобы видеть новую обложку
      if (newBackground != null && newBackground.isNotEmpty) {
        // Очищаем новый URL (все варианты)
        await clearImageCacheForUrl(newBackground);

        // Очищаем старый URL (если был другой)
        if (oldBackground != null && oldBackground != newBackground) {
          await clearImageCacheForUrl(oldBackground);
        }
      }
    } catch (e) {
      // Игнорируем ошибки очистки кэша
    }
  }

  /// Обновление данных профиля без очистки кэша аватарки
  ///
  /// Используется для периодического обновления данных (подписки/подписчики)
  /// без визуального "мигания" аватарки. Кэш аватарки сохраняется.
  Future<void> refresh() async {
    try {
      // Загружаем свежие данные с сервера
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

      final profile = UserProfileHeader.fromJson(Map<String, dynamic>.from(raw));

      // Сохраняем в кэш (обновляем данные, но НЕ очищаем кэш аватарки)
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
      // Если ошибка сети — показываем текущие данные
      if (state.profile != null) {
        state = state.copyWith(
          error: 'Не удалось обновить данные',
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          error: ErrorHandler.format(e),
          isLoading: false,
        );
      }
    }
  }
}
