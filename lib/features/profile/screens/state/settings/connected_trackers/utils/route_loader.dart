// ────────────────────────────────────────────────────────────────────────────
//  УТИЛИТА ДЛЯ ЗАГРУЗКИ МАРШРУТА ИЗ HEALTH CONNECT
//
//  Загружает маршрут тренировки из Health Connect (Android) или Apple Health (iOS)
//  с обработкой разрешений и ошибок
// ────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// РЕЗУЛЬТАТ ЗАГРУЗКИ МАРШРУТА
/// ─────────────────────────────────────────────────────────────────────────
class RouteLoadResult {
  final List<LatLng> route;
  final List<Map<String, dynamic>> routeData;
  final String? error;
  final bool requiresConsent;

  const RouteLoadResult({
    required this.route,
    required this.routeData,
    this.error,
    this.requiresConsent = false,
  });

  bool get hasRoute => route.isNotEmpty;
  bool get hasError => error != null;
}

/// ─────────────────────────────────────────────────────────────────────────
/// ЗАГРУЗКА МАРШРУТА ИЗ HEALTH CONNECT (ANDROID) ИЛИ HEALTHKIT (iOS)
///
/// Загружает маршрут тренировки за указанный период времени
/// Обрабатывает одноразовое согласие пользователя на доступ к маршруту
/// Работает на обеих платформах через единый MethodChannel
/// ─────────────────────────────────────────────────────────────────────────
Future<RouteLoadResult> loadRouteFromHealthConnect(
  DateTime workoutStart,
  DateTime workoutEnd,
) async {
  // Проверяем платформу - теперь поддерживаем обе
  if (!Platform.isAndroid && !Platform.isIOS) {
    return const RouteLoadResult(
      route: [],
      routeData: [],
      error: 'Маршрут доступен только на Android (Health Connect) и iOS (HealthKit)',
    );
  }

  try {
    // Расширяем окно поиска на 5 минут до и после тренировки
    final routeStart = workoutStart.subtract(const Duration(minutes: 5));
    final routeEnd = workoutEnd.add(const Duration(minutes: 5));

    const channel = MethodChannel('paceup/route');
    final res = await channel.invokeMethod<List<dynamic>>(
      'getExerciseRoute',
      <String, dynamic>{
        'start': routeStart.millisecondsSinceEpoch,
        'end': routeEnd.millisecondsSinceEpoch,
      },
    );

    // Обрабатываем ошибки от нативной стороны
    if (res == null) {
      return const RouteLoadResult(
        route: [],
        routeData: [],
        error: 'Маршрут не найден для данной тренировки',
      );
    }

    if (res.isEmpty) {
      return const RouteLoadResult(
        route: [],
        routeData: [],
        error: 'Маршрут отсутствует в Health Connect',
      );
    }

    // Преобразуем данные маршрута
    final routeData = res.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return {
        'lat': (m['lat'] as num).toDouble(),
        'lng': (m['lng'] as num).toDouble(),
        'alt': (m['alt'] as num?)?.toDouble(),
        't': (m['t'] as num?)?.toInt(),
      };
    }).toList();

    final route = routeData
        .where((p) => p['lat'] != null && p['lng'] != null)
        .map((p) => LatLng(
              (p['lat'] as num).toDouble(),
              (p['lng'] as num).toDouble(),
            ))
        .toList();

    return RouteLoadResult(
      route: route,
      routeData: routeData,
    );
  } on PlatformException catch (e) {
    // Обрабатываем специфичные ошибки от нативной стороны
    String errorMessage;
    bool requiresConsent = false;

    switch (e.code) {
      case 'consent_denied':
        errorMessage = Platform.isAndroid
            ? 'Требуется одноразовое разрешение на доступ к маршруту в Health Connect.'
            : 'Требуется разрешение на доступ к маршруту в Health.';
        requiresConsent = true;
        break;
      case 'no_permission':
        errorMessage = Platform.isAndroid
            ? 'Нет разрешения на чтение маршрутов. Проверьте настройки Health Connect.'
            : 'Нет разрешения на чтение маршрутов. Проверьте настройки Health.';
        break;
      case 'health_connect_unavailable':
      case 'healthkit_unavailable':
        errorMessage = Platform.isAndroid
            ? 'Health Connect недоступен на этом устройстве.'
            : 'HealthKit недоступен на этом устройстве.';
        break;
      case 'bad_args':
        errorMessage = 'Неверные параметры запроса маршрута.';
        break;
      case 'permission_error':
      case 'query_error':
      case 'route_error':
        errorMessage = 'Ошибка загрузки маршрута: ${e.message ?? e.code}';
        break;
      default:
        errorMessage = 'Ошибка загрузки маршрута: ${e.message ?? e.code}';
    }

    return RouteLoadResult(
      route: const [],
      routeData: const [],
      error: errorMessage,
      requiresConsent: requiresConsent,
    );
  } catch (e) {
    // Общая ошибка
    return RouteLoadResult(
      route: const [],
      routeData: const [],
      error: 'Ошибка загрузки маршрута: $e',
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// ЗАГРУЗКА МАРШРУТА ДЛЯ ВСЕХ ТИПОВ ТРЕНИРОВОК
///
/// Поддерживает: бег, велосипед, лыжи, ходьба
/// Маршрут загружается по времени тренировки, независимо от типа
/// 
/// Работает на Android (Health Connect) и iOS (HealthKit)
/// ─────────────────────────────────────────────────────────────────────────
Future<RouteLoadResult> loadWorkoutRoute(
  DateTime workoutStart,
  DateTime workoutEnd,
  String workoutType, // 'run', 'bike', 'ski', 'swim', 'walk'
) async {
  // Проверяем платформу - поддерживаем Android и iOS
  if (!Platform.isAndroid && !Platform.isIOS) {
    return const RouteLoadResult(
      route: [],
      routeData: [],
      error: 'Маршрут доступен только на Android (Health Connect) и iOS (HealthKit).',
    );
  }

  // Проверяем, поддерживается ли маршрут для данного типа тренировки
  // Для плавания маршрут обычно недоступен (GPS не работает под водой)
  if (workoutType == 'swim') {
    return const RouteLoadResult(
      route: [],
      routeData: [],
      error: 'Маршрут недоступен для плавания (GPS не работает под водой)',
    );
  }

  // Для остальных типов тренировок (бег, велосипед, лыжи, ходьба) загружаем маршрут
  return loadRouteFromHealthConnect(workoutStart, workoutEnd);
}
