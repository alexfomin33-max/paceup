// lib/screens/lenta/widgets/stats/stats_widgets.dart
import 'package:flutter/cupertino.dart';

import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/utils/activity_format.dart';

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
/// СБОРЩИК: строка статов тренировки (пример под бег)
/// принимает уже «сырые» числа и форматирует их внутри
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
  });

  @override
  Widget build(BuildContext context) {
    // ──────────────────────────────────────────────────────────────
    // 📏 ФОРМАТИРОВАНИЕ РАССТОЯНИЯ: для плавания (SWIM) показываем в метрах,
    // для остальных типов — в километрах
    // ──────────────────────────────────────────────────────────────
    final isSwim = activityType?.toLowerCase() == 'swim' ||
        activityType?.toLowerCase() == 'swimming';
    final isBike = activityType?.toLowerCase() == 'bike' ||
        activityType?.toLowerCase() == 'bicycle' ||
        activityType?.toLowerCase() == 'cycling';
    final distanceText = distanceMeters != null
        ? isSwim
            ? '${distanceMeters!.toStringAsFixed(0)} м'
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
    final paceText = avgPaceMinPerKm != null
        ? isSwim
            ? formatPace(avgPaceMinPerKm! / 10.0) // мин/км → мин/100м (делим на 10)
            : formatPace(avgPaceMinPerKm!)
        : '—';
    final hrText = avgHeartRate != null
        ? avgHeartRate!.toStringAsFixed(0)
        : '—';
    final cadenceText = avgCadence != null
        ? avgCadence!.toStringAsFixed(0)
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

    final hasCaloriesOrSteps = calories != null || totalSteps != null;

    return Padding(
      // ──────────────────────────────────────────────────────────────
      // ОТСТУП СЛЕВА: выравниваем левый край с левым краем имени
      // (аватар 50px + отступ 12px = 62px)
      // ──────────────────────────────────────────────────────────────
      padding: const EdgeInsets.only(left: 62),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ──────────────────────────────────────────────────────────────
          // ПЕРВАЯ СТРОКА: Расстояние | Время | Темп
          // ──────────────────────────────────────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: MetricVertical(
                  mainTitle: 'Расстояние',
                  mainValue: distanceText,
                  subTitle: '',
                  subValue: '',
                ),
              ),
              SizedBox(
                width: 90,
                child: MetricVertical(
                  mainTitle: 'Время',
                  mainValue: durationText,
                  subTitle: '',
                  subValue: '',
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // ──────────────────────────────────────────────────────────────
                      // ⏱️ ЗАГОЛОВОК ТЕМПА/СКОРОСТИ:
                      // - для плавания показываем "Темп, мин/100м"
                      // - для велотренировок показываем "Скорость, км/ч"
                      // - для остальных показываем "Темп, мин/км"
                      // ──────────────────────────────────────────────────────────────
                      isSwim
                          ? 'Темп, мин/100м'
                          : isBike
                              ? 'Скорость, км/ч'
                              : 'Темп, мин/км',
                      style: AppTextStyles.h11w4Sec.copyWith(
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      // ──────────────────────────────────────────────────────────────
                      // 🚴 ДЛЯ ВЕЛОТРЕНИРОВОК: показываем скорость вместо темпа
                      // ──────────────────────────────────────────────────────────────
                      isBike ? speedText : paceText,
                      style: AppTextStyles.h14w6.copyWith(
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
          // ──────────────────────────────────────────────────────────────
          if (!isManuallyAdded) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: MetricVertical(
                    mainTitle: 'Набор высоты',
                    mainValue: elevationText,
                    subTitle: '',
                    subValue: '',
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: MetricVertical(
                    mainTitle: 'Каденс',
                    mainValue: cadenceText,
                    subTitle: '',
                    subValue: '',
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
                            style: AppTextStyles.h14w6.copyWith(
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
          // ТРЕТЬЯ СТРОКА: Калории | Шаги | Скорость (если доступны)
          // ──────────────────────────────────────────────────────────────
          if (showExtendedStats && hasCaloriesOrSteps && !isManuallyAdded) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: MetricVertical(
                    mainTitle: 'Калории, ккал',
                    mainValue: caloriesText,
                    subTitle: '',
                    subValue: '',
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: MetricVertical(
                    mainTitle: 'Шаги',
                    mainValue: stepsText,
                    subTitle: '',
                    subValue: '',
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
                      Text(
                        speedText,
                        style: AppTextStyles.h14w6.copyWith(
                          color: AppColors.getTextPrimaryColor(context),
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
    );
  }
}
