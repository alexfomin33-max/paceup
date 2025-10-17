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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(mainTitle, style: AppTextStyles.h11w4Ter),
        const SizedBox(height: 1),
        Text(mainValue, style: AppTextStyles.h14w5),
        const SizedBox(height: 10),
        Text(subTitle, style: AppTextStyles.h11w4Ter),
        const SizedBox(height: 1),
        Text(subValue, style: AppTextStyles.h14w5),
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

  const StatsRow({
    super.key,
    required this.distanceMeters,
    required this.durationSec,
    required this.elevationGainM,
    required this.avgPaceMinPerKm,
    required this.avgHeartRate,
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetricVertical(
          mainTitle: 'Расстояние',
          mainValue: distanceText,
          subTitle: 'Набор высоты',
          subValue: elevationText,
        ),
        const SizedBox(width: 30),
        MetricVertical(
          mainTitle: 'Время',
          mainValue: durationText,
          subTitle: 'Каденс',
          subValue: '—',
        ),
        const SizedBox(width: 30),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Темп', style: AppTextStyles.h11w4Ter),
            const SizedBox(height: 1),
            Text(paceText, style: AppTextStyles.h14w5),
            const SizedBox(height: 10),
            const Text('Ср. пульс', style: AppTextStyles.h11w4Ter),
            const SizedBox(height: 1),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(hrText, style: AppTextStyles.h14w5),
                const SizedBox(width: 2),
                const Icon(
                  CupertinoIcons.heart_fill,
                  color: AppColors.error,
                  size: 12,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
