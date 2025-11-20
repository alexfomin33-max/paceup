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
import '../../../../service/api_service.dart';

// Меню с тремя точками
import '../../../../widgets/more_menu_overlay.dart';

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

    // ────────────────────────────────────────────────────────────────
    // 🔹 КЛЮЧ ДЛЯ МЕНЮ: нужен для привязки всплывающего меню
    // ────────────────────────────────────────────────────────────────
    final menuKey = GlobalKey();

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

              // ────────────────────────────────────────────────────────────────
              // 🔹 МЕНЮ С ТРЕМЯ ТОЧКАМИ: показываем только автору активности
              // ────────────────────────────────────────────────────────────────
              trailing: updatedActivity.userId == currentUserId
                  ? IconButton(
                      key: menuKey,
                      icon: const Icon(
                        CupertinoIcons.ellipsis,
                        color: AppColors.iconPrimary,
                      ),
                      onPressed: () {
                        final items = <MoreMenuItem>[
                          MoreMenuItem(
                            text: 'Редактировать',
                            icon: CupertinoIcons.pencil,
                            onTap: () {
                              // TODO: Реализовать редактирование активности
                            },
                          ),
                          MoreMenuItem(
                            text: 'Удалить тренировку',
                            icon: CupertinoIcons.minus_circle,
                            iconColor: AppColors.error,
                            textStyle: const TextStyle(color: AppColors.error),
                            onTap: () {
                              _handleDeleteActivity(
                                context: context,
                                ref: ref,
                                activity: updatedActivity,
                                currentUserId: currentUserId,
                              );
                            },
                          ),
                        ];
                        MoreMenuOverlay(
                          anchorKey: menuKey,
                          items: items,
                        ).show(context);
                      },
                    )
                  : null,
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
              showMenuButton: updatedActivity.userId == currentUserId,
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

// ────────────────────────────────────────────────────────────────
//                        ЛОКАЛЬНЫЕ ХЕЛПЕРЫ
// ────────────────────────────────────────────────────────────────

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
  if (!confirmed) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  _showBlockingLoader(context);

  final success = await _sendDeleteActivityRequest(
    userId: currentUserId,
    activityId: activity.id,
  );

  if (navigator.mounted) {
    navigator.pop();
  }

  if (success) {
    await ref
        .read(lentaProvider(currentUserId).notifier)
        .removeItem(activity.lentaId);
  } else {
    await _showErrorDialog(
      context: context,
      message: 'Не удалось удалить тренировку. Попробуйте ещё раз.',
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
void _showBlockingLoader(BuildContext context) {
  showCupertinoDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const CupertinoAlertDialog(
      content: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(),
            SizedBox(height: 12),
            Text('Удаляем тренировку…'),
          ],
        ),
      ),
    ),
  );
}

/// Универсальный показ ошибки через SelectableText.rich (вместо SnackBar).
Future<void> _showErrorDialog({
  required BuildContext context,
  required String message,
}) {
  return showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Ошибка'),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SelectableText.rich(
          TextSpan(
            text: message,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 15,
            ),
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
  required int userId,
  required int activityId,
}) async {
  try {
    final api = ApiService();
    final response = await api.post(
      '/delete_activity.php',
      body: {
        'userId': '$userId',
        'activityId': '$activityId',
      },
      timeout: const Duration(seconds: 12),
    );

    // ────────────────────────────────────────────────────────────────
    // ✅ ПРОВЕРКА УСПЕШНОСТИ: API возвращает {success: true, message: 'Тренировка удалена'}
    // ────────────────────────────────────────────────────────────────
    final success = response['success'] == true;
    final message = response['message']?.toString() ?? '';

    // Дополнительная проверка по сообщению для надежности
    return success || message == 'Тренировка удалена';
  } on ApiException catch (e) {
    // Логируем ошибку API для отладки
    debugPrint('⚠️ Ошибка удаления активности: ${e.message}');
    return false;
  } catch (e) {
    // Логируем неожиданные ошибки
    debugPrint('⚠️ Неожиданная ошибка при удалении активности: $e');
    return false;
  }
}

