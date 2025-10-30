// ────────────────────────────────────────────────────────────────────────────
//  CACHE SERVICE
//
//  Сервис для работы с offline-first кэшем
//  Использует Drift Database для локального хранения
//
//  Возможности:
//  • Кэширование активностей из ленты
//  • Кэширование профилей пользователей
//  • Кэширование GPS маршрутов
//  • Автоматическая очистка старого кэша (TTL)
//  • Конвертация между моделями приложения и кэш-моделями
//
//  Использование:
//  ```dart
//  final cache = CacheService(db);
//
//  // Сохранить активности
//  await cache.cacheActivities(activities, userId: 1);
//
//  // Загрузить из кэша
//  final cached = await cache.getCachedActivities(userId: 1);
//
//  // Очистить старый кэш (старше 7 дней)
//  await cache.clearOldCache(days: 7);
//  ```
// ────────────────────────────────────────────────────────────────────────────

import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/activity_lenta.dart';

class CacheService {
  final AppDatabase _db;

  CacheService(this._db);

  // ────────────────────────── АКТИВНОСТИ ──────────────────────────

  /// Сохраняет список активностей в кэш
  ///
  /// Параметры:
  /// • activities — список активностей для кэширования
  /// • userId — ID пользователя, для которого сохраняется кэш
  ///
  /// Использует UPSERT (insert or replace) для обновления существующих
  Future<void> cacheActivities(
    List<Activity> activities, {
    required int userId,
  }) async {
    final companions = activities.map((activity) {
      return CachedActivitiesCompanion.insert(
        activityId: activity.id,
        lentaId: activity.lentaId,
        userId: activity.userId,
        type: activity.type,
        dateStart: Value(activity.dateStart),
        dateEnd: Value(activity.dateEnd),
        userName: activity.userName,
        userAvatar: activity.userAvatar,
        userGroup: activity.userGroup,
        likes: Value(activity.likes),
        comments: Value(activity.comments),
        isLike: Value(activity.islike),
        postDateText: Value(activity.postDateText),
        postMediaUrl: Value(activity.postMediaUrl),
        postContent: Value(activity.postContent),
        equipments: Value(activity.equipments),
        stats: Value(activity.stats),
        points: Value(activity.points),
        mediaImages: Value(activity.mediaImages),
        mediaVideos: Value(activity.mediaVideos),
        cacheOwner: userId,
      );
    }).toList();

    // Batch insert для производительности
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.cachedActivities, companions);
    });
  }

  /// Загружает закэшированные активности для пользователя
  ///
  /// Параметры:
  /// • userId — ID пользователя
  /// • limit — максимальное количество активностей (по умолчанию 20)
  ///
  /// Возвращает список активностей, отсортированных по дате (новые сверху)
  Future<List<Activity>> getCachedActivities({
    required int userId,
    int limit = 20,
  }) async {
    final query = _db.select(_db.cachedActivities)
      ..where((tbl) => tbl.cacheOwner.equals(userId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.dateStart, mode: OrderingMode.desc),
      ])
      ..limit(limit);

    final results = await query.get();

    // Конвертируем из CachedActivity в Activity
    return results.map(_toDomainActivity).toList();
  }

  /// Загружает одну активность из кэша по lentaId
  Future<Activity?> getCachedActivity({required int lentaId}) async {
    final query = _db.select(_db.cachedActivities)
      ..where((tbl) => tbl.lentaId.equals(lentaId))
      ..limit(1);

    final results = await query.get();
    if (results.isEmpty) return null;

    return _toDomainActivity(results.first);
  }

  /// Удаляет активность из кэша
  Future<void> removeCachedActivity({required int lentaId}) async {
    await (_db.delete(
      _db.cachedActivities,
    )..where((tbl) => tbl.lentaId.equals(lentaId))).go();
  }

  /// Обновляет счётчик лайков в кэше
  Future<void> updateCachedActivityLikes({
    required int lentaId,
    required int newLikes,
  }) async {
    await (_db.update(_db.cachedActivities)
          ..where((tbl) => tbl.lentaId.equals(lentaId)))
        .write(CachedActivitiesCompanion(likes: Value(newLikes)));
  }

  /// Обновляет счётчик комментариев в кэше
  Future<void> updateCachedActivityComments({
    required int lentaId,
    required int newComments,
  }) async {
    await (_db.update(_db.cachedActivities)
          ..where((tbl) => tbl.lentaId.equals(lentaId)))
        .write(CachedActivitiesCompanion(comments: Value(newComments)));
  }

  // ────────────────────────── ПРОФИЛИ ──────────────────────────

  /// Сохраняет профиль пользователя в кэш
  Future<void> cacheProfile({
    required int userId,
    required String name,
    String avatar = '',
    int userGroup = 0,
    int totalDistance = 0,
    int totalActivities = 0,
    int totalTime = 0,
    String? city,
    int? age,
    int? followers,
    int? following,
  }) async {
    await _db
        .into(_db.cachedProfiles)
        .insertOnConflictUpdate(
          CachedProfilesCompanion.insert(
            userId: userId,
            name: name,
            avatar: Value(avatar),
            userGroup: Value(userGroup),
            totalDistance: Value(totalDistance),
            totalActivities: Value(totalActivities),
            totalTime: Value(totalTime),
            city: Value(city),
            age: Value(age),
            followers: Value(followers),
            following: Value(following),
          ),
        );
  }

  /// Загружает профиль из кэша
  Future<CachedProfile?> getCachedProfile({required int userId}) async {
    final query = _db.select(_db.cachedProfiles)
      ..where((tbl) => tbl.userId.equals(userId))
      ..limit(1);

    final results = await query.get();
    return results.isEmpty ? null : results.first;
  }

  // ────────────────────────── МАРШРУТЫ ──────────────────────────

  /// Сохраняет маршрут тренировки в кэш
  Future<void> cacheRoute({
    required int activityId,
    required List<Coord> points,
    List<Coord> bounds = const [],
  }) async {
    await _db
        .into(_db.cachedRoutes)
        .insertOnConflictUpdate(
          CachedRoutesCompanion.insert(
            activityId: activityId,
            points: Value(points),
            bounds: Value(bounds),
          ),
        );
  }

  /// Загружает маршрут из кэша
  Future<CachedRoute?> getCachedRoute({required int activityId}) async {
    final query = _db.select(_db.cachedRoutes)
      ..where((tbl) => tbl.activityId.equals(activityId))
      ..limit(1);

    final results = await query.get();
    return results.isEmpty ? null : results.first;
  }

  // ────────────────────────── ОЧИСТКА ──────────────────────────

  /// Очищает весь кэш активностей для пользователя
  Future<void> clearActivitiesCache({required int userId}) async {
    await (_db.delete(
      _db.cachedActivities,
    )..where((tbl) => tbl.cacheOwner.equals(userId))).go();
  }

  /// Очищает старый кэш (старше указанного количества дней)
  ///
  /// По умолчанию удаляет кэш старше 7 дней
  Future<void> clearOldCache({int days = 7}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));

    // Удаляем старые активности
    await (_db.delete(
      _db.cachedActivities,
    )..where((tbl) => tbl.cachedAt.isSmallerThanValue(cutoffDate))).go();

    // Удаляем старые профили
    await (_db.delete(
      _db.cachedProfiles,
    )..where((tbl) => tbl.cachedAt.isSmallerThanValue(cutoffDate))).go();

    // Удаляем старые маршруты
    await (_db.delete(
      _db.cachedRoutes,
    )..where((tbl) => tbl.cachedAt.isSmallerThanValue(cutoffDate))).go();
  }

  /// Очищает весь кэш (все данные)
  Future<void> clearAllCache() async {
    await _db.delete(_db.cachedActivities).go();
    await _db.delete(_db.cachedProfiles).go();
    await _db.delete(_db.cachedRoutes).go();
  }

  /// Полный сброс базы данных (для отладки и разработки)
  ///
  /// ВНИМАНИЕ: Удаляет все данные безвозвратно!
  /// Используйте только для отладки проблем с миграцией.
  Future<void> resetDatabase() async {
    await clearAllCache();
    // Дополнительно можно очистить метаданные миграции
    // но это требует прямого SQL и обычно не нужно
  }

  // ────────────────────────── СТАТИСТИКА ──────────────────────────

  /// Возвращает количество закэшированных активностей для пользователя
  Future<int> getCachedActivitiesCount({required int userId}) async {
    final query = _db.selectOnly(_db.cachedActivities)
      ..addColumns([_db.cachedActivities.id.count()])
      ..where(_db.cachedActivities.cacheOwner.equals(userId));

    final result = await query.getSingle();
    return result.read(_db.cachedActivities.id.count()) ?? 0;
  }

  /// Возвращает размер базы данных в байтах (примерно)
  Future<int> getCacheSizeEstimate() async {
    final activitiesCount = await _db.select(_db.cachedActivities).get();
    final profilesCount = await _db.select(_db.cachedProfiles).get();
    final routesCount = await _db.select(_db.cachedRoutes).get();

    // Примерная оценка: activity ~5KB, profile ~1KB, route ~20KB
    return (activitiesCount.length * 5 * 1024) +
        (profilesCount.length * 1 * 1024) +
        (routesCount.length * 20 * 1024);
  }

  // ────────────────────────── УТИЛИТЫ ──────────────────────────

  /// Конвертирует CachedActivity в доменную модель Activity
  Activity _toDomainActivity(CachedActivity cached) {
    return Activity(
      id: cached.activityId,
      type: cached.type,
      dateStart: cached.dateStart,
      dateEnd: cached.dateEnd,
      lentaId: cached.lentaId,
      userId: cached.userId,
      userName: cached.userName,
      userAvatar: cached.userAvatar,
      likes: cached.likes,
      comments: cached.comments,
      userGroup: cached.userGroup,
      equipments: cached.equipments,
      stats: cached.stats,
      points: cached.points,
      postDateText: cached.postDateText,
      postMediaUrl: cached.postMediaUrl,
      postContent: cached.postContent,
      islike: cached.isLike,
      mediaImages: cached.mediaImages,
      mediaVideos: cached.mediaVideos,
    );
  }

  /// Закрывает подключение к базе данных
  Future<void> dispose() async {
    await _db.close();
  }
}
