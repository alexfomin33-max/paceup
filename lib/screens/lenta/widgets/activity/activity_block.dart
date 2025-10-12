// lib/screens/lenta/widgets/activity/activity_block.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

// Токены/модели
import '../../../../theme/app_theme.dart';
import '../../../../models/activity_lenta.dart';

// Подвиджеты
import 'header/activity_header.dart';
import 'stats/stats_row.dart';
import 'route/route_card.dart';
import 'equipment/equipment_chip.dart';
import 'actions/activity_actions_row.dart';

// Для комментариев и «вместе» — поведение как в исходном коде
import '../comments_bottom_sheet.dart';
import '../../activity/together/together_screen.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

/// Главный виджет «тренировка».
/// Задача: сохранить визуал 1-в-1 с дорефакторинговым activity_block.dart.
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
    // Достаём статистику. Даже если её нет — рисуем блок (он покажет «—»),
    // чтобы сохранить стабильную вертикальную ритмику и высоту карточки.
    final stats = activity.stats;

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
          // ──────────────────────────────────────────────────────────────
          // ШАПКА + МЕТРИКИ (одна секция с отступом 16)
          // ──────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: ActivityHeader(
              userId: activity.userId,
              userName: activity.userName,
              userAvatar: activity.userAvatar,
              dateStart: activity.dateStart,

              // ⬇️ если в модели Activity есть готовая строка, как в Посте — используем её
              dateTextOverride: activity
                  .postDateText, // <-- ПОДСТАВЬ СВОЁ НАЗВАНИЕ ПОЛЯ, если оно другое
              // Нижний слот — метрики
              bottom: StatsRow(
                distanceMeters: stats?.distance,
                durationSec: stats?.duration,
                elevationGainM: stats?.cumulativeElevationGain,
                avgPaceMinPerKm: stats?.avgPace,
                avgHeartRate: stats?.avgHeartRate,
              ),
              bottomGap: 18.0,
            ),
          ),

          // Тонкий промежуток после шапки+метрик (было const SizedBox(height: 2))
          const SizedBox(height: 2),

          // ───────────────── ЭКИПИРОВКА ─────────────────
          // Как в исходнике: снаружи паддинг 6, внутри сам чип имеет собственный горизонтальный паддинг 10 (мы добавили его в EquipmentChip).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: EquipmentChip(items: activity.equipments),
          ),

          const SizedBox(height: 8),

          // ───────────────── МАРШРУТ ─────────────────
          RouteCard(
            points: activity.points.map((c) => LatLng(c.lat, c.lng)).toList(),
          ),

          const SizedBox(height: 12),

          // ───────────────── НИЖНЯЯ ПАНЕЛЬ ДЕЙСТВИЙ ─────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ActivityActionsRow(
              activityId: activity.id,
              currentUserId: currentUserId,
              initialLikes: activity.likes,
              initiallyLiked: activity.islike,
              commentsCount: activity.comments,

              // Открываем комментарии — поведение как было
              onOpenComments: () {
                showCupertinoModalBottomSheet(
                  context: context,
                  builder: (context) => CommentsBottomSheet(
                    itemType: 'activity',
                    itemId: activity.id,
                    currentUserId: currentUserId,
                  ),
                );
              },

              // «Вместе» — пушим экран совместных активностей
              onOpenTogether: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const TogetherScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
