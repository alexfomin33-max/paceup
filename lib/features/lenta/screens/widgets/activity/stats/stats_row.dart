// lib/screens/lenta/widgets/stats/stats_widgets.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/utils/activity_format.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// АТОМ: горизонтальная метрика с иконкой (для первой строки: расстояние, время, темп)
/// ─────────────────────────────────────────────────────────────────────────
class MetricHorizontal extends StatelessWidget {
  final IconData icon;
  final String value;

  const MetricHorizontal({super.key, required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.getTextSecondaryColor(context)),
        const SizedBox(width: 8),
        Text(
          value,
          style: AppTextStyles.h16w6.copyWith(
            color: AppColors.getTextPrimaryColor(context),
          ),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// АТОМ: одна вертикальная метрика (заголовок/значение + саб-заголовок/значение)
/// ─────────────────────────────────────────────────────────────────────────
class MetricVertical extends StatelessWidget {
  final String mainTitle;
  final String mainValue;
  final String subTitle;
  final String subValue;

  const MetricVertical({
    super.key,
    required this.mainTitle,
    required this.mainValue,
    required this.subTitle,
    required this.subValue,
  });

  @override
  Widget build(BuildContext context) {
    final showSub = subTitle.isNotEmpty && subValue.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ──────────────────────────────────────────────────────────────
        // ЗАГОЛОВОК СВЕРХУ: сначала отображаем заголовок
        // ──────────────────────────────────────────────────────────────
        Text(
          mainTitle,
          style: AppTextStyles.h11w4Sec.copyWith(
            color: AppColors.getTextSecondaryColor(context),
          ),
        ),
        const SizedBox(height: 1),
        // ──────────────────────────────────────────────────────────────
        // ЗНАЧЕНИЕ СНИЗУ: затем отображаем значение
        // ──────────────────────────────────────────────────────────────
        Text(
          mainValue,
          style: AppTextStyles.h14w6.copyWith(
            color: AppColors.getTextPrimaryColor(context),
          ),
        ),
        if (showSub) ...[
          const SizedBox(height: 10),
          // ──────────────────────────────────────────────────────────────
          // ПОДЗАГОЛОВОК СВЕРХУ: сначала отображаем подзаголовок
          // ──────────────────────────────────────────────────────────────
          Text(
            subTitle,
            style: AppTextStyles.h11w4Sec.copyWith(
              color: AppColors.getTextSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 1),
          // ──────────────────────────────────────────────────────────────
          // ПОДЗНАЧЕНИЕ СНИЗУ: затем отображаем подзначение
          // ──────────────────────────────────────────────────────────────
          Text(
            subValue,
            style: AppTextStyles.h14w6.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// СБОРЩИК: строка статов тренировки
/// принимает уже «сырые» числа и форматирует их внутри
/// 🏊 ДЛЯ ПЛАВАНИЯ И 🏃 ДЛЯ БЕГА: горизонтальный формат (одна строка)
/// ─────────────────────────────────────────────────────────────────────────
class StatsRow extends StatelessWidget {
  final double? distanceMeters;
  final num? durationSec;
  final double? elevationGainM;
  final double? avgPaceMinPerKm;
  final double? avgSpeed; // средняя скорость в км/ч (для велотренировок)
  final double? avgHeartRate;
  final double? avgCadence; // шагов в минуту (spm)
  final double? calories; // калории (ккал)
  final int? totalSteps; // общее количество шагов
  final bool isManuallyAdded;
  final bool
  showExtendedStats; // показывать ли третью строку (Калории | Шаги | Скорость)
  final String? activityType; // тип активности для определения единиц измерения
  final double? bottomPadding; // нижний padding (по умолчанию 16)

  const StatsRow({
    super.key,
    required this.distanceMeters,
    required this.durationSec,
    required this.elevationGainM,
    required this.avgPaceMinPerKm,
    this.avgSpeed,
    required this.avgHeartRate,
    this.avgCadence,
    this.calories,
    this.totalSteps,
    this.isManuallyAdded = false,
    this.showExtendedStats = false,
    this.activityType,
    this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    // ──────────────────────────────────────────────────────────────
    // 📏 ФОРМАТИРОВАНИЕ РАССТОЯНИЯ: для плавания (SWIM) показываем в метрах,
    // для остальных типов — в километрах
    // ──────────────────────────────────────────────────────────────
    final isSwim =
        activityType?.toLowerCase() == 'swim' ||
        activityType?.toLowerCase() == 'swimming';
    final isBike =
        activityType?.toLowerCase() == 'bike' ||
        activityType?.toLowerCase() == 'bicycle' ||
        activityType?.toLowerCase() == 'cycling';
    // ──────────────────────────────────────────────────────────────
    // 📏 ФОРМАТИРОВАНИЕ ДИСТАНЦИИ ДЛЯ ПЛАВАНИЯ: добавляем пробел после каждых 3 цифр
    // ──────────────────────────────────────────────────────────────
    String formatSwimDistance(double meters) {
      final value = meters.toStringAsFixed(0);
      // Добавляем пробелы после каждых 3 цифр справа налево
      final buffer = StringBuffer();
      for (int i = 0; i < value.length; i++) {
        if (i > 0 && (value.length - i) % 3 == 0) {
          buffer.write(' ');
        }
        buffer.write(value[i]);
      }
      return buffer.toString();
    }

    final distanceText = distanceMeters != null
        ? isSwim
              ? '${formatSwimDistance(distanceMeters!)} м'
              : '${((distanceMeters! / 1000.0).toStringAsFixed(2))} км'
        : '—';
    final elevationText = elevationGainM != null
        ? '${elevationGainM!.toStringAsFixed(0)} м'
        : '—';
    final durationText = durationSec != null
        ? formatDuration(durationSec)
        : '—';
    // ──────────────────────────────────────────────────────────────
    // ⏱️ ФОРМАТИРОВАНИЕ ТЕМПА: для плавания пересчитываем из мин/км в мин/100м
    // 🚴 ДЛЯ ВЕЛОТРЕНИРОВОК: показываем скорость вместо темпа
    // ──────────────────────────────────────────────────────────────
    String paceText;
    if (isSwim) {
      // ──────────────────────────────────────────────────────────────
      // 🏊 РАСЧЕТ ТЕМПА ДЛЯ ПЛАВАНИЯ: мин/100м
      // Если avgPaceMinPerKm есть и > 0, пересчитываем из мин/км в мин/100м
      // Иначе рассчитываем из расстояния и времени
      // ──────────────────────────────────────────────────────────────
      if (avgPaceMinPerKm != null && avgPaceMinPerKm! > 0) {
        // Пересчитываем из мин/км в мин/100м (делим на 10, т.к. 1км = 10*100м)
        paceText = formatPace(avgPaceMinPerKm! / 10.0);
      } else if (distanceMeters != null &&
          durationSec != null &&
          distanceMeters! > 0 &&
          (durationSec as num).toDouble() > 0) {
        // Рассчитываем темп из расстояния и времени: (время в сек * 100) / (расстояние в м * 60)
        final duration = (durationSec as num).toDouble();
        final paceMinPer100m = (duration * 100) / (distanceMeters! * 60);
        paceText = formatPace(paceMinPer100m);
      } else {
        paceText = '—';
      }
    } else {
      // Для остальных типов активности используем стандартный темп
      paceText = avgPaceMinPerKm != null ? formatPace(avgPaceMinPerKm!) : '—';
    }
    final hrText = avgHeartRate != null
        ? avgHeartRate!.toStringAsFixed(0)
        : '—';
    final cadenceText = avgCadence != null
        ? (avgCadence! * 2).toStringAsFixed(0)
        : '—';
    final caloriesText = calories != null ? calories!.toStringAsFixed(0) : '—';
    final stepsText = totalSteps != null ? totalSteps.toString() : '—';

    // ──────────────────────────────────────────────────────────────
    // 🚴 ВЫЧИСЛЕНИЕ СКОРОСТИ ДЛЯ ВЕЛОТРЕНИРОВОК: используем avgSpeed из stats,
    // если его нет — рассчитываем из расстояния и времени (км/ч)
    // ──────────────────────────────────────────────────────────────
    double? speedKmh;
    if (isBike) {
      // Для велотренировок используем avgSpeed из stats, если он есть
      if (avgSpeed != null && avgSpeed! > 0) {
        speedKmh = avgSpeed;
      } else if (distanceMeters != null &&
          durationSec != null &&
          distanceMeters! > 0 &&
          (durationSec as num).toDouble() > 0) {
        // Если avgSpeed нет, рассчитываем из расстояния и времени
        final duration = (durationSec as num).toDouble();
        speedKmh = (distanceMeters! / duration) * 3.6;
      }
    } else {
      // Для других типов активности (для третьей строки) рассчитываем скорость
      if (distanceMeters != null &&
          durationSec != null &&
          distanceMeters! > 0 &&
          (durationSec as num).toDouble() > 0) {
        final duration = (durationSec as num).toDouble();
        speedKmh = (distanceMeters! / duration) * 3.6;
      }
    }
    final speedText = speedKmh != null
        ? '${speedKmh.toStringAsFixed(1)} км/ч'
        : '—';

    return Column(
      children: [
        // ────────────────────────────────────────────────────────────────
        // РАЗДЕЛИТЕЛЬ: горизонтальная линия между хэдером и блоком метрик
        // ────────────────────────────────────────────────────────────────
        Container(height: 0.5, color: AppColors.getDividerColor(context)),
        Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: bottomPadding ?? 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ──────────────────────────────────────────────────────────────
              // ПЕРВАЯ СТРОКА: Расстояние | Время | Темп/Скорость
              // 🏊 ДЛЯ ПЛАВАНИЯ: вертикальный формат (как на скриншоте)
              // 🏃 ДЛЯ БЕГА: вертикальный формат (как на скриншоте)
              // 🚴 ДЛЯ ВЕЛОСИПЕДА: вертикальный формат (как на скриншоте)
              // ──────────────────────────────────────────────────────────────
              Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Расстояние',
                          style: AppTextStyles.h11w4Sec.copyWith(
                            color: AppColors.getTextSecondaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 1),
                        // ──────────────────────────────────────────────────────────────
                        // 📏 УМЕНЬШАЕМ РАЗМЕР ШРИФТА "км" и "м" на 1
                        // ──────────────────────────────────────────────────────────────
                        distanceText == '—'
                            ? Text(
                                distanceText,
                                style: AppTextStyles.h16w6.copyWith(
                                  color: AppColors.getTextPrimaryColor(context),
                                ),
                              )
                            : Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: distanceText
                                          .replaceAll(' км', '')
                                          .replaceAll(' м', ''),
                                      style: AppTextStyles.h16w6.copyWith(
                                        color: AppColors.getTextPrimaryColor(
                                          context,
                                        ),
                                      ),
                                    ),
                                    TextSpan(
                                      text: distanceText.contains(' км')
                                          ? ' км'
                                          : ' м',
                                      style: AppTextStyles.h16w6.copyWith(
                                        fontSize: 15,
                                        color: AppColors.getTextPrimaryColor(
                                          context,
                                        ),
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
                          'Время',
                          style: AppTextStyles.h11w4Sec.copyWith(
                            color: AppColors.getTextSecondaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          durationText,
                          style: AppTextStyles.h16w6.copyWith(
                            color: AppColors.getTextPrimaryColor(context),
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
                          // ──────────────────────────────────────────────────────────────
                          // ⏱️ ЗАГОЛОВОК ТЕМПА/СКОРОСТИ:
                          // - для велотренировок показываем "Скорость"
                          // - для плавания и бега показываем "Темп"
                          // ──────────────────────────────────────────────────────────────
                          isBike ? 'Скорость' : 'Темп',
                          style: AppTextStyles.h11w4Sec.copyWith(
                            color: AppColors.getTextSecondaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 1),
                        // ──────────────────────────────────────────────────────────────
                        // 🚴 ДЛЯ ВЕЛОТРЕНИРОВОК: показываем скорость вместо темпа
                        // 📏 УМЕНЬШАЕМ РАЗМЕР ШРИФТА "км/ч" на 1
                        // ──────────────────────────────────────────────────────────────
                        isBike
                            ? (speedText == '—'
                                  ? Text(
                                      speedText,
                                      style: AppTextStyles.h16w6.copyWith(
                                        color: AppColors.getTextPrimaryColor(
                                          context,
                                        ),
                                      ),
                                    )
                                  : Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: speedText.replaceAll(
                                              ' км/ч',
                                              '',
                                            ),
                                            style: AppTextStyles.h16w6.copyWith(
                                              color:
                                                  AppColors.getTextPrimaryColor(
                                                    context,
                                                  ),
                                            ),
                                          ),
                                          TextSpan(
                                            text: ' км/ч',
                                            style: AppTextStyles.h16w6.copyWith(
                                              fontSize: 15,
                                              color:
                                                  AppColors.getTextPrimaryColor(
                                                    context,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                            : Text(
                                paceText,
                                style: AppTextStyles.h16w6.copyWith(
                                  color: AppColors.getTextPrimaryColor(context),
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
              // ──────────────────────────────────────────────────────────────
              // ВТОРАЯ СТРОКА: Набор высоты | Каденс | Пульс
              // 🏊 ДЛЯ ПЛАВАНИЯ: показываем вторую строку метрик (как на скриншоте)
              // 🏃 ДЛЯ БЕГА: показываем вторую строку метрик (как на скриншоте)
              // 🚴 ДЛЯ ВЕЛОСИПЕДА: показываем вторую строку метрик (как на скриншоте)
              // ──────────────────────────────────────────────────────────────
              if (!isManuallyAdded) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Набор высоты',
                            style: AppTextStyles.h11w4Sec.copyWith(
                              color: AppColors.getTextSecondaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 1),
                          // ──────────────────────────────────────────────────────────────
                          // 📏 УМЕНЬШАЕМ РАЗМЕР ШРИФТА "м" на 1
                          // ──────────────────────────────────────────────────────────────
                          elevationText == '—'
                              ? Text(
                                  elevationText,
                                  style: AppTextStyles.h16w6.copyWith(
                                    color: AppColors.getTextPrimaryColor(
                                      context,
                                    ),
                                  ),
                                )
                              : Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: elevationText.replaceAll(
                                          ' м',
                                          '',
                                        ),
                                        style: AppTextStyles.h16w6.copyWith(
                                          color: AppColors.getTextPrimaryColor(
                                            context,
                                          ),
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' м',
                                        style: AppTextStyles.h16w6.copyWith(
                                          fontSize: 15,
                                          color: AppColors.getTextPrimaryColor(
                                            context,
                                          ),
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
                            // ──────────────────────────────────────────────────────────────
                            // 🚴 ДЛЯ ВЕЛОСИПЕДА: показываем "Калории" вместо "Каденс" во второй строке
                            // 🏊 ДЛЯ ПЛАВАНИЯ: показываем "Калории" вместо "Каденс" во второй строке
                            // ──────────────────────────────────────────────────────────────
                            (isBike || isSwim) ? 'Калории' : 'Каденс',
                            style: AppTextStyles.h11w4Sec.copyWith(
                              color: AppColors.getTextSecondaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            // ──────────────────────────────────────────────────────────────
                            // 🚴 ДЛЯ ВЕЛОСИПЕДА: показываем caloriesText вместо cadenceText
                            // 🏊 ДЛЯ ПЛАВАНИЯ: показываем caloriesText вместо cadenceText
                            // ──────────────────────────────────────────────────────────────
                            (isBike || isSwim) ? caloriesText : cadenceText,
                            style: AppTextStyles.h16w6.copyWith(
                              color: AppColors.getTextPrimaryColor(context),
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
                            'Ср. пульс',
                            style: AppTextStyles.h11w4Sec.copyWith(
                              color: AppColors.getTextSecondaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                hrText,
                                style: AppTextStyles.h16w6.copyWith(
                                  color: AppColors.getTextPrimaryColor(context),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                CupertinoIcons.heart_fill,
                                color: AppColors.error,
                                size: 11,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              // ──────────────────────────────────────────────────────────────
              // ТРЕТЬЯ СТРОКА: Калории | Шаги | Скорость
              // 🏊 ДЛЯ ПЛАВАНИЯ: показываем третью строку метрик (как на скриншоте)
              // 🏃 ДЛЯ БЕГА: показываем третью строку метрик (как на скриншоте)
              // 🚴 ДЛЯ ВЕЛОСИПЕДА: показываем третью строку метрик (как на скриншоте)
              // Скорость всегда доступна (рассчитывается из расстояния и времени)
              // ──────────────────────────────────────────────────────────────
              if (showExtendedStats && !isManuallyAdded) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            // ──────────────────────────────────────────────────────────────
                            // 🚴 ДЛЯ ВЕЛОСИПЕДА: показываем "Каденс" вместо "Калории" в третьей строке
                            // 🏊 ДЛЯ ПЛАВАНИЯ: показываем "Каденс" вместо "Калории" в третьей строке
                            // ──────────────────────────────────────────────────────────────
                            (isBike || isSwim) ? 'Каденс' : 'Калории',
                            style: AppTextStyles.h11w4Sec.copyWith(
                              color: AppColors.getTextSecondaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            // ──────────────────────────────────────────────────────────────
                            // 🚴 ДЛЯ ВЕЛОСИПЕДА: показываем cadenceText вместо caloriesText
                            // 🏊 ДЛЯ ПЛАВАНИЯ: показываем cadenceText вместо caloriesText
                            // ──────────────────────────────────────────────────────────────
                            (isBike || isSwim) ? cadenceText : caloriesText,
                            style: AppTextStyles.h16w6.copyWith(
                              color: AppColors.getTextPrimaryColor(context),
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
                            'Шаги',
                            style: AppTextStyles.h11w4Sec.copyWith(
                              color: AppColors.getTextSecondaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            stepsText,
                            style: AppTextStyles.h16w6.copyWith(
                              color: AppColors.getTextPrimaryColor(context),
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
                            'Скорость',
                            style: AppTextStyles.h11w4Sec.copyWith(
                              color: AppColors.getTextSecondaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 1),
                          // ──────────────────────────────────────────────────────────────
                          // 📏 УМЕНЬШАЕМ РАЗМЕР ШРИФТА "км/ч" на 1
                          // ──────────────────────────────────────────────────────────────
                          speedText == '—'
                              ? Text(
                                  speedText,
                                  style: AppTextStyles.h16w6.copyWith(
                                    color: AppColors.getTextPrimaryColor(
                                      context,
                                    ),
                                  ),
                                )
                              : Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: speedText.replaceAll(' км/ч', ''),
                                        style: AppTextStyles.h16w6.copyWith(
                                          color: AppColors.getTextPrimaryColor(
                                            context,
                                          ),
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' км/ч',
                                        style: AppTextStyles.h16w6.copyWith(
                                          fontSize: 15,
                                          color: AppColors.getTextPrimaryColor(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
