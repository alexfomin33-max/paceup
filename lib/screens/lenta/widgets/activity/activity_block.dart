// lib/screens/lenta/widgets/activity/activity_block.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../theme/app_theme.dart';
import '../../../../models/activity_lenta.dart';

// Подвиджеты
import 'header/activity_header.dart';
import 'stats/stats_row.dart';
import 'route/route_card.dart';
import 'equipment/equipment_chip.dart';
import 'actions/activity_actions_row.dart';

/// Главный виджет «тренировка».
/// Здесь — только «сборка» из подвиджетов + проброс колбэков.
/// Вся логика форматирования/анимаций/сетевых вызовов разложена по частям.
class ActivityBlock extends StatelessWidget {
  final Activity activity;
  final int currentUserId;

  const ActivityBlock({
    super.key,
    required this.activity,
    this.currentUserId = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(width: 0.5, color: AppColors.border),
          bottom: BorderSide(width: 0.5, color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Шапка: аватар + имя + дата (сам по себе компактный)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: ActivityHeader(
              userId: activity.userId,
              userName: activity.userName,
              userAvatar: activity.userAvatar,
              dateStart: activity.dateStart,
            ),
          ),

          /// Метрики тренировки: расстояние/время/темп/пульс и т.п.
          if (activity.stats != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: StatsRow(
                distanceMeters: activity.stats!.distance, // double/num
                durationSec: (activity.stats!.duration).toInt(), // num -> int
                elevationGainM: activity.stats!.cumulativeElevationGain, // num
                avgPaceMinPerKm: activity.stats!.avgPace, // double
                avgHeartRate: activity.stats!.avgHeartRate, // double/num?
              ),
            ),

          /// Чип с экипировкой (обувь) — отдельно от попапа
          if (activity.equipments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: EquipmentChip(items: activity.equipments),
            ),

          const SizedBox(height: 8),

          /// Маршрут (миникарта)
          RouteCard(
            points: activity.points.map((c) => LatLng(c.lat, c.lng)).toList(),
          ),

          const SizedBox(height: 12),

          /// Нижняя панель действий (лайк/комменты/совместно)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ActivityActionsRow(
              activityId: activity.id,
              currentUserId: currentUserId,
              initialLikes: activity.likes,
              initiallyLiked: activity.islike,
              commentsCount: activity.comments,
              onOpenComments: () {
                // Комментарии открывает родительский экран (через showCupertinoModalBottomSheet).
                // Если хочется — можно пробросить наружу ещё один колбэк.
                // Пока оставим заглушку: родитель ловит тапом по карточке или через GestureDetector.
              },
              onOpenTogether: () {
                // Тоже лучше пробрасывать наружу. Здесь — только UI.
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
