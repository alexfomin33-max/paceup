// lib/screens/lenta/widgets/activity/activity_block.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:latlong2/latlong.dart';

// Токены/модели
import '../../../../theme/app_theme.dart';
import '../../../../models/activity_lenta.dart';

// Подвиджеты
import 'header/activity_header.dart';
import 'stats/stats_row.dart';
import '../../../../../widgets/route_card.dart';
import 'equipment/equipment_chip.dart';
import 'actions/activity_actions_row.dart';

// Для комментариев и «вместе» — поведение как в исходном коде
import '../comments_bottom_sheet.dart';
import '../../activity/together/together_screen.dart';

// Провайдеры
import '../../../../providers/lenta/lenta_provider.dart';

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
    // 🔔 ОБНОВЛЕНИЕ СЧЕТЧИКА: получаем актуальный Activity из провайдера
    // ────────────────────────────────────────────────────────────────
    // Watch провайдер для получения актуального счетчика комментариев
    final lentaState = ref.watch(lentaProvider(currentUserId));
    final updatedActivity = lentaState.items.firstWhere(
      (a) => a.lentaId == activity.lentaId,
      orElse: () => activity, // fallback на переданную activity
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
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
              userId: updatedActivity.userId,
              userName: updatedActivity.userName,
              userAvatar: updatedActivity.userAvatar,
              dateStart: updatedActivity.dateStart,

              // ⬇️ если в модели Activity есть готовая строка, как в Посте — используем её
              dateTextOverride: updatedActivity.postDateText,
              // Нижний слот — метрики
              bottom: StatsRow(
                distanceMeters: stats?.distance,
                durationSec: stats?.duration,
                elevationGainM: stats?.cumulativeElevationGain,
                avgPaceMinPerKm: stats?.avgPace,
                avgHeartRate: stats?.avgHeartRate,
              ),
              bottomGap: 12.0,
            ),
          ),

          // ───────────────── ЭКИПИРОВКА ─────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: EquipmentChip(
              items: updatedActivity.equipments,
              userId: updatedActivity.userId,
              activityType: updatedActivity.type,
              activityId: updatedActivity.id,
              activityDistance: (stats?.distance ?? 0.0) / 1000.0, // конвертируем метры в километры
              onEquipmentChanged: () {
                // Обновляем ленту после замены эквипа
                ref.read(lentaProvider(currentUserId).notifier).forceRefresh();
              },
            ),
          ),

          // ────────────────────────────────────────────────────────────────
          // 📏 ДИНАМИЧЕСКОЕ РАССТОЯНИЕ: уменьшаем, если нет экипировки
          // ────────────────────────────────────────────────────────────────
          SizedBox(height: updatedActivity.equipments.isNotEmpty ? 8 : 0),

          // ───────────────── МАРШРУТ ─────────────────
          RouteCard(
            points: updatedActivity.points
                .map((c) => LatLng(c.lat, c.lng))
                .toList(),
            height: 240, // Увеличена высота карты для лучшей видимости маршрута
          ),

          const SizedBox(height: 12),

          // ───────────────── НИЖНЯЯ ПАНЕЛЬ ДЕЙСТВИЙ ─────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ActivityActionsRow(
              activityId: updatedActivity.id,
              currentUserId: currentUserId,
              initialLikes: updatedActivity.likes,
              initiallyLiked: updatedActivity.islike,
              commentsCount: updatedActivity.comments,

              // Открываем комментарии — поведение как было
              onOpenComments: () {
                // ────────────────────────────────────────────────────────────────
                // 🔹 Используем showModalBottomSheet с useRootNavigator для перекрытия нижнего меню
                // ────────────────────────────────────────────────────────────────
                showModalBottomSheet(
                  context: context,
                  useRootNavigator: true,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) {
                    // ────────────────────────────────────────────────────────────────
                    // 🔔 ОБНОВЛЕНИЕ СЧЕТЧИКА: передаем lentaId и callback
                    // ────────────────────────────────────────────────────────────────
                    final lentaState = ref.read(lentaProvider(currentUserId));
                    final activityItem = lentaState.items.firstWhere(
                      (a) => a.lentaId == updatedActivity.lentaId,
                      orElse: () =>
                          updatedActivity, // fallback на обновленную activity
                    );

                    return CommentsBottomSheet(
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
                    );
                  },
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
