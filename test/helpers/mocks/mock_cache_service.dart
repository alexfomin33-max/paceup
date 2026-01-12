// ────────────────────────────────────────────────────────────────────────────
//  MOCK CACHE SERVICE
//
//  Мок для CacheService для использования в тестах
//  Использует mocktail для создания моков без code generation
// ────────────────────────────────────────────────────────────────────────────

import 'package:mocktail/mocktail.dart';
import 'package:paceup/core/services/cache_service.dart';
import 'package:paceup/domain/models/activity_lenta.dart';

/// Мок для CacheService
class MockCacheService extends Mock implements CacheService {}

/// Хелперы для создания MockCacheService
class MockCacheServiceFactory {
  /// Создаёт мок с предустановленными данными
  static MockCacheService withDefaults({
    List<Activity>? cachedActivities,
  }) {
    final mock = MockCacheService();
    
    // Настраиваем дефолтные ответы
    when(() => mock.getCachedActivities(userId: any(named: 'userId'), limit: any(named: 'limit')))
        .thenAnswer((_) async => cachedActivities ?? []);
    
    when(() => mock.getCachedActivity(lentaId: any(named: 'lentaId')))
        .thenAnswer((_) async => null);
    
    when(() => mock.cacheActivities(any(), userId: any(named: 'userId')))
        .thenAnswer((_) async {});
    
    when(() => mock.removeCachedActivity(lentaId: any(named: 'lentaId')))
        .thenAnswer((_) async {});
    
    when(() => mock.updateCachedActivityLikes(lentaId: any(named: 'lentaId'), newLikes: any(named: 'newLikes')))
        .thenAnswer((_) async {});
    
    when(() => mock.updateCachedActivityComments(lentaId: any(named: 'lentaId'), newComments: any(named: 'newComments')))
        .thenAnswer((_) async {});
    
    when(() => mock.clearActivitiesCache(userId: any(named: 'userId')))
        .thenAnswer((_) async {});
    
    when(() => mock.getCachedActivitiesCount(userId: any(named: 'userId')))
        .thenAnswer((_) async => cachedActivities?.length ?? 0);
    
    return mock;
  }

  /// Создаёт мок с пустым кэшем
  static MockCacheService empty() {
    return withDefaults();
  }

  /// Создаёт мок с предзаполненными активностями
  static MockCacheService withActivities(List<Activity> activities) {
    return withDefaults(cachedActivities: activities);
  }
}
