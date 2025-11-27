// lib/screens/lenta/widgets/activity/actions/activity_actions_row.dart

import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/services/api_service.dart';

/// Панель действий: лайк/комменты/совместно.
/// Здесь локальная анимация лайка + вызов API лайка.
/// Комментарии/совместно — пробрасываются наружу колбэками.
class ActivityActionsRow extends StatefulWidget {
  final int activityId;
  final int currentUserId;
  final int initialLikes;
  final bool initiallyLiked;
  final int commentsCount;
  final bool hideRightActions;

  final VoidCallback? onOpenComments;
  final VoidCallback? onOpenTogether;

  const ActivityActionsRow({
    super.key,
    required this.activityId,
    required this.currentUserId,
    required this.initialLikes,
    required this.initiallyLiked,
    required this.commentsCount,
    this.hideRightActions = false,
    this.onOpenComments,
    this.onOpenTogether,
  });

  @override
  State<ActivityActionsRow> createState() => _ActivityActionsRowState();
}

class _ActivityActionsRowState extends State<ActivityActionsRow>
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
      final api = ApiService();
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
      }
      return ok;
    } on ApiException {
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(width: 12),
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

        // Правая группа: «совместно» (скрываем для тренировок, добавленных вручную)
        if (!widget.hideRightActions)
          Row(
            children: [
              const Icon(
                CupertinoIcons.person_2,
                size: 20,
                color: AppColors.success,
              ),
              const SizedBox(width: 4),
              Text(
                '48',
                style: AppTextStyles.h14w4.copyWith(
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: widget.onOpenTogether,
                child: const Icon(
                  CupertinoIcons.person_crop_circle_badge_plus,
                  size: 20,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '3',
                style: AppTextStyles.h14w4.copyWith(
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
