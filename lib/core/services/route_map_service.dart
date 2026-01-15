// lib/core/services/route_map_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Сервис для работы с сохраненными изображениями карт маршрутов
//
// Функции:
//  • Получение URL сохраненного изображения карты маршрута
//  • Сохранение изображения карты маршрута на сервер
//  • Автоматическая генерация и сохранение при отсутствии изображения
//
// ⚡ PERFORMANCE OPTIMIZATION:
// - Кеширование результатов запросов для избежания повторных обращений к API
// - Асинхронная загрузка и сохранение изображений
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../config/app_config.dart';

/// Сервис для работы с сохраненными изображениями карт маршрутов
class RouteMapService {
  static final RouteMapService _instance = RouteMapService._internal();
  factory RouteMapService() => _instance;
  RouteMapService._internal();

  final ApiService _api = ApiService();
  
  // ──────────────────────────── Кеш для URL изображений ────────────────────────────
  // Кешируем результаты запросов, чтобы не делать повторные запросы для одной активности
  final Map<int, String?> _routeMapUrlCache = {};

  /// Проверяет наличие URL в кеше (синхронно)
  /// Возвращает URL если есть в кеше, иначе null
  String? getCachedRouteMapUrl(int activityId) {
    return _routeMapUrlCache[activityId];
  }

  /// Получает URL сохраненного изображения карты маршрута для активности
  ///
  /// Возвращает:
  /// - URL изображения, если оно сохранено на сервере
  /// - null, если изображение не найдено (нужно генерировать через Mapbox)
  ///
  /// ⚡ PERFORMANCE OPTIMIZATION:
  /// - Использует кеш для избежания повторных запросов
  /// - Не блокирует UI (асинхронный запрос)
  Future<String?> getRouteMapUrl(int activityId) async {
    // Проверяем кеш
    if (_routeMapUrlCache.containsKey(activityId)) {
      return _routeMapUrlCache[activityId];
    }

    try {
      final response = await _api.get(
        '/get_activity_route_map.php',
        queryParams: {'activity_id': activityId.toString()},
      );

      final routeMapUrl = response['route_map_url'] as String?;
      final exists = response['exists'] as bool? ?? false;

      // Кешируем результат (даже если null)
      _routeMapUrlCache[activityId] = exists ? routeMapUrl : null;

      return exists ? routeMapUrl : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ RouteMapService: Ошибка получения URL карты: $e');
      }
      // При ошибке возвращаем null (будет генерироваться через Mapbox)
      _routeMapUrlCache[activityId] = null;
      return null;
    }
  }

  /// Сохраняет изображение карты маршрута на сервер
  ///
  /// Параметры:
  /// - [activityId] - ID активности
  /// - [userId] - ID пользователя (для проверки прав доступа)
  /// - [imageFile] - файл изображения для загрузки
  ///
  /// Возвращает URL сохраненного изображения или null при ошибке
  ///
  /// ⚡ PERFORMANCE OPTIMIZATION:
  /// - Обновляет кеш после успешного сохранения
  /// - Использует multipart/form-data для эффективной загрузки файлов
  Future<String?> saveRouteMapImage({
    required int activityId,
    required int userId,
    required File imageFile,
  }) async {
    try {
      final response = await _api.postMultipart(
        '/save_activity_route_map.php',
        files: {'image': imageFile},
        fields: {
          'activity_id': activityId.toString(),
          'user_id': userId.toString(),
        },
      );

      final routeMapUrl = response['route_map_url'] as String?;
      
      // Обновляем кеш после успешного сохранения
      if (routeMapUrl != null) {
        _routeMapUrlCache[activityId] = routeMapUrl;
      }

      return routeMapUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ RouteMapService: Ошибка сохранения карты: $e');
      }
      return null;
    }
  }

  /// Сохраняет изображение карты маршрута из URL (скачивает и загружает на сервер)
  ///
  /// Используется для сохранения изображений, сгенерированных через Mapbox Static Images API
  ///
  /// Параметры:
  /// - [activityId] - ID активности
  /// - [userId] - ID пользователя
  /// - [mapboxUrl] - URL изображения от Mapbox
  ///
  /// ⚡ PERFORMANCE OPTIMIZATION:
  /// - Скачивает изображение в память без сохранения на диск
  /// - Загружает напрямую на сервер через multipart
  Future<String?> saveRouteMapFromUrl({
    required int activityId,
    required int userId,
    required String mapboxUrl,
  }) async {
    try {
      // Скачиваем изображение из Mapbox
      final response = await http.get(Uri.parse(mapboxUrl));
      
      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('⚠️ RouteMapService: Не удалось скачать изображение с Mapbox');
        }
        return null;
      }

      // Сохраняем во временный файл
      final tempFile = File('${Directory.systemTemp.path}/route_map_$activityId.png');
      await tempFile.writeAsBytes(response.bodyBytes);

      try {
        // Загружаем на сервер
        final savedUrl = await saveRouteMapImage(
          activityId: activityId,
          userId: userId,
          imageFile: tempFile,
        );

        return savedUrl;
      } finally {
        // Удаляем временный файл
        try {
          await tempFile.delete();
        } catch (_) {
          // Игнорируем ошибки удаления
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ RouteMapService: Ошибка сохранения карты из URL: $e');
      }
      return null;
    }
  }

  /// Очищает кеш для конкретной активности
  void clearCache(int activityId) {
    _routeMapUrlCache.remove(activityId);
  }

  /// Очищает весь кеш
  void clearAllCache() {
    _routeMapUrlCache.clear();
  }
}
