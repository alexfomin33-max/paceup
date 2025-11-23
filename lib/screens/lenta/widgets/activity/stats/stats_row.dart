// lib/screens/lenta/widgets/stats/stats_widgets.dart
import 'package:flutter/cupertino.dart';

import '../../../../../theme/app_theme.dart';
import '../../../../../utils/activity_format.dart';

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
        Text(
          mainTitle,
          style: AppTextStyles.h11w4Ter.copyWith(
            color: AppColors.getTextTertiaryColor(context),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          mainValue,
          style: AppTextStyles.h14w5.copyWith(
            color: AppColors.getTextPrimaryColor(context),
          ),
        ),
        if (showSub) ...[
          const SizedBox(height: 10),
          Text(
            subTitle,
            style: AppTextStyles.h11w4Ter.copyWith(
              color: AppColors.getTextTertiaryColor(context),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subValue,
            style: AppTextStyles.h14w5.copyWith(
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
  final bool isManuallyAdded;

  const StatsRow({
    super.key,
    required this.distanceMeters,
    required this.durationSec,
    required this.elevationGainM,
    required this.avgPaceMinPerKm,
    required this.avgHeartRate,
    this.isManuallyAdded = false,
  });

  @override
  Widget build(BuildContext context) {
    final distanceKm = (distanceMeters ?? 0) / 1000.0;
    final distanceText = distanceMeters != null
        ? '${distanceKm.toStringAsFixed(2)} км'
        : '—';
    final elevationText = elevationGainM != null
        ? '${elevationGainM!.toStringAsFixed(0)} м'
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

    return Padding(
      // ──────────────────────────────────────────────────────────────
      // ОТСТУП СЛЕВА: выравниваем левый край с левым краем имени
      // (аватар 50px + отступ 12px = 62px)
      // ──────────────────────────────────────────────────────────────
      padding: const EdgeInsets.only(left: 62),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ──────────────────────────────────────────────────────────────
          // ПЕРВАЯ КОЛОНКА: Расстояние / Набор высоты (фиксированная ширина)
          // ──────────────────────────────────────────────────────────────
          SizedBox(
            width: 120,
            child: MetricVertical(
              mainTitle: 'Расстояние',
              mainValue: distanceText,
              subTitle: isManuallyAdded ? '' : 'Набор высоты',
              subValue: isManuallyAdded ? '' : elevationText,
            ),
          ),
          // ──────────────────────────────────────────────────────────────
          // ВТОРАЯ КОЛОНКА: Время / Каденс (фиксированная ширина)
          // ──────────────────────────────────────────────────────────────
          SizedBox(
            width: 90,
            child: MetricVertical(
              mainTitle: 'Время',
              mainValue: durationText,
              subTitle: isManuallyAdded ? '' : 'Каденс',
              subValue: isManuallyAdded ? '' : '—',
            ),
          ),
          // ──────────────────────────────────────────────────────────────
          // ТРЕТЬЯ КОЛОНКА: Темп / Ср. пульс (занимает оставшееся пространство)
          // ──────────────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Темп',
                  style: AppTextStyles.h11w4Ter.copyWith(
                    color: AppColors.getTextTertiaryColor(context),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  paceText,
                  style: AppTextStyles.h14w5.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
                if (!isManuallyAdded) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Ср. пульс',
                    style: AppTextStyles.h11w4Ter.copyWith(
                      color: AppColors.getTextTertiaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.heart_fill,
                        color: AppColors.error,
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        hrText,
                        style: AppTextStyles.h14w5.copyWith(
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
