// ────────────────────────────────────────────────────────────────────────────
//  CACHE CLEANER
//
//  Утилита для очистки кэша изображений
// ────────────────────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';

/// Очистка всего кэша CachedNetworkImage
/// 
/// Удаляет все закэшированные изображения (disk + memory).
/// Используйте после критических изменений (например, смены аватарки).
Future<void> clearAllImageCache() async {
  try {
    // Очищаем disk cache CachedNetworkImage
    await CachedNetworkImage.evictFromCache('');
    
    // Очищаем Flutter ImageCache (встроенный)
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
  } catch (e) {
    // Игнорируем ошибки очистки
  }
}

/// Очистка кэша конкретного URL
/// 
/// Очищает кэш для всех вариантов URL (с параметрами и без),
/// чтобы гарантировать обновление изображения даже если URL
/// содержит cache-busting параметры (?v=timestamp).
Future<void> clearImageCacheForUrl(String url) async {
  try {
    // Очищаем базовый URL (без параметров)
    final baseUrl = url.split('?').first;
    await CachedNetworkImage.evictFromCache(baseUrl);
    
    // Очищаем полный URL (с параметрами, если есть)
    if (url != baseUrl) {
      await CachedNetworkImage.evictFromCache(url);
    }
    
    // Также очищаем через provider для базового URL
    final provider = CachedNetworkImageProvider(baseUrl);
    await provider.evict();
    
    // Очищаем через provider для полного URL (если отличается)
    if (url != baseUrl) {
      final fullProvider = CachedNetworkImageProvider(url);
      await fullProvider.evict();
    }
    
    // Очищаем Flutter ImageCache для всех вариантов
    PaintingBinding.instance.imageCache.evict(provider);
    if (url != baseUrl) {
      final fullProvider = CachedNetworkImageProvider(url);
      PaintingBinding.instance.imageCache.evict(fullProvider);
    }
  } catch (e) {
    // Игнорируем ошибки
  }
}

