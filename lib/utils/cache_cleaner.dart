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
Future<void> clearImageCacheForUrl(String url) async {
  try {
    await CachedNetworkImage.evictFromCache(url);
    
    // Также очищаем через provider
    final provider = CachedNetworkImageProvider(url);
    await provider.evict();
  } catch (e) {
    // Игнорируем ошибки
  }
}

