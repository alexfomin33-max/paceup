// ────────────────────────────────────────────────────────────────────────────
//  CACHE SERVICE PROVIDER
//
//  Riverpod Provider для CacheService
//  Singleton — одна инстанция на всё приложение
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../service/cache_service.dart';

/// Provider для AppDatabase (singleton)
/// 
/// Создаёт подключение к локальной SQLite базе данных
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  
  // Автоматически закрываем при dispose
  ref.onDispose(() {
    db.close();
  });
  
  return db;
});

/// Provider для CacheService (singleton)
/// 
/// Использование:
/// ```dart
/// final cache = ref.read(cacheServiceProvider);
/// await cache.cacheActivities(activities, userId: 1);
/// final cached = await cache.getCachedActivities(userId: 1);
/// ```
final cacheServiceProvider = Provider<CacheService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final cache = CacheService(db);
  
  // Автоматически очищаем старый кэш при инициализации
  // (асинхронно, не блокируем UI)
  Future.microtask(() {
    cache.clearOldCache(days: 7);
  });
  
  return cache;
});

