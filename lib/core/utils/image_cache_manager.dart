// ────────────────────────────────────────────────────────────────────────────
//  IMAGE CACHE MANAGER
//
//  Unified кэш-менеджер для всех изображений в приложении
//  Решает проблему разных кэшей между CachedNetworkImage и precacheImage
//
//  Возможности:
//  • Единый disk cache для всех изображений (7 дней хранения)
//  • Оптимизированный memory cache (200 изображений / 100 MB)
//  • Автоматическая очистка старых файлов
//  • Deduplicated загрузка (один URL = один запрос)
//
//  Использование:
//  ```dart
//  // В main.dart при старте
//  ImageCacheManager.configure(context);
//
//  // В CachedNetworkImage
//  CachedNetworkImage(
//    imageUrl: url,
//    cacheManager: ImageCacheManager.instance,
//  )
//
//  // В precacheImage
//  final provider = CachedNetworkImageProvider(
//    url,
//    cacheManager: ImageCacheManager.instance,
//  );
//  precacheImage(provider, context);
//  ```
// ────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Unified кэш-менеджер для всех изображений в приложении
class ImageCacheManager {
  // ──────────────────────────── Singleton ────────────────────────────

  static ImageCacheManager? _instance;

  /// Получить глобальный инстанс кэш-менеджера
  static CacheManager get instance {
    _instance ??= ImageCacheManager._();
    return _instance!._cacheManager;
  }

  // ──────────────────────────── Configuration ────────────────────────────

  /// Конфигурация disk cache
  static const _cacheKey = 'paceup_unified_image_cache';
  static const _maxCacheObjects = 200; // максимум файлов на диске
  static const _stalePeriod = Duration(days: 7); // 7 дней хранения

  /// Конфигурация memory cache
  static const _maxMemoryObjects = 200; // максимум изображений в памяти
  static const _maxMemorySizeBytes = 100 << 20; // 100 MB максимум в памяти

  // ──────────────────────────── Private ────────────────────────────

  late final CacheManager _cacheManager;

  ImageCacheManager._() {
    _cacheManager = CacheManager(
      Config(
        _cacheKey,
        stalePeriod: _stalePeriod,
        maxNrOfCacheObjects: _maxCacheObjects,
        repo: JsonCacheInfoRepository(databaseName: _cacheKey),
        fileService: HttpFileService(),
      ),
    );
  }

  // ──────────────────────────── Public API ────────────────────────────

  /// Настройка глобального ImageCache Flutter
  ///
  /// Вызывать один раз в main.dart после runApp():
  /// ```dart
  /// void main() {
  ///   runApp(MyApp());
  ///   WidgetsBinding.instance.addPostFrameCallback((_) {
  ///     ImageCacheManager.configure(context);
  ///   });
  /// }
  /// ```
  static void configure(BuildContext context) {
    final imageCache = PaintingBinding.instance.imageCache;

    // Настраиваем максимальное количество изображений в памяти
    imageCache.maximumSize = _maxMemoryObjects;

    // Настраиваем максимальный размер кэша в байтах
    imageCache.maximumSizeBytes = _maxMemorySizeBytes;

    debugPrint('🖼️ ImageCache настроен: '
        'maxSize=$_maxMemoryObjects, '
        'maxBytes=${_maxMemorySizeBytes ~/ (1 << 20)}MB');
  }

  /// Очистка всего кэша (disk + memory)
  ///
  /// Полезно при выходе из аккаунта или для очистки места
  static Future<void> clearAll() async {
    // Очищаем disk cache
    await instance.emptyCache();

    // Очищаем memory cache
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    debugPrint('🗑️ ImageCache полностью очищен (disk + memory)');
  }

  /// Получить размер кэша на диске (в байтах)
  static Future<int> getCacheSize() async {
    try {
      final dir = await getTemporaryDirectory();
      final cacheDirPath = path.join(dir.path, _cacheKey);
      final directory = Directory(cacheDirPath);
      
      if (!await directory.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          totalSize += (await entity.length());
        }
      }

      return totalSize;
    } catch (e) {
      debugPrint('⚠️ Ошибка подсчёта размера кэша: $e');
      return 0;
    }
  }

  /// Получить статистику memory cache
  static ImageCacheStatus getMemoryCacheStats() {
    final imageCache = PaintingBinding.instance.imageCache;
    return ImageCacheStatus(
      currentSize: imageCache.currentSize,
      currentSizeBytes: imageCache.currentSizeBytes,
      liveImageCount: imageCache.liveImageCount,
      pendingImageCount: imageCache.pendingImageCount,
    );
  }

  /// Предзагрузка изображения в кэш
  ///
  /// Использует единый кэш-менеджер для согласованности
  /// с CachedNetworkImage.
  ///
  /// ⚠️ Загружает оригинал без ресайза (maxWidth/maxHeight не поддерживаются
  /// с обычным CacheManager). Ресайз выполняется при отображении через
  /// memCacheWidth/memCacheHeight в CachedNetworkImage.
  ///
  /// Пример:
  /// ```dart
  /// await ImageCacheManager.precache(
  ///   context: context,
  ///   url: 'https://example.com/image.jpg',
  /// );
  /// ```
  static Future<void> precache({
    required BuildContext context,
    required String url,
  }) async {
    try {
      // Используем CachedNetworkImageProvider с единым кэш-менеджером
      // БЕЗ maxWidth/maxHeight - они требуют ImageCacheManager (не обычный CacheManager)
      final provider = CachedNetworkImageProvider(
        url,
        cacheManager: instance,
      );

      // Загружаем в память через precacheImage
      await precacheImage(provider, context);
    } catch (e) {
      // Игнорируем ошибки prefetch (не критично для UX)
      debugPrint('⚠️ Prefetch failed for $url: $e');
    }
  }
}

// ──────────────────────────── Import fix ────────────────────────────

// flutter_cache_manager нужно добавить в pubspec.yaml:
// dependencies:
//   flutter_cache_manager: ^3.3.1

// CachedNetworkImageProvider из cached_network_image автоматически
// поддерживает кастомный cacheManager

/// Статистика memory cache
class ImageCacheStatus {
  final int currentSize;
  final int currentSizeBytes;
  final int liveImageCount;
  final int pendingImageCount;

  ImageCacheStatus({
    required this.currentSize,
    required this.currentSizeBytes,
    required this.liveImageCount,
    required this.pendingImageCount,
  });

  @override
  String toString() {
    return 'ImageCacheStatus('
        'size: $currentSize/$liveImageCount live, '
        'bytes: ${currentSizeBytes ~/ (1 << 20)}MB, '
        'pending: $pendingImageCount'
        ')';
  }
}

