import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../../service/api_service.dart';
import '../../../../../../service/auth_service.dart';
import '../../../../../../theme/app_theme.dart';
import '../../../../../../widgets/app_bar.dart';
import '../../../../../../widgets/route_card.dart';
import 'package:flutter/services.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  ЭКРАН «ДЕТАЛИ ТРЕНИРОВОК» С ВКЛАДКАМИ ПО ДАТАМ
///  Загружает и отображает данные тренировок за указанные даты.
/// ─────────────────────────────────────────────────────────────────────────
class TrainingDayTabsScreen extends StatefulWidget {
  const TrainingDayTabsScreen({super.key});

  @override
  State<TrainingDayTabsScreen> createState() => _TrainingDayTabsScreenState();
}

class _TrainingDayTabsScreenState extends State<TrainingDayTabsScreen> {
  // Даты для вкладок: 08.11, 14.11, 15.11 (2025 год)
  final List<DateTime> _dates = [
    DateTime(2025, 11, 8),
    DateTime(2025, 11, 14),
    DateTime(2025, 11, 15),
  ];

  int _selectedIndex = 0;

  static String _dm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const PaceAppBar(
        title: 'Детали тренировок',
        showBottomDivider: false,
      ),
      body: Column(
        children: [
          // ───────────────────────────────────────────────────────────────
          //  СЕГМЕНТИРОВАННЫЙ КОНТРОЛ ДЛЯ ВЫБОРА ДАТЫ
          // ───────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _selectedIndex,
              onValueChanged: (value) {
                if (value != null) {
                  setState(() => _selectedIndex = value);
                }
              },
              children: {
                for (int i = 0; i < _dates.length; i++)
                  i: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      _dm(_dates[i]),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              },
            ),
          ),
          // ───────────────────────────────────────────────────────────────
          //  КОНТЕНТ ВКЛАДКИ С ДАННЫМИ ТРЕНИРОВКИ
          //  Используем key для пересоздания виджета при смене даты
          // ───────────────────────────────────────────────────────────────
          Expanded(
            child: _TrainingTabContent(
              key: ValueKey(_dates[_selectedIndex]),
              date: _dates[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
///  КОНТЕНТ ЭКРАНА: грузим Workout/Distance/HR за день, считаем метрики,
///  показываем карту маршрута (Android/Health Connect).
/// ─────────────────────────────────────────────────────────────────────────
class _TrainingTabContent extends StatefulWidget {
  const _TrainingTabContent({super.key, required this.date});

  final DateTime date;

  @override
  State<_TrainingTabContent> createState() => _TrainingTabContentState();
}

class _TrainingTabContentState extends State<_TrainingTabContent>
    with AutomaticKeepAliveClientMixin {
  final Health _health = Health();

  @override
  bool get wantKeepAlive => true; // Сохраняем загруженные данные при смене вкладок

  bool _busy = false;
  String _status = 'Загружаю данные тренировки…';

  DateTime? _wStart;
  DateTime? _wEnd;
  double _distanceMeters = 0;
  Duration _duration = Duration.zero;
  double? _hrAvg;
  double? _hrMin;
  double? _hrMax;

  List<LatLng> _route = const [];
  List<Map<String, dynamic>> _routeData = const []; // Полные данные с высотой
  String? _routeError; // Ошибка загрузки маршрута

  // ─── Форматтеры
  static String _dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  static String _dm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  static String _hms(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String _km2(double m) {
    final km = m <= 0 ? 0.0 : m / 1000.0;
    return '${km.toStringAsFixed(2)} км';
  }

  static String _pace(Duration dur, double meters) {
    if (dur <= Duration.zero || meters <= 0) return '—';
    final sec = dur.inSeconds.toDouble();
    final secPerKm = sec / (meters / 1000.0);
    final total = secPerKm.round();
    final mm = total ~/ 60, ss = total % 60;
    return '$mm:${ss.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      // 1) Разрешения
      await _health.configure();
      final types = <HealthDataType>[
        HealthDataType.WORKOUT,
        HealthDataType.DISTANCE_DELTA,
        HealthDataType.HEART_RATE,
      ];
      final ok = await _health.requestAuthorization(
        types,
        permissions: List.generate(types.length, (_) => HealthDataAccess.READ),
      );
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _status =
              'Нет доступа к данным. Проверьте разрешения Health Connect/Здоровье.';
        });
        return;
      }

      // 2) Окно дня
      final startOfDay = DateTime(
        widget.date.year,
        widget.date.month,
        widget.date.day,
        0,
        0,
        0,
      );
      final endOfDay = DateTime(
        widget.date.year,
        widget.date.month,
        widget.date.day,
        23,
        59,
        59,
      );

      // 3) WORKOUT за день
      final workouts = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.WORKOUT],
        startTime: startOfDay,
        endTime: endOfDay,
      );

      if (!mounted) return;

      if (workouts.isEmpty) {
        setState(() {
          _status = 'За ${_dmy(widget.date)} тренировки не найдены.';
        });
        return;
      }

      workouts.sort((a, b) => a.dateTo.compareTo(b.dateTo));
      final w = workouts.last; // последняя по времени завершения
      final wStart = w.dateFrom;
      final wEnd = w.dateTo;

      // Небольшой запас для поиска маршрута
      final routeStart = wStart.subtract(const Duration(minutes: 5));
      final routeEnd = wEnd.add(const Duration(minutes: 5));

      // 4) Дистанция внутри окна тренировки
      final dists = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.DISTANCE_DELTA],
        startTime: wStart,
        endTime: wEnd,
      );
      double distance = 0;
      for (final p in dists) {
        final v = p.value;
        if (v is NumericHealthValue) distance += v.numericValue.toDouble();
      }

      // 5) Средний, минимальный и максимальный пульс
      final hrPoints = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.HEART_RATE],
        startTime: wStart,
        endTime: wEnd,
      );
      double? hrAvg;
      double? hrMin;
      double? hrMax;
      if (hrPoints.isNotEmpty) {
        final hrValues = <double>[];
        for (final p in hrPoints) {
          final v = p.value;
          if (v is NumericHealthValue) {
            hrValues.add(v.numericValue.toDouble());
          }
        }
        if (hrValues.isNotEmpty) {
          hrAvg = hrValues.reduce((a, b) => a + b) / hrValues.length;
          hrMin = hrValues.reduce((a, b) => a < b ? a : b);
          hrMax = hrValues.reduce((a, b) => a > b ? a : b);
        }
      }

      // 6) Длительность по самой сессии
      final dur = wEnd.difference(wStart);

      // 7) Маршрут (Android/Health Connect) с высотой
      List<LatLng> route = const [];
      List<Map<String, dynamic>> routeData = const [];
      String? routeError;
      if (Platform.isAndroid) {
        try {
          const channel = MethodChannel('paceup/route');
          final res = await channel.invokeMethod<List<dynamic>>(
            'getExerciseRoute',
            <String, dynamic>{
              'start': routeStart.millisecondsSinceEpoch,
              'end': routeEnd.millisecondsSinceEpoch,
            },
          );

          if (res != null && res.isNotEmpty) {
            // Получаем полные данные с высотой
            routeData = res.map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              return {
                'lat': (m['lat'] as num).toDouble(),
                'lng': (m['lng'] as num).toDouble(),
                'alt': (m['alt'] as num?)?.toDouble(), // Высота
              };
            }).toList();

            // Для отображения на карте (только координаты)
            route = routeData
                .where((p) => p['lat'] != null && p['lng'] != null)
                .map((p) => LatLng(p['lat']!, p['lng']!))
                .toList();
          } else {
            // Маршрут не найден - возможно, требуется одноразовое согласие
            // или маршрут просто отсутствует в Health Connect
            routeError =
                'Маршрут не найден. Возможно, требуется разрешение в Health Connect или маршрут не был записан.';
          }
        } on PlatformException catch (e) {
          // Обрабатываем специфичные ошибки от нативной стороны
          if (e.code == 'consent_denied') {
            routeError =
                'Требуется одноразовое разрешение на доступ к маршруту в Health Connect.';
          } else if (e.code == 'no_permission') {
            routeError =
                'Нет разрешения на чтение маршрутов. Проверьте настройки Health Connect.';
          } else if (e.code == 'health_connect_unavailable') {
            routeError = 'Health Connect недоступен на этом устройстве.';
          } else {
            routeError = 'Ошибка загрузки маршрута: ${e.message ?? e.code}';
          }
          debugPrint('Ошибка загрузки маршрута: ${e.code} - ${e.message}');
        } catch (e) {
          // Общая ошибка
          routeError = 'Ошибка загрузки маршрута: $e';
          debugPrint('Ошибка загрузки маршрута: $e');
        }
      }

      setState(() {
        _wStart = wStart;
        _wEnd = wEnd;
        _distanceMeters = distance;
        _duration = dur;
        _hrAvg = hrAvg;
        _hrMin = hrMin;
        _hrMax = hrMax;
        _route = route;
        _routeData = routeData;
        _routeError = routeError;
        _status = 'Готово';
      });

      // ─── Сохраняем данные в БД после успешной загрузки ───
      await _saveToDatabase(w);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Ошибка загрузки: $e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// ─────────────────────────────────────────────────────────────────────────
  /// СОХРАНЕНИЕ ДАННЫХ ТРЕНИРОВКИ В БАЗУ ДАННЫХ
  ///
  /// Преобразует данные из Health Connect/HealthKit в формат БД и отправляет
  /// на сервер через API endpoint create_activity.php
  /// ─────────────────────────────────────────────────────────────────────────
  Future<void> _saveToDatabase(HealthDataPoint workout) async {
    // Проверяем наличие минимальных данных для сохранения
    if (_wStart == null || _wEnd == null || _distanceMeters <= 0) {
      return; // Нет данных для сохранения
    }

    try {
      // Получаем ID пользователя
      final authService = AuthService();
      final userId = await authService.getUserId();
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ошибка: пользователь не авторизован'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // ─── Определяем тип активности из workout type ───
      String activityType = _mapWorkoutTypeToActivityType(workout);

      // ─── Формируем params (JSON с stats) ───
      // Формат должен быть: [{"stats": {...}}] для совместимости с activities_lenta.php
      final stats = <String, dynamic>{
        'distance': _distanceMeters,
        'duration': _duration.inSeconds,
      };

      // Добавляем пульс (средний, минимальный, максимальный)
      if (_hrAvg != null) {
        stats['avgHeartRate'] = _hrAvg;
      }
      if (_hrMin != null) {
        stats['minHeartRate'] = _hrMin;
      }
      if (_hrMax != null) {
        stats['maxHeartRate'] = _hrMax;
      }

      // Добавляем временные метки в ISO8601 формате
      stats['startedAt'] = _wStart!.toIso8601String();
      stats['finishedAt'] = _wEnd!.toIso8601String();

      // Вычисляем среднюю скорость и темп (если есть дистанция и время)
      if (_distanceMeters > 0 && _duration.inSeconds > 0) {
        final avgSpeed = (_distanceMeters / _duration.inSeconds) * 3.6; // км/ч
        final avgPace =
            (_duration.inSeconds / (_distanceMeters / 1000.0)) / 60.0; // мин/км
        stats['avgSpeed'] = avgSpeed;
        stats['avgPace'] = avgPace;
      }

      // ─── Вычисляем статистику по высоте ───
      if (_routeData.isNotEmpty) {
        final altitudeStats = _calculateAltitudeStats(
          _routeData,
          _distanceMeters,
        );
        stats.addAll(altitudeStats);
      }

      final params = jsonEncode([
        {'stats': stats},
      ]);

      // ─── Формируем points (массив строк "LatLng(lat, lng)") ───
      final pointsList = _route
          .map((p) => 'LatLng(${p.latitude}, ${p.longitude})')
          .toList();
      final points = jsonEncode(pointsList);

      // ─── Форматируем даты в формат MySQL (YYYY-MM-DD HH:mm:ss) ───
      String formatDateTime(DateTime dt) {
        return '${dt.year}-'
            '${dt.month.toString().padLeft(2, '0')}-'
            '${dt.day.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:'
            '${dt.minute.toString().padLeft(2, '0')}:'
            '${dt.second.toString().padLeft(2, '0')}';
      }

      // ─── Подготавливаем данные для отправки ───
      final body = <String, dynamic>{
        'user_id': userId,
        'type': activityType,
        'date_start': formatDateTime(_wStart!),
        'date_end': formatDateTime(_wEnd!),
        'params': params,
        'points': points,
        'privacy': '0', // По умолчанию публичная
        'equip_id': 0, // Нет привязки к оборудованию
        'media': '', // Нет медиа файлов
      };

      // ─── Отправляем на сервер ───
      final api = ApiService();
      final response = await api.post('/create_activity.php', body: body);

      if (response['success'] == true) {
        // Успешно сохранено
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Тренировка сохранена в базу данных'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Ошибка сохранения
        final errorMsg = response['message'] ?? 'Неизвестная ошибка';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка сохранения: $errorMsg'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Ошибка при сохранении (логируем, но не показываем пользователю,
      // чтобы не мешать просмотру данных)
      debugPrint('Ошибка сохранения тренировки: $e');
    }
  }

  /// ─────────────────────────────────────────────────────────────────────────
  /// ВЫЧИСЛЕНИЕ СТАТИСТИКИ ПО ВЫСОТЕ
  ///
  /// Вычисляет minAltitude, maxAltitude, cumulativeElevationGain,
  /// cumulativeElevationLoss, altPerKm из точек маршрута с высотой
  /// ─────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> _calculateAltitudeStats(
    List<Map<String, dynamic>> routeData,
    double totalDistanceMeters,
  ) {
    final result = <String, dynamic>{};

    // Фильтруем точки с валидной высотой (alt != null и alt >= 0)
    final validPoints = routeData
        .where((p) => p['alt'] != null && (p['alt'] as num).toDouble() >= 0)
        .toList();

    if (validPoints.isEmpty) {
      // Если нет данных о высоте, возвращаем пустые значения
      return {
        'minAltitude': 0.0,
        'minAltitudeCoords': null,
        'maxAltitude': 0.0,
        'maxAltitudeCoords': null,
        'cumulativeElevationGain': 0.0,
        'cumulativeElevationLoss': 0.0,
        'altPerKm': <String, double>{},
      };
    }

    // Находим минимальную и максимальную высоту
    double minAlt = double.infinity;
    double maxAlt = double.negativeInfinity;
    Map<String, dynamic>? minAltCoords;
    Map<String, dynamic>? maxAltCoords;

    for (final point in validPoints) {
      final alt = (point['alt'] as num).toDouble();
      if (alt < minAlt) {
        minAlt = alt;
        minAltCoords = {'lat': point['lat'], 'lng': point['lng']};
      }
      if (alt > maxAlt) {
        maxAlt = alt;
        maxAltCoords = {'lat': point['lat'], 'lng': point['lng']};
      }
    }

    result['minAltitude'] = minAlt.isFinite ? minAlt : 0.0;
    result['minAltitudeCoords'] = minAltCoords;
    result['maxAltitude'] = maxAlt.isFinite ? maxAlt : 0.0;
    result['maxAltitudeCoords'] = maxAltCoords;

    // Вычисляем cumulative elevation gain и loss
    double cumulativeGain = 0.0;
    double cumulativeLoss = 0.0;

    for (int i = 1; i < validPoints.length; i++) {
      final prevAlt = (validPoints[i - 1]['alt'] as num).toDouble();
      final currAlt = (validPoints[i]['alt'] as num).toDouble();
      final diff = currAlt - prevAlt;

      if (diff > 0) {
        cumulativeGain += diff;
      } else if (diff < 0) {
        cumulativeLoss += diff.abs();
      }
    }

    result['cumulativeElevationGain'] = cumulativeGain;
    result['cumulativeElevationLoss'] = cumulativeLoss;

    // ─── Вычисляем среднюю высоту по километрам ───
    final altPerKm = <String, double>{};

    if (totalDistanceMeters > 0 && validPoints.length > 1) {
      // Приблизительно распределяем точки по километрам
      // Предполагаем равномерное распределение точек по дистанции
      final totalKm = totalDistanceMeters / 1000.0;
      final pointsPerKm = (validPoints.length / totalKm).ceil();

      int kmIndex = 1;
      final currentKmAlts = <double>[];

      for (int i = 0; i < validPoints.length; i++) {
        final alt = (validPoints[i]['alt'] as num).toDouble();
        currentKmAlts.add(alt);

        // Каждые pointsPerKm точек считаем за километр
        if (currentKmAlts.length >= pointsPerKm ||
            i == validPoints.length - 1) {
          if (currentKmAlts.isNotEmpty) {
            final avgAlt =
                currentKmAlts.reduce((a, b) => a + b) / currentKmAlts.length;
            final kmKey =
                i == validPoints.length - 1 && (totalKm - kmIndex + 1) < 1.0
                ? 'km_${kmIndex}_partial'
                : 'km_$kmIndex';
            altPerKm[kmKey] = avgAlt;

            currentKmAlts.clear();
            kmIndex++;
          }
        }
      }
    }

    result['altPerKm'] = altPerKm;

    return result;
  }

  /// ─────────────────────────────────────────────────────────────────────────
  /// МАППИНГ ТИПА ТРЕНИРОВКИ ИЗ HEALTH CONNECT/HEALTHKIT
  ///
  /// Преобразует тип workout из Health Connect/HealthKit в формат БД:
  /// 'run', 'bike', 'swim'
  /// ─────────────────────────────────────────────────────────────────────────
  String _mapWorkoutTypeToActivityType(HealthDataPoint workout) {
    // Пытаемся получить тип из workout value
    final value = workout.value;
    if (value is WorkoutHealthValue) {
      // Используем workoutActivityType.name для определения типа
      final activityTypeName = value.workoutActivityType.name.toLowerCase();

      // Маппинг типов активности на типы в БД
      if (activityTypeName.contains('running') ||
          activityTypeName.contains('walking') ||
          activityTypeName.contains('hiking') ||
          activityTypeName.contains('jogging')) {
        return 'run';
      } else if (activityTypeName.contains('cycling') ||
          activityTypeName.contains('bike')) {
        return 'bike';
      } else if (activityTypeName.contains('swimming') ||
          activityTypeName.contains('swim')) {
        return 'swim';
      }
    }

    // Если не удалось определить тип, используем 'run' по умолчанию
    return 'run';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Обязательно для AutomaticKeepAliveClientMixin

    // Формат даты для отображения: "08.11" (без года)
    final dateText = _dm(widget.date);

    // Подготовим карточки с РАЗНЫМИ тинтами (как в connected_trackers_screen)
    final mDate = _M(
      icon: CupertinoIcons.calendar_today,
      label: 'Дата',
      value: dateText,
      tint: CupertinoColors.systemIndigo,
    );
    final mTime = _M(
      icon: CupertinoIcons.time,
      label: 'Время',
      value: (_wStart != null && _wEnd != null)
          ? '${_hm(_wStart!)} - ${_hm(_wEnd!)}'
          : '—',
      tint: CupertinoColors.systemPurple,
    );
    final mDist = _M(
      icon: CupertinoIcons.location,
      label: 'Дистанция',
      value: _km2(_distanceMeters),
      tint: CupertinoColors.activeBlue,
    );
    final mDur = _M(
      icon: CupertinoIcons.timer,
      label: 'Длительность',
      value: _hms(_duration),
      tint: CupertinoColors.systemOrange,
    );
    final mPace = _M(
      icon: CupertinoIcons.speedometer,
      label: 'Темп',
      value: _pace(_duration, _distanceMeters),
      tint: CupertinoColors.systemGreen,
    );
    final mHr = _M(
      icon: CupertinoIcons.heart_fill,
      label: 'Средний пульс',
      value: _hrAvg != null ? _hrAvg!.toStringAsFixed(0) : '—',
      tint: CupertinoColors.systemRed,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ── Статус
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Тренировка $dateText', style: AppTextStyles.h14w6),
              const SizedBox(height: 6),
              Text(_status, style: AppTextStyles.h13w4),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Метрики (с разными цветами карточек)
        _MetricBlock(items: [mDate, mTime, mDist, mDur, mPace, mHr]),

        const SizedBox(height: 12),

        // ── Карта (Android)
        if (Platform.isAndroid)
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Маршрут', style: AppTextStyles.h14w6),
                const SizedBox(height: 8),
                if (_route.length >= 2)
                  // Обрезаем карту по скругленным углам контейнера
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: RouteCard(points: _route, height: 220),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          CupertinoIcons.info_circle,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _routeError ??
                                'Маршрут не найден. Возможно, у источника нет трека, требуется разовый доступ в Health Connect, или данные ещё не пришли.',
                            style: AppTextStyles.h12w4Ter.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            padding: const EdgeInsets.all(12),
            child: const Text(
              'Карта маршрута доступна на Android (Health Connect). На iOS экран без карты.',
              style: AppTextStyles.h12w4Ter,
            ),
          ),
      ],
    );
  }
}

/// ── Сетка метрик, поддерживает индивидуальный tint у каждой карточки
class _MetricBlock extends StatelessWidget {
  const _MetricBlock({required this.items});
  final List<_M> items;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final itemWidth = width >= 420
        ? (width - 16 * 2 - 8 * 2) / 3
        : (width >= 360 ? (width - 16 * 2 - 8) / 2 : width - 16 * 2);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((m) {
        final bg = m.tint.withValues(alpha: 0.06);
        final br = m.tint.withValues(alpha: 0.22);
        return SizedBox(
          width: itemWidth,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: br, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(m.icon, size: 18, color: m.tint),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.label,
                        style: AppTextStyles.h12w4Ter,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.value,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _M {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  const _M({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });
}
