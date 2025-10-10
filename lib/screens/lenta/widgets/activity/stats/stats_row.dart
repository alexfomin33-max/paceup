// lib/screens/lenta/widgets/stats/stats_widgets.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
        Text(
          mainTitle,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 1),
        Text(
          mainValue,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          subTitle,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 1),
        Text(
          subValue,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
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
  final double? avgHeartRate; // можно null → выведем «—»

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
            const Text(
              'Темп',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 1),
            Text(
              paceText,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ср. пульс',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 1),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hrText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  CupertinoIcons.heart_fill,
                  color: Colors.red,
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
