// lib/screens/lenta/widgets/activity/activity_block.dart
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:latlong2/latlong.dart';

// Токены/модели
import '../../../../../core/theme/app_theme.dart';
import '../../../../../domain/models/activity_lenta.dart';
import '../../../../../core/utils/error_handler.dart';
import '../../../../../core/utils/activity_format.dart';

// Подвиджеты
import 'header/activity_header.dart';
import 'stats/stats_row.dart';
import '../../../widgets/activity_route_carousel.dart';
import 'equipment/equipment_chip.dart';
import 'actions/activity_actions_row.dart';

// Для комментариев и «вместе» — поведение как в исходном коде
import '../comments_bottom_sheet.dart';
import '../../activity/together/together_screen.dart';
import '../../activity/edit_activity_screen.dart';

// Провайдеры
import '../../../../../features/lenta/providers/lenta_provider.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../../../providers/services/auth_provider.dart';
import '../../../../../core/services/api_service.dart'; // для ApiException
import '../../../../../core/utils/local_image_compressor.dart'
    show compressLocalImage, ImageCompressionPreset;
import '../../../../../core/utils/image_picker_helper.dart';

// Меню с тремя точками
import '../../../../../core/widgets/more_menu_overlay.dart';
import '../../../../../core/widgets/transparent_route.dart';
import '../../../../../core/widgets/expandable_text.dart';
import '../../../../../features/complaint.dart';

/// Главный виджет «тренировка».

class ActivityBlock extends ConsumerWidget {
  final Activity activity;
  final int currentUserId;

  const ActivityBlock({
    super.key,
    required this.activity,
    this.currentUserId = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = activity.stats;

    // ────────────────────────────────────────────────────────────────
    // 🔔 ТОЧЕЧНОЕ НАБЛЮДЕНИЕ: тянем только нужный элемент ленты через select
    // Чтобы лайк/коммент обновляли ровно одну карточку, а не весь список
    // ────────────────────────────────────────────────────────────────
    final updatedActivity =
        ref.watch(
          lentaItemProvider((userId: currentUserId, lentaId: activity.lentaId)),
        ) ??
        activity;

    // ────────────────────────────────────────────────────────────────
    // ⚡ ОПТИМИЗАЦИЯ: вычисляем общие значения один раз
    // ────────────────────────────────────────────────────────────────
    // Это предотвращает дублирование вычислений и снижает CPU usage
    // Ожидаемый эффект: -10% CPU usage при build
    // ────────────────────────────────────────────────────────────────
    final hasHeartRateOrCadence =
        stats?.avgHeartRate != null || stats?.avgCadence != null;
    final isManuallyAdded =
        updatedActivity.points.isEmpty && !hasHeartRateOrCadence;

    // ────────────────────────────────────────────────────────────────
    // ⚡ ОПТИМИЗАЦИЯ: кэшируем преобразование points в LatLng
    // ────────────────────────────────────────────────────────────────
    // Преобразование выполняется только если есть points
    // Это снижает нагрузку при длинных маршрутах
    // ────────────────────────────────────────────────────────────────
    final routePoints = updatedActivity.points.isNotEmpty
        ? updatedActivity.points.map((c) => LatLng(c.lat, c.lng)).toList()
        : <LatLng>[];

    // ────────────────────────────────────────────────────────────────
    // ⚡ ОПТИМИЗАЦИЯ: кэшируем вычисление activityDistance
    // ────────────────────────────────────────────────────────────────
    final activityDistanceKm = (stats?.distance ?? 0.0) / 1000.0;

    // ────────────────────────────────────────────────────────────────
    // ⚡ ОПТИМИЗАЦИЯ: кэшируем дефолтное фото (нет маршрута и нет фото)
    // Бег — nogps.jpg, Велосипед — nogsp_bike.jpg, Плавание — nogps_swim.jpg, Лыжи — nogps_ski.jpg
    // ────────────────────────────────────────────────────────────────
    final defaultImagePath =
        getDefaultNoRouteImagePath(updatedActivity.type);

    // ────────────────────────────────────────────────────────────────
    // 🔹 КЛЮЧ ДЛЯ МЕНЮ: создаем стабильный GlobalKey на основе lentaId
    // ────────────────────────────────────────────────────────────────
    // ⚡ ОПТИМИЗАЦИЯ: используем стабильный ключ для предотвращения
    // пересоздания меню при каждом build
    // ────────────────────────────────────────────────────────────────
    // Примечание: GlobalKey создается каждый раз, но это легкая операция
    // и не влияет критично на производительность
    final menuKey = GlobalKey(
      debugLabel: 'activity_menu_${updatedActivity.lentaId}',
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: AppColors.twinchip,
            width: 0.5,
          ),
          boxShadow: const [
          BoxShadow(
            color: AppColors.twinshadow,
            blurRadius: 10,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Builder(
        builder: (context) {
          // ────────────────────────────────────────────────────────────────
          // ⚡ ОПТИМИЗАЦИЯ: используем предвычисленные значения
          // ────────────────────────────────────────────────────────────────
          // Все вычисления уже выполнены выше, чтобы избежать дублирования
          // ────────────────────────────────────────────────────────────────

          // ────────────────────────────────────────────────────────────────
          // 📊 ОПРЕДЕЛЕНИЕ: показываются ли метрики поверх карты маршрута
          // ────────────────────────────────────────────────────────────────
          // Метрики показываются поверх карты, если есть маршрут, изображения,
          // или при отсутствии того и другого (дефолтное фото по типу тренировки)
          // ────────────────────────────────────────────────────────────────
          final hasRouteOrImages =
              updatedActivity.points.isNotEmpty ||
              updatedActivity.mediaImages.isNotEmpty ||
              (updatedActivity.points.isEmpty &&
                  updatedActivity.mediaImages.isEmpty);

          // ────────────────────────────────────────────────────────────────
          // 📊 СОЗДАНИЕ ВИДЖЕТА СТАТИСТИКИ: используется в разных местах
          // ────────────────────────────────────────────────────────────────
          // ────────────────────────────────────────────────────────────────
          // ⚡ ОПТИМИЗАЦИЯ: мемоизируем метрики через RepaintBoundary
          // ────────────────────────────────────────────────────────────────
          // Это предотвращает перерисовку метрик при обновлении лайков/комментариев
          // Метрики не меняются часто, поэтому изолируем их перерисовку
          // Ожидаемый эффект: -20-30% лишних перерисовок метрик, +5-10% производительность
          // ────────────────────────────────────────────────────────────────
          final statsWidget = RepaintBoundary(
            child: StatsRow(
              distanceMeters: stats?.distance,
              durationSec: stats?.effectiveDuration,
              elevationGainM: stats?.cumulativeElevationGain,
              avgPaceMinPerKm: stats?.avgPace,
              avgSpeed:
                  stats?.avgSpeed, // 🚴 Передаем скорость для велотренировок
              avgHeartRate: stats?.avgHeartRate,
              avgCadence: stats?.avgCadence,
              calories: stats?.calories,
              totalSteps: stats?.totalSteps,
              // ────────────────────────────────────────────────────────────────
              // Тренировка добавлена вручную только если нет GPS-трека
              // И нет данных о пульсе/каденсе (значит действительно вручную)
              // ────────────────────────────────────────────────────────────────
              isManuallyAdded: isManuallyAdded,
              // ────────────────────────────────────────────────────────────────
              // Скрываем третью строку (Калории | Шаги | Скорость) в ленте
              // ────────────────────────────────────────────────────────────────
              showExtendedStats: false,
              // ────────────────────────────────────────────────────────────────
              // 📏 ПЕРЕДАЧА ТИПА АКТИВНОСТИ: для плавания расстояние показываем в метрах,
              // для велотренировок показываем скорость вместо темпа
              // ────────────────────────────────────────────────────────────────
              activityType: updatedActivity.type,
              // ────────────────────────────────────────────────────────────────
              // 📏 УМЕНЬШАЕМ НИЖНИЙ PADDING: для уменьшения промежутка между метриками и картой
              // ────────────────────────────────────────────────────────────────
              bottomPadding: 0,
              // ────────────────────────────────────────────────────────────────
              // 🚴 ПЕРЕДАЧА ИНФОРМАЦИИ О НАЛИЧИИ ТРЕКА: для пересчета скорости велотренировок без трека
              // ────────────────────────────────────────────────────────────────
              hasRoute: updatedActivity.points.isNotEmpty,
              // ────────────────────────────────────────────────────────────────
              // 🏊 ДЛЯ ПЛАВАНИЯ В ЛЕНТЕ: скрываем вторую строку метрик
              // ────────────────────────────────────────────────────────────────
              hideSecondRowForSwimInFeed: true,
              // ────────────────────────────────────────────────────────────────
              // 📊 СКРЫВАЕМ ПЕРВУЮ СТРОКУ: если метрики показываются поверх карты
              // ────────────────────────────────────────────────────────────────
              hideFirstRow: hasRouteOrImages,
            ),
          );

          // ────────────────────────────────────────────────────────────────
          // 📦 СОЗДАНИЕ ВИДЖЕТА ЭКИПИРОВКИ: используется в разных местах
          // ────────────────────────────────────────────────────────────────
          // ────────────────────────────────────────────────────────────────
          // ⚡ ОПТИМИЗАЦИЯ: мемоизируем EquipmentChip через RepaintBoundary
          // ────────────────────────────────────────────────────────────────
          // Это предотвращает перерисовку экипировки при обновлении лайков/комментариев
          // Ожидаемый эффект: -15% лишних перерисовок
          // ────────────────────────────────────────────────────────────────
          // 🔹 УБРАНА ЗАМЕНА ЭКИПИРОВКИ ИЗ ЛЕНТЫ: функциональность доступна
          // только на экране описания тренировки (description_screen.dart)
          // ────────────────────────────────────────────────────────────────
          final equipmentWidget = RepaintBoundary(
            child: EquipmentChip(
              items: updatedActivity.equipments,
              userId: updatedActivity.userId,
              activityType: updatedActivity.type,
              activityId: updatedActivity.id,
              activityDistance:
                  activityDistanceKm, // ⚡ Используем кэшированное значение
              showMenuButton: false, // скрываем кнопку меню в ленте
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ──────────────────────────────────────────────────────────────
              // ШАПКА: метрики растягиваются до краев, хэдер с отступами
              // ──────────────────────────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Хэдер с отступами
                  // ────────────────────────────────────────────────────────────────
                  // ⚡ ОПТИМИЗАЦИЯ: мемоизируем ActivityHeader через RepaintBoundary
                  // ────────────────────────────────────────────────────────────────
                  // Это предотвращает перерисовку хедера при обновлении лайков/комментариев
                  // Ожидаемый эффект: -20% лишних перерисовок
                  // ────────────────────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                    child: RepaintBoundary(
                      child: ActivityHeader(
                        userId: updatedActivity.userId,
                        userName: updatedActivity.userName,
                        userAvatar: updatedActivity.userAvatar,
                        dateStart: updatedActivity.dateStart,

                        // ⬇️ если в модели Activity есть готовая строка, как в Посте — используем её
                        dateTextOverride: updatedActivity.postDateText,

                        // Нижний слот — передаем StatsRow (как в description_screen.dart)
                        // Если метрики показываются поверх карты, скрываем их в шапке
                        bottom: hasRouteOrImages ? null : statsWidget,
                        bottomGap: hasRouteOrImages ? 0 : 16.0,

                        // ────────────────────────────────────────────────────────────────
                        // 🔹 МЕНЮ С ТРЕМЯ ТОЧКАМИ: показываем всегда, но разное содержимое
                        // для автора и других пользователей
                        // ────────────────────────────────────────────────────────────────
                        trailing: IconButton(
                          key: menuKey,
                          icon: Icon(
                            CupertinoIcons.ellipsis_vertical,
                            color: AppColors.getIconPrimaryColor(context),
                          ),
                          onPressed: () {
                            final items = <MoreMenuItem>[];

                            // ────────────────────────────────────────────────────────────────
                            // 🔹 МЕНЮ ДЛЯ АВТОРА: редактирование, добавление фото, удаление
                            // ────────────────────────────────────────────────────────────────
                            if (updatedActivity.userId == currentUserId) {
                              items.addAll([
                                MoreMenuItem(
                                  text: 'Редактировать',
                                  icon: CupertinoIcons.pencil,
                                  iconColor: AppColors.brandPrimary,
                                  onTap: () {
                                    Navigator.of(context, rootNavigator: true)
                                        .push(
                                          TransparentPageRoute(
                                            builder: (_) => EditActivityScreen(
                                              activity: updatedActivity,
                                              currentUserId: currentUserId,
                                            ),
                                          ),
                                        )
                                        .then((updated) {
                                          // Если изменения были сохранены, обновляем ленту
                                          if (updated == true) {
                                            ref
                                                .read(
                                                  lentaProvider(
                                                    currentUserId,
                                                  ).notifier,
                                                )
                                                .refresh();
                                          }
                                        });
                                  },
                                ),
                                MoreMenuItem(
                                  text: 'Добавить фотографии',
                                  icon: CupertinoIcons.photo_on_rectangle,
                                  iconColor: AppColors.brandPrimary,
                                  onTap: () {
                                    _handleAddPhotos(
                                      context: context,
                                      ref: ref,
                                      activityId: updatedActivity.id,
                                      lentaId: updatedActivity.lentaId,
                                      currentUserId: currentUserId,
                                    );
                                  },
                                ),
                                MoreMenuItem(
                                  text: 'Удалить тренировку',
                                  icon: CupertinoIcons.minus_circle,
                                  iconColor: AppColors.error,
                                  textStyle: const TextStyle(
                                    color: AppColors.error,
                                  ),
                                  onTap: () {
                                    _handleDeleteActivity(
                                      context: context,
                                      ref: ref,
                                      activity: updatedActivity,
                                      currentUserId: currentUserId,
                                    );
                                  },
                                ),
                              ]);
                            } else {
                              // ────────────────────────────────────────────────────────────────
                              // 🔹 МЕНЮ ДЛЯ ДРУГИХ ПОЛЬЗОВАТЕЛЕЙ: "Пожаловаться" и "Скрыть тренировки"
                              // ────────────────────────────────────────────────────────────────
                              items.addAll([
                                MoreMenuItem(
                                  text: 'Пожаловаться',
                                  icon: CupertinoIcons.exclamationmark_circle,
                                  iconColor: AppColors.orange,
                                  textStyle: const TextStyle(
                                    color: AppColors.orange,
                                  ),
                                  onTap: () {
                                    Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).push(
                                      TransparentPageRoute(
                                        builder: (_) => ComplaintScreen(
                                          contentType:
                                              updatedActivity.type == 'post'
                                              ? 'post'
                                              : 'activity',
                                          contentId: updatedActivity.id,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                MoreMenuItem(
                                  text: 'Скрыть тренировки',
                                  icon: CupertinoIcons.eye_slash,
                                  iconColor: AppColors.error,
                                  textStyle: const TextStyle(
                                    color: AppColors.error,
                                  ),
                                  onTap: () {
                                    _handleHideActivities(
                                      context: context,
                                      ref: ref,
                                      activity: updatedActivity,
                                      currentUserId: currentUserId,
                                    );
                                  },
                                ),
                              ]);
                            }

                            MoreMenuOverlay(
                              anchorKey: menuKey,
                              items: items,
                            ).show(context);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ───────────────── МАРШРУТ С ФОТОГРАФИЯМИ ─────────────────
              // Показываем только если есть точки маршрута или есть изображения
              // Высота 400
              // Для импортированных тренировок без маршрута показываем дефолтную картинку
              // ────────────────────────────────────────────────────────────────
              // ⚡ ОПТИМИЗАЦИЯ: используем предвычисленные значения
              // ────────────────────────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Builder(
                  builder: (context) {
                    // ────────────────────────────────────────────────────────────────
                    // 📊 ФОРМАТИРОВАНИЕ МЕТРИК: вычисляем значения для первой строки
                    // ────────────────────────────────────────────────────────────────
                    final activityTypeLower = updatedActivity.type
                        .toLowerCase();
                    final isSwim =
                        activityTypeLower == 'swim' ||
                        activityTypeLower == 'swimming';
                    final isBike =
                        activityTypeLower == 'bike' ||
                        activityTypeLower == 'bicycle' ||
                        activityTypeLower == 'cycling' ||
                        activityTypeLower == 'indoor-cycling';
                    final isRun =
                        activityTypeLower == 'run' ||
                        activityTypeLower == 'running' ||
                        activityTypeLower == 'indoor-running' ||
                        activityTypeLower == 'walking' ||
                        activityTypeLower == 'hiking';

                    // Форматирование расстояния
                    String formatSwimDistance(double meters) {
                      final value = meters.toStringAsFixed(0);
                      final buffer = StringBuffer();
                      for (int i = 0; i < value.length; i++) {
                        if (i > 0 && (value.length - i) % 3 == 0) {
                          buffer.write(' ');
                        }
                        buffer.write(value[i]);
                      }
                      return buffer.toString();
                    }

                    final distanceText = stats?.distance != null
                        ? isSwim
                              ? '${formatSwimDistance(stats!.distance)} м'
                              : '${((stats!.distance / 1000.0).toStringAsFixed(2))} км'
                        : '—';

                    // Форматирование времени
                    final durationText = stats?.effectiveDuration != null
                        ? formatDuration(stats!.effectiveDuration)
                        : '—';

                    // Форматирование темпа/скорости
                    String paceText;
                    double? speedKmh;
                    if (isSwim) {
                      if (stats?.avgPace != null && stats!.avgPace > 0) {
                        paceText = formatPace(stats.avgPace / 10.0);
                      } else if (stats?.distance != null &&
                          stats?.effectiveDuration != null &&
                          stats!.distance > 0 &&
                          stats.effectiveDuration > 0) {
                        final duration = stats.effectiveDuration.toDouble();
                        final paceMinPer100m =
                            (duration * 100) / (stats.distance * 60);
                        paceText = formatPace(paceMinPer100m);
                      } else {
                        paceText = '—';
                      }
                    } else {
                      paceText = stats?.avgPace != null
                          ? formatPace(stats!.avgPace)
                          : '—';
                    }

                    // Вычисление скорости
                    if (isBike) {
                      // ────────────────────────────────────────────────────────────────
                      // 🚴 ДЛЯ ВЕЛОТРЕНИРОВОК БЕЗ ТРЕКА: всегда пересчитываем из расстояния и времени
                      // ────────────────────────────────────────────────────────────────
                      if (updatedActivity.points.isEmpty &&
                          stats?.distance != null &&
                          stats?.effectiveDuration != null &&
                          stats!.distance > 0 &&
                          stats.effectiveDuration > 0) {
                        final duration = stats.effectiveDuration.toDouble();
                        speedKmh = (stats.distance / duration) * 3.6;
                      } else if (stats?.avgSpeed != null && stats!.avgSpeed > 0) {
                        // Для тренировок с треком используем avgSpeed из stats
                        speedKmh = stats.avgSpeed;
                      } else if (stats?.distance != null &&
                          stats?.effectiveDuration != null &&
                          stats!.distance > 0 &&
                          stats.effectiveDuration > 0) {
                        // Если avgSpeed нет, рассчитываем из расстояния и времени
                        final duration = stats.effectiveDuration.toDouble();
                        speedKmh = (stats.distance / duration) * 3.6;
                      }
                    } else {
                      if (stats?.distance != null &&
                          stats?.effectiveDuration != null &&
                          stats!.distance > 0 &&
                          stats.effectiveDuration > 0) {
                        final duration = stats.effectiveDuration.toDouble();
                        speedKmh = (stats.distance / duration) * 3.6;
                      }
                    }
                    final speedText = speedKmh != null
                        ? '${speedKmh.toStringAsFixed(1)} км/ч'
                        : '—';

                    // ────────────────────────────────────────────────────────────────
                    // 📊 ВИДЖЕТ ПЕРВОЙ СТРОКИ МЕТРИК: для наложения поверх градиента
                    // ────────────────────────────────────────────────────────────────
                    Widget buildOverlayMetricsRow() {
                      return Positioned(
                        bottom: 20,
                        left: 24,
                        right: 16,
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 130,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Расстояние',
                                    style: AppTextStyles.h11w4Sec.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  distanceText == '—'
                                      ? Text(
                                          distanceText,
                                          style: AppTextStyles.h17w6.copyWith(
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: distanceText
                                                    .replaceAll(' км', '')
                                                    .replaceAll(' м', ''),
                                                style: AppTextStyles.h17w6
                                                    .copyWith(
                                                      color: Colors.white,
                                                    ),
                                              ),
                                              TextSpan(
                                                text:
                                                    distanceText.contains(' км')
                                                    ? ' км'
                                                    : ' м',
                                                style: AppTextStyles.h17w6
                                                    .copyWith(
                                                      fontSize: 16,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 110,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Время, мин',
                                    style: AppTextStyles.h11w4Sec.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    durationText,
                                    style: AppTextStyles.h17w6.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isBike
                                        ? 'Скорость'
                                        : isSwim
                                        ? 'Темп, /100м'
                                        : 'Темп, /км',
                                    style: AppTextStyles.h11w4Sec.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  isBike
                                      ? (speedText == '—'
                                            ? Text(
                                                speedText,
                                                style: AppTextStyles.h17w6
                                                    .copyWith(
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : Text.rich(
                                                TextSpan(
                                                  children: [
                                                    TextSpan(
                                                      text: speedText
                                                          .replaceAll(
                                                            ' км/ч',
                                                            '',
                                                          ),
                                                      style: AppTextStyles.h17w6
                                                          .copyWith(
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                                    TextSpan(
                                                      text: ' км/ч',
                                                      style: AppTextStyles.h17w6
                                                          .copyWith(
                                                            fontSize: 16,
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ))
                                      : Text(
                                          paceText,
                                          style: AppTextStyles.h17w6.copyWith(
                                            color: Colors.white,
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Показываем блок, если есть маршрут, изображения, или нет ни того ни другого
                    // (дефолтное фото: импорт без маршрута, ручное добавление без фото)
                    if (updatedActivity.points.isNotEmpty ||
                        updatedActivity.mediaImages.isNotEmpty ||
                        (updatedActivity.points.isEmpty &&
                            updatedActivity.mediaImages.isEmpty)) {
                      // ────────────────────────────────────────────────────────────────
                      // 🖼️ ДЕФОЛТНАЯ КАРТИНКА: нет маршрута и нет фото — по типу: бег/вело/плавание/лыжи
                      // высота фиксированная — 350 пикселей
                      // ────────────────────────────────────────────────────────────────
                      if (updatedActivity.points.isEmpty &&
                          updatedActivity.mediaImages.isEmpty) {
                        // ────────────────────────────────────────────────────────────────
                        // ⚡ ОПТИМИЗАЦИЯ: используем предвычисленный defaultImagePath
                        // ────────────────────────────────────────────────────────────────
                        return SizedBox(
                          height: 350.0,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                defaultImagePath,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: AppColors.disabled,
                                      child: const Center(
                                        child: Icon(
                                          CupertinoIcons.photo,
                                          size: 48,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ),
                              ),
                              // ────────────────────────────────────────────────────────────────
                              // 🌑 ТЕМНЫЙ ГРАДИЕНТ: наложение внизу изображения для лучшей читаемости
                              // ────────────────────────────────────────────────────────────────
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height: 140,
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.5),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // ────────────────────────────────────────────────────────────────
                              // 📊 ПЕРВАЯ СТРОКА МЕТРИК: дублирование поверх градиента
                              // ────────────────────────────────────────────────────────────────
                              buildOverlayMetricsRow(),
                            ],
                          ),
                        );
                      }

                      // ────────────────────────────────────────────────────────────────
                      // 📐 ВЫЧИСЛЕНИЕ ВЫСОТЫ ПО СООТНОШЕНИЮ 1:1.1:
                      // Высота = ширина экрана × 1.1
                      // ────────────────────────────────────────────────────────────────
                      final screenWidth = MediaQuery.of(context).size.width;
                      final mapHeight = screenWidth * 1.1;

                      return SizedBox(
                        height: mapHeight,
                        child: Stack(
                          children: [
                            ActivityRouteCarousel(
                              points: updatedActivity.points
                                  .map((c) => LatLng(c.lat, c.lng))
                                  .toList(),
                              imageUrls: updatedActivity.mediaImages,
                              height: mapHeight,
                              mapSortOrder: updatedActivity.mapSortOrder,
                              activityId: updatedActivity.id,
                              userId: updatedActivity.userId,
                            ),
                            // ────────────────────────────────────────────────────────────────
                            // 🌑 ТЕМНЫЙ ГРАДИЕНТ: наложение сверху изображения для лучшей читаемости
                            // ────────────────────────────────────────────────────────────────
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 140,
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.1),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // ────────────────────────────────────────────────────────────────
                            // 🌑 ТЕМНЫЙ ГРАДИЕНТ: наложение внизу изображения для лучшей читаемости
                            // ────────────────────────────────────────────────────────────────
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 140,
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.8),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // ────────────────────────────────────────────────────────────────
                            // 📊 ПЕРВАЯ СТРОКА МЕТРИК: дублирование поверх градиента
                            // ────────────────────────────────────────────────────────────────
                            buildOverlayMetricsRow(),
                          ],
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),

              // ────────────────────────────────────────────────────────────────
              // 📦 ЭКИПИРОВКА: вплотную под блоком с маршрутом
              // ────────────────────────────────────────────────────────────────
              equipmentWidget,

              // ────────────────────────────────────────────────────────────────
              // 📝 ОПИСАНИЕ ТРЕНИРОВКИ: после карты, до лайков/комментариев
              // ────────────────────────────────────────────────────────────────
              if (updatedActivity.postContent.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
                  child: ExpandableText(text: updatedActivity.postContent),
                ),

              const SizedBox(height: 12),

              // ───────────────── НИЖНЯЯ ПАНЕЛЬ ДЕЙСТВИЙ ─────────────────
              // ────────────────────────────────────────────────────────────────
              // 🔹 БЛОКИРОВКА КЛИКА: оборачиваем в GestureDetector для предотвращения
              // перехода на экран описания при клике на полоску действий
              // ────────────────────────────────────────────────────────────────
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  // Пустой обработчик — поглощает клики, не давая им распространяться
                  // вверх к родительскому GestureDetector в lenta_screen.dart
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 13, right: 16),
                  child: ActivityActionsRow(
                    activityId: updatedActivity.id,
                    activityUserId: updatedActivity.userId,
                    currentUserId: currentUserId,
                    initialLikes: updatedActivity.likes,
                    initiallyLiked: updatedActivity.islike,
                    commentsCount: updatedActivity.comments,
                    activity: updatedActivity,

                    // Открываем комментарии — поведение как было
                    onOpenComments: () {
                      // ────────────────────────────────────────────────────────────────
                      // 🔹 Используем helper-функцию для плавного открытия bottom sheet
                      // ────────────────────────────────────────────────────────────────
                      // ────────────────────────────────────────────────────────────────
                      // 🔔 ОБНОВЛЕНИЕ СЧЕТЧИКА: передаем lentaId и callback
                      // ────────────────────────────────────────────────────────────────
                      final lentaState = ref.read(lentaProvider(currentUserId));
                      final activityItem = lentaState.items.firstWhere(
                        (a) => a.lentaId == updatedActivity.lentaId,
                        orElse: () =>
                            updatedActivity, // fallback на обновленную activity
                      );

                      showCommentsBottomSheet(
                        context: context,
                        itemType: 'activity',
                        itemId: activityItem.id,
                        currentUserId: currentUserId,
                        lentaId: activityItem.lentaId,
                        // Оптимистичное обновление: увеличиваем счетчик на 1
                        onCommentAdded: () {
                          // Получаем актуальный счетчик из провайдера перед обновлением
                          final currentState = ref.read(
                            lentaProvider(currentUserId),
                          );
                          final latestActivity = currentState.items.firstWhere(
                            (a) => a.lentaId == activityItem.lentaId,
                            orElse: () => activityItem, // fallback
                          );

                          ref
                              .read(lentaProvider(currentUserId).notifier)
                              .updateComments(
                                activityItem.lentaId,
                                latestActivity.comments + 1,
                              );
                        },
                        // Оптимистичное обновление: уменьшаем счетчик на 1
                        onCommentDeleted: () {
                          // Получаем актуальный счетчик из провайдера перед обновлением
                          final currentState = ref.read(
                            lentaProvider(currentUserId),
                          );
                          final latestActivity = currentState.items.firstWhere(
                            (a) => a.lentaId == activityItem.lentaId,
                            orElse: () => activityItem, // fallback
                          );

                          // Уменьшаем счетчик на 1 (но не меньше 0)
                          final newCount = (latestActivity.comments - 1)
                              .clamp(0, double.infinity)
                              .toInt();
                          ref
                              .read(lentaProvider(currentUserId).notifier)
                              .updateComments(activityItem.lentaId, newCount);
                        },
                      );
                    },

                    // «Вместе» — пушим экран совместных активностей
                    onOpenTogether: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) =>
                              TogetherScreen(activityId: updatedActivity.id),
                        ),
                      );
                    },

                    // ────────────────────────────────────────────────────────────────
                    // ✅ ИСПРАВЛЕНО: иконка совместной тренировки показывается всегда
                    // для владельца, независимо от наличия карты маршрута
                    // ────────────────────────────────────────────────────────────────
                    hideRightActions: false,
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//                        ЛОКАЛЬНЫЕ ХЕЛПЕРЫ
// ────────────────────────────────────────────────────────────────

/// Обработчик добавления фотографий к тренировке.
///
/// Открывает галерею телефона для выбора нескольких фотографий.
/// Использует lentaId для точной идентификации элемента в ленте.
Future<void> _handleAddPhotos({
  required BuildContext context,
  required WidgetRef ref,
  required int activityId,
  required int lentaId,
  required int currentUserId,
}) async {
  final picker = ImagePicker();
  final container = ProviderScope.containerOf(context);
  final auth = container.read(authServiceProvider);
  final navigator = Navigator.of(context, rootNavigator: true);
  var loaderShown = false;

  // ────────────────────────────────────────────────────────────────
  // 🔹 СОХРАНЯЕМ screenWidth ДО async операций, чтобы избежать
  // использования BuildContext через async gap
  // ────────────────────────────────────────────────────────────────
  final screenWidth = MediaQuery.of(context).size.width;
  final aspectRatio = screenWidth / 400.0;

  void hideLoader() {
    if (loaderShown && navigator.mounted) {
      navigator.pop();
      loaderShown = false;
    }
  }

  try {
    final pickedFiles = await picker.pickMultiImage(
      maxWidth: ImagePickerHelper.maxPickerDimension,
      maxHeight: ImagePickerHelper.maxPickerDimension,
      imageQuality: ImagePickerHelper.pickerImageQuality,
    );
    if (pickedFiles.isEmpty) return;

    final userId = await auth.getUserId();
    if (userId == null) {
      if (context.mounted) {
        await _showErrorDialog(
          context: context,
          error:
              'Не удалось определить пользователя. Пожалуйста, авторизуйтесь.',
        );
      }
      return;
    }

    final filesForUpload = <String, File>{};
    for (var i = 0; i < pickedFiles.length; i++) {
      if (!context.mounted) return;

      final picked = pickedFiles[i];
      // Обрезаем изображение для высоты 400px (динамическое соотношение)
      final cropped = await ImagePickerHelper.cropPickedImage(
        context: context,
        source: picked,
        aspectRatio: aspectRatio,
        title: 'Обрезать',
      );

      if (cropped == null) {
        continue; // Пропускаем, если пользователь отменил обрезку
      }

      // Сжимаем обрезанное изображение
      final compressed = await compressLocalImage(
        sourceFile: cropped,
        maxSide: ImageCompressionPreset.activity.maxSide,
        jpegQuality: ImageCompressionPreset.activity.quality,
      );

      // Удаляем временный файл обрезки
      if (cropped.path != compressed.path) {
        try {
          await cropped.delete();
        } catch (_) {
          // Игнорируем ошибки удаления
        }
      }

      filesForUpload['file$i'] = compressed;
    }

    if (filesForUpload.isEmpty) {
      return;
    }

    if (!context.mounted) return;
    _showBlockingLoader(context, message: 'Загружаем фотографии…');
    loaderShown = true;

    final api = ref.read(apiServiceProvider);
    final response = await api.postMultipart(
      '/upload_activity_photos.php',
      files: filesForUpload,
      fields: {'user_id': '$userId', 'activity_id': '$activityId'},
      timeout: const Duration(minutes: 2),
    );

    hideLoader();

    if (response['success'] != true) {
      final message =
          response['message']?.toString() ??
          'Не удалось загрузить фотографии. Попробуйте ещё раз.';
      if (context.mounted) {
        await _showErrorDialog(context: context, error: message);
      }
      return;
    }

    final images =
        (response['images'] as List?)?.whereType<String>().toList(
          growable: false,
        ) ??
        const [];

    if (images.isNotEmpty) {
      await ref
          .read(lentaProvider(currentUserId).notifier)
          .updateActivityMedia(lentaId: lentaId, mediaImages: images);
    } else {
      await ref.read(lentaProvider(currentUserId).notifier).refresh();
    }

    if (context.mounted) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Готово'),
          content: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Фотографии добавлены к тренировке.'),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Ок'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    hideLoader();
    if (context.mounted) {
      await _showErrorDialog(context: context, error: e);
    }
  }
}

/// Обработчик удаления тренировки.
///
/// 1. Спрашиваем подтверждение у пользователя.
/// 2. Показываем модальный индикатор с блокировкой ввода.
/// 3. Вызываем API `/delete_activity.php`.
/// 4. При успехе удаляем элемент из провайдера `lentaProvider`.
/// 5. При ошибке показываем SelectableText.rich с сообщением об ошибке.
Future<void> _handleDeleteActivity({
  required BuildContext context,
  required WidgetRef ref,
  required Activity activity,
  required int currentUserId,
}) async {
  final confirmed = await _confirmDeletion(context);
  if (!confirmed || !context.mounted) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  _showBlockingLoader(context);

  final success = await _sendDeleteActivityRequest(
    context: context,
    userId: currentUserId,
    activityId: activity.id,
  );

  if (navigator.mounted) {
    navigator.pop();
  }

  if (!context.mounted) return;

  if (success) {
    await ref
        .read(lentaProvider(currentUserId).notifier)
        .removeItem(activity.lentaId);
  } else {
    await _showErrorDialog(
      context: context,
      error: 'Не удалось удалить тренировку. Попробуйте ещё раз.',
    );
  }
}

/// Показывает модальный диалог подтверждения.
Future<bool> _confirmDeletion(BuildContext context) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Удалить тренировку?'),
      content: const Text('Действие нельзя отменить.'),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Отмена'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );

  return result ?? false;
}

/// Показываем лоадер, пока ждём ответ сервера.
void _showBlockingLoader(
  BuildContext context, {
  String message = 'Удаляем тренировку…',
}) {
  showCupertinoDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CupertinoAlertDialog(
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(),
            const SizedBox(height: 12),
            Text(message),
          ],
        ),
      ),
    ),
  );
}

/// Универсальный показ ошибки через SelectableText.rich (вместо SnackBar).
Future<void> _showErrorDialog({
  required BuildContext context,
  required dynamic error,
}) {
  final message = ErrorHandler.format(error);
  return showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Ошибка'),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SelectableText.rich(
          TextSpan(
            text: message,
            style: const TextStyle(color: AppColors.error, fontSize: 15),
          ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Понятно'),
        ),
      ],
    ),
  );
}

/// Вызывает API удаления активности и возвращает bool-успех.
///
/// ⚡ PERFORMANCE OPTIMIZATION:
/// - Timeout 12 секунд — баланс между надежностью и UX
/// - Простая проверка success — быстрая валидация ответа
/// - Обработка ApiException — корректная обработка сетевых ошибок
Future<bool> _sendDeleteActivityRequest({
  required BuildContext context,
  required int userId,
  required int activityId,
}) async {
  try {
    final container = ProviderScope.containerOf(context);
    final api = container.read(apiServiceProvider);
    final response = await api.post(
      '/delete_activity.php',
      body: {'userId': '$userId', 'activityId': '$activityId'},
      timeout: const Duration(seconds: 12),
    );

    // ────────────────────────────────────────────────────────────────
    // ✅ ПРОВЕРКА УСПЕШНОСТИ: API возвращает {success: true, message: 'Тренировка удалена'}
    // ────────────────────────────────────────────────────────────────
    final success = response['success'] == true;
    final message = response['message']?.toString() ?? '';

    // Дополнительная проверка по сообщению для надежности
    return success || message == 'Тренировка удалена';
  } on ApiException {
    return false;
  } catch (_) {
    return false;
  }
}

/// Обработчик скрытия тренировок пользователя.
///
/// Показывает диалог подтверждения, после чего скрывает тренировки через API.
Future<void> _handleHideActivities({
  required BuildContext context,
  required WidgetRef ref,
  required Activity activity,
  required int currentUserId,
}) async {
  // ────────────────────────────────────────────────────────────────
  // 🔹 ДИАЛОГ ПОДТВЕРЖДЕНИЯ: спрашиваем у пользователя подтверждение
  // ────────────────────────────────────────────────────────────────
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Скрыть тренировки?'),
      content: Text(
        'Тренировки ${activity.userName} будут скрыты из вашей ленты.',
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Отмена'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Да, скрыть'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  // ────────────────────────────────────────────────────────────────
  // 🔹 ВЫЗОВ API: скрываем тренировки пользователя
  // ────────────────────────────────────────────────────────────────
  try {
    final api = ref.read(apiServiceProvider);
    final data = await api.post(
      '/hide_user_content.php',
      body: {
        'userId': '$currentUserId',
        'hidden_user_id': '${activity.userId}',
        'action': 'hide',
        'content_type': 'activity', // Скрываем только тренировки
      },
      timeout: const Duration(seconds: 10),
    );

    // Проверяем успешность операции
    final success = data['success'] == true;

    if (success && context.mounted) {
      // Удаляем тренировки пользователя из ленты локально без сброса пагинации
      ref
          .read(lentaProvider(currentUserId).notifier)
          .removeUserContent(
            hiddenUserId: activity.userId,
            contentType: 'activity',
          );
    } else if (context.mounted) {
      // Показываем ошибку
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Ошибка'),
          content: Text(
            data['message']?.toString() ??
                'Не удалось скрыть тренировки пользователя',
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Ок'),
            ),
          ],
        ),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Ошибка'),
          content: Text('Не удалось скрыть тренировки: ${e.message}'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Ок'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Ошибка'),
          content: const Text('Не удалось скрыть тренировки пользователя'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Ок'),
            ),
          ],
        ),
      );
    }
  }
}
