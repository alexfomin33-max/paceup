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
import 'package:cached_network_image/cached_network_image.dart';
import '../../service/api_service.dart';
import '../../service/cache_service.dart';
import '../../models/user_profile_header.dart';
import '../../utils/cache_cleaner.dart';
import 'profile_header_state.dart';
import '../avatar_version_provider.dart';

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
  /// 
  /// Стратегия двойного cache-busting:
  /// 1. Профиль использует URL с timestamp → показывает новую версию через новый ключ кэша
  /// 2. Лента/редактирование используют базовый URL → очищаем их кэш принудительно
  Future<void> reload() async {
    // Сохраняем старый URL и timestamp
    final oldAvatar = state.profile?.avatar;
    final oldTimestamp = state.lastUpdateTimestamp;
    
    // ШАГ 1: Генерируем новый timestamp для профиля (cache-busting)
    final newTimestamp = DateTime.now().millisecondsSinceEpoch;
    state = state.copyWith(lastUpdateTimestamp: newTimestamp);
    
    // ШАГ 2: Загружаем свежие данные с сервера
    await load();
    
    final newAvatar = state.profile?.avatar;
    if (newAvatar == null || newAvatar.isEmpty) return;
    
    // ШАГ 3: Очистка всех вариантов кэша для синхронизации с лентой и редактированием
    try {
      // Собираем все возможные варианты URL для очистки
      final urlsToEvict = <String>{};
      
      // Базовый URL (используется в ленте и редактировании)
      urlsToEvict.add(newAvatar);
      
      // Старый URL с timestamp (если был)
      if (oldAvatar != null && oldAvatar.isNotEmpty) {
        urlsToEvict.add(oldAvatar);
        if (oldTimestamp > 0) {
          final separator = oldAvatar.contains('?') ? '&' : '?';
          urlsToEvict.add('$oldAvatar${separator}v=$oldTimestamp');
        }
      }
      
      // Новый URL с timestamp (используется в профиле)
      final separator = newAvatar.contains('?') ? '&' : '?';
      urlsToEvict.add('$newAvatar${separator}v=$newTimestamp');
      
      // Очищаем все варианты
      for (final url in urlsToEvict) {
        await CachedNetworkImage.evictFromCache(url);
        
        // Также очищаем через ImageProvider
        try {
          final provider = CachedNetworkImageProvider(url);
          await provider.evict();
        } catch (_) {
          // Игнорируем ошибки
        }
      }
      
      // Небольшая задержка для синхронизации
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Повторная очистка базового URL для ленты и редактирования
      await CachedNetworkImage.evictFromCache(newAvatar);
      
      // ШАГ 4: Полная очистка кэша для гарантии
      // Убираем все старые сплюснутые/искажённые версии
      await clearImageCacheForUrl(newAvatar);
      
      // ШАГ 5: Обновляем глобальную версию аватарки
      // Это заставит ленту и редактирование обновить изображение
      _ref.read(avatarVersionProvider.notifier).bump();
      
    } catch (e) {
      // Игнорируем ошибки очистки кэша
    }
  }
}
