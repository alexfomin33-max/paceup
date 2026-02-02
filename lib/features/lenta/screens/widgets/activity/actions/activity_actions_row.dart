// lib/screens/lenta/widgets/activity/actions/activity_actions_row.dart

import 'dart:async';
import 'package:flutter/cupertino.dart';

import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../providers/services/api_provider.dart';
import '../../../../../../core/services/api_service.dart'; // для ApiException
import '../../../../../../domain/models/activity_lenta.dart' as al;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../lenta/providers/lenta_provider.dart';
import '../../../activity/share_activity_screen.dart';

/// Панель действий: лайк/комменты/совместно.
/// Здесь локальная анимация лайка + вызов API лайка.
/// Комментарии/совместно — пробрасываются наружу колбэками.
class ActivityActionsRow extends ConsumerStatefulWidget {
  final int activityId;
  final int activityUserId; // ID владельца тренировки
  final int currentUserId;
  final int initialLikes;
  final bool initiallyLiked;
  final int commentsCount;
  final bool hideRightActions;
  final al.Activity? activity; // Полный объект Activity для шаринга

  final VoidCallback? onOpenComments;
  final VoidCallback? onOpenTogether;

  const ActivityActionsRow({
    super.key,
    required this.activityId,
    required this.activityUserId,
    required this.currentUserId,
    required this.initialLikes,
    required this.initiallyLiked,
    required this.commentsCount,
    this.hideRightActions = false,
    this.activity,
    this.onOpenComments,
    this.onOpenTogether,
  });

  @override
  ConsumerState<ActivityActionsRow> createState() => _ActivityActionsRowState();
}

class _ActivityActionsRowState extends ConsumerState<ActivityActionsRow>
    with SingleTickerProviderStateMixin {
  late bool isLiked;
  late int likesCount;
  bool _busy = false;

  late AnimationController _likeController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
    isLiked = widget.initiallyLiked;
    likesCount = widget.initialLikes;

    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _likeController, curve: Curves.easeOutBack),
    );
    _likeController.addStatusListener((s) {
      if (s == AnimationStatus.completed) _likeController.reverse();
    });
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  Future<void> _onLikeTap() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      isLiked = !isLiked;
      likesCount += isLiked ? 1 : -1;
    });
    _likeController.forward(from: 0);

    final ok = await _sendLike(
      activityId: widget.activityId,
      userId: widget.currentUserId,
      isLikedNow: isLiked,
    );

    if (!ok && mounted) {
      setState(() {
        isLiked = !isLiked;
        likesCount += isLiked ? 1 : -1;
      });
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<bool> _sendLike({
    required int activityId,
    required int userId,
    required bool isLikedNow,
  }) async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/activity_likes_toggle.php',
        body: {
          'userId': '$userId', // 🔹 PHP ожидает строки
          'activityId': '$activityId', // 🔹 PHP ожидает строки
          'type': 'activity',
          'action': isLikedNow ? 'like' : 'dislike',
        },
        timeout: const Duration(seconds: 10),
      );

      // 🔹 Сервер возвращает массив внутри 'data', достаём первый элемент
      final actualData =
          data['data'] is List && (data['data'] as List).isNotEmpty
          ? (data['data'] as List)[0] as Map<String, dynamic>
          : data;

      final ok = actualData['ok'] == true || actualData['status'] == 'ok';
      final serverLikes = int.tryParse('${actualData['likes']}');

      if (ok && serverLikes != null && mounted) {
        setState(() => likesCount = serverLikes);
        
        // ────────────────────────────────────────────────────────────────
        // ⚡ ОПТИМИЗАЦИЯ: обновляем провайдер для синхронизации с другими карточками
        // ────────────────────────────────────────────────────────────────
        // Обновляем счетчик лайков в провайдере, чтобы другие карточки
        // видели актуальные значения. Это вызовет обновление только
        // lentaItemCountsProvider, но не lentaItemProvider (если правильно настроен select)
        if (widget.activity != null) {
          ref
              .read(
                lentaProvider(widget.currentUserId).notifier,
              )
              .updateLikes(widget.activity!.lentaId, serverLikes);
        }
      }
      return ok;
    } on ApiException {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _onShareTap() async {
    if (widget.activity == null) return;

    final activity = widget.activity!;

    if (!mounted) return;

    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => ShareActivityScreen(activity: activity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.currentUserId == widget.activityUserId;
    
    // ───────────────────────────────────────────────────────────────────────
    // 🗺️ ПРОВЕРКА НАЛИЧИЯ КАРТЫ: если нет карты маршрута, скрываем только
    // иконку "совместно", шаринг всегда показывается
    // ───────────────────────────────────────────────────────────────────────
    final hasMap = widget.activity?.points.isNotEmpty ?? false;
    
    // ───────────────────────────────────────────────────────────────────────
    // 🏊 ПРОВЕРКА ТИПА ТРЕНИРОВКИ: для плавания скрываем только иконку "совместно"
    // ───────────────────────────────────────────────────────────────────────
    final activityType = widget.activity?.type.toLowerCase() ?? '';
    final isSwim = activityType == 'swim' || activityType == 'swimming';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Левая группа: лайк + комментарии
        Row(
          children: [
            GestureDetector(
              onTap: _onLikeTap,
              child: Container(
                width: 25,
                height: 25,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: ScaleTransition(
                  scale: _likeAnimation,
                  child: Icon(
                    isLiked ? CupertinoIcons.heart_solid : CupertinoIcons.heart,
                    size: 20,
                    color: isLiked ? AppColors.error : AppColors.error,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 0),
            Text(
              likesCount.toString(),
              style: AppTextStyles.h14w4.copyWith(
                color: AppColors.getTextPrimaryColor(context),
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: widget.onOpenComments,
              child: const Icon(
                CupertinoIcons.chat_bubble,
                size: 20,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              widget.commentsCount.toString(),
              style: AppTextStyles.h14w4.copyWith(
                color: AppColors.getTextPrimaryColor(context),
              ),
            ),
          ],
        ),

        // Правая группа: «совместно» + шаринг
        // 🗺️ СКРЫВАЕМ ИКОНКУ "СОВМЕСТНО": если нет карты маршрута, скрываем только
        // иконку "совместно", шаринг всегда показывается
        // 🏊 ДЛЯ ПЛАВАНИЯ: скрываем только иконку "совместно", шаринг показываем
        if (!widget.hideRightActions)
          _RightActionsGroup(
            activityId: widget.activityId,
            activityUserId: widget.activityUserId,
            currentUserId: widget.currentUserId,
            activity: widget.activity,
            isOwner: isOwner,
            onOpenTogether: widget.onOpenTogether,
            onShareTap: _onShareTap,
            hideShare: false, // ✅ Шаринг всегда показывается
            hideTogetherIcon: isSwim || !hasMap, // 🗺️ Скрываем если нет карты или плавание
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// 🔹 ВИДЖЕТ ПРАВОЙ ГРУППЫ ДЕЙСТВИЙ: иконка «совместно» и шаринг
// ─────────────────────────────────────────────────────────────────────────────
// Иконка «совместно» показывается:
// 1. Владельцу тренировки — всегда (если есть карта и не плавание).
// 2. Остальным пользователям — если togetherCount > 1 (есть другие участники),
//    чтобы любой мог зайти и посмотреть, с кем тренировались (в т.ч. тех, на кого
//    не подписан). Есть карта и не плавание.
// Шаринг только для владельца.
// ─────────────────────────────────────────────────────────────────────────────
class _RightActionsGroup extends ConsumerWidget {
  final int activityId;
  final int activityUserId;
  final int currentUserId;
  final al.Activity? activity;
  final bool isOwner;
  final VoidCallback? onOpenTogether;
  final VoidCallback onShareTap;
  final bool hideShare; // ✅ Устаревший параметр (шаринг всегда показывается)
  final bool hideTogetherIcon; // 🗺️ Скрывать иконку "совместно" если нет карты или плавание

  const _RightActionsGroup({
    required this.activityId,
    required this.activityUserId,
    required this.currentUserId,
    required this.activity,
    required this.isOwner,
    this.onOpenTogether,
    required this.onShareTap,
    this.hideShare = false,
    this.hideTogetherIcon = false, // 🗺️ По умолчанию показываем иконку
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ───────────────────────────────────────────────────────────────────────
    // ✅ ВЛАДЕЛЕЦ: видит иконку совместной тренировки (если есть карта) и шаринг
    // 🗺️ ИКОНКА "СОВМЕСТНО": скрывается если нет карты маршрута или это плавание
    // ✅ ШАРИНГ: всегда показывается для владельца, независимо от наличия карты
    // ───────────────────────────────────────────────────────────────────────
    if (isOwner) {
      return _buildActionsRow(
        context: context,
        showTogetherIcon: !hideTogetherIcon, // 🗺️ Скрываем если нет карты или плавание
        togetherCount: activity?.togetherCount ?? 1,
        sameWorkoutCount: activity?.sameWorkoutCount ?? 1,
        showShareIcon: true, // ✅ Шаринг всегда показывается для владельца
        onOpenTogether: onOpenTogether,
        onShareTap: onShareTap,
        isOwner: true, // ✅ Передаем флаг владельца
      );
    }

    // ───────────────────────────────────────────────────────────────────────
    // ✅ НЕ ВЛАДЕЛЕЦ: иконку «совместно» показываем всем, если участников > 1
    // (togetherCount) ИЛИ автоопределённая совместная тренировка (sameWorkoutCount > 1),
    // чтобы любой мог видеть индикатор и открыть список участников.
    // ───────────────────────────────────────────────────────────────────────
    final togetherCount = activity?.togetherCount ?? 1;
    final sameWorkoutCount = activity?.sameWorkoutCount ?? 1;
    if (togetherCount <= 1 && sameWorkoutCount <= 1) {
      return const SizedBox.shrink();
    }

    return _buildActionsRow(
      context: context,
      showTogetherIcon: !hideTogetherIcon,
      togetherCount: togetherCount,
      sameWorkoutCount: sameWorkoutCount,
      showShareIcon: false, // Шаринг только для владельца
      onOpenTogether: onOpenTogether,
      onShareTap: onShareTap,
      isOwner: false,
    );
  }

  Widget _buildActionsRow({
    required BuildContext context,
    required bool showTogetherIcon,
    required int togetherCount,
    required int sameWorkoutCount,
    required bool showShareIcon,
    required VoidCallback? onOpenTogether,
    required VoidCallback onShareTap,
    required bool isOwner, // ✅ Флаг владельца для отображения счетчика
  }) {
    // Количество пользователей с одинаковой тренировкой (автоопределение)
    final countToShow = sameWorkoutCount > 0 ? sameWorkoutCount : 1;
    return Row(
      children: [
        // ───────────────────────────────────────────────────────────────────
        // 🗺️ ИКОНКА И СЧЕТЧИК: количество пользователей с такой же тренировкой
        // (автоопределение по треку + время ±5 мин)
        // ───────────────────────────────────────────────────────────────────
        if (showTogetherIcon) ...[
          const Icon(
            CupertinoIcons.person_2,
            size: 20,
            color: AppColors.success,
          ),
          const SizedBox(width: 4),
          Text(
            countToShow.toString(),
            style: AppTextStyles.h14w4.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
          const SizedBox(width: 12),
        ],
        // ───────────────────────────────────────────────────────────────────
        // ✅ ИКОНКА «СОВМЕСТНО»: показываем только если пользователь имеет
        // право видеть её (владелец или участник)
        // ───────────────────────────────────────────────────────────────────
        if (showTogetherIcon)
          GestureDetector(
            onTap: onOpenTogether,
            child: const Icon(
              CupertinoIcons.person_crop_circle_badge_plus,
              size: 20,
              color: AppColors.brandPrimary,
            ),
          ),
        // ───────────────────────────────────────────────────────────────────
        // ✅ КОЛИЧЕСТВО: для владельца показываем всегда; для остальных — если
        // togetherCount > 1 или sameWorkoutCount > 1 (автоопределённая совместная).
        // ───────────────────────────────────────────────────────────────────
        if (showTogetherIcon &&
            (isOwner || togetherCount > 1 || sameWorkoutCount > 1)) ...[
          const SizedBox(width: 4),
          Text(
            countToShow.toString(),
            style: AppTextStyles.h14w4.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
        ],
        // ───────────────────────────────────────────────────────────────────
        // ✅ КНОПКА ШАРИНГА: только для владельца
        // ───────────────────────────────────────────────────────────────────
        if (showShareIcon) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onShareTap,
            child: const Icon(
              CupertinoIcons.square_arrow_up,
              size: 20,
              color: AppColors.brandPrimary,
            ),
          ),
        ],
      ],
    );
  }
}
