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
  final double? avgHeartRate;
  final double? avgCadence; // шагов в минуту (spm)
  final double? calories; // калории (ккал)
  final int? totalSteps; // общее количество шагов
  final bool isManuallyAdded;
  final bool
  showExtendedStats; // показывать ли третью строку (Калории | Шаги | Скорость)

  const StatsRow({
    super.key,
    required this.distanceMeters,
    required this.durationSec,
    required this.elevationGainM,
    required this.avgPaceMinPerKm,
    required this.avgHeartRate,
    this.avgCadence,
    this.calories,
    this.totalSteps,
    this.isManuallyAdded = false,
    this.showExtendedStats = false,
  });

  @override
  Widget build(BuildContext context) {
    final distanceKm = (distanceMeters ?? 0) / 1000.0;
    final distanceText = distanceMeters != null
        ? distanceKm.toStringAsFixed(2)
        : '—';
    final elevationText = elevationGainM != null
        ? elevationGainM!.toStringAsFixed(0)
        : '—';
    final durationText = durationSec != null
        ? formatDuration(durationSec)
        : '—';
    final paceText = avgPaceMinPerKm != null
        ? formatPace(avgPaceMinPerKm!)
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
    // Вычисляем скорость из расстояния и времени (км/ч)
    // ──────────────────────────────────────────────────────────────
    double? speedKmh;
    if (distanceMeters != null &&
        durationSec != null &&
        distanceMeters! > 0 &&
        (durationSec as num).toDouble() > 0) {
      final duration = (durationSec as num).toDouble();
      speedKmh = (distanceMeters! / duration) * 3.6;
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
                  mainTitle: 'Расстояние, км',
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
                      'Темп, мин/км',
                      style: AppTextStyles.h11w4Sec.copyWith(
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      paceText,
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
                    mainTitle: 'Набор высоты, м',
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
