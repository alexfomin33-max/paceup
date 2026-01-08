// lib/screens/lenta/widgets/activity/actions/activity_actions_row.dart

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../providers/services/api_provider.dart';
import '../../../../../../core/services/api_service.dart'; // для ApiException
import '../../../../../../core/services/share_image_generator.dart';
import '../../../../../../domain/models/activity_lenta.dart' as al;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'share_image_selector_dialog.dart';

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
  ConsumerState<ActivityActionsRow> createState() =>
      _ActivityActionsRowState();
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
    final hasPhotos = activity.mediaImages.isNotEmpty;
    final hasMap = activity.points.isNotEmpty;
    
    // Если есть и фото, и карта - показываем диалог выбора
    if (hasPhotos && hasMap) {
      final selection = await ShareImageSelectorDialog.show(
        context: context,
        photoUrls: activity.mediaImages,
        hasMap: hasMap,
      );
      
      if (selection == null || !mounted) return;
      
      await _generateAndShare(
        activity: activity,
        useMap: selection.type == ShareImageType.map,
        selectedPhotoUrl: selection.photoUrl,
      );
    } else if (hasPhotos) {
      // Если есть только фото - используем первое фото
      await _generateAndShare(
        activity: activity,
        useMap: false,
        selectedPhotoUrl: activity.mediaImages.first,
      );
    } else if (hasMap) {
      // Если есть только карта - используем карту
      await _generateAndShare(
        activity: activity,
        useMap: true,
        selectedPhotoUrl: null,
      );
    } else {
      // Если нет ни фото, ни карты - показываем сообщение
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Нет данных для репоста'),
            content: const Text('Добавьте фото или маршрут к тренировке'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ОК'),
              ),
            ],
          ),
        );
      }
    }
  }
  
  Future<void> _generateAndShare({
    required al.Activity activity,
    required bool useMap,
    String? selectedPhotoUrl,
  }) async {
    BuildContext? dialogContext;
    
    try {
      // Показываем индикатор загрузки
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) {
          dialogContext = dialogCtx;
          return const CupertinoAlertDialog(
            content: Padding(
              padding: EdgeInsets.all(20),
              child: CupertinoActivityIndicator(),
            ),
          );
        },
      );
      
      // Генерируем финальное изображение для шаринга
      final imagePath = await ShareImageGenerator.generateShareImage(
        activity: activity,
        context: context,
        routeImageBytes: null,
        selectedPhotoUrl: selectedPhotoUrl,
        useMap: useMap,
      );
      
      // Закрываем индикатор загрузки
      if (mounted && dialogContext != null) {
        Navigator.of(dialogContext!).pop();
        dialogContext = null;
      }
      
      if (!mounted) return;
      
      if (imagePath != null) {
        // Открываем системный share sheet
        await Share.shareXFiles(
          [XFile(imagePath)],
          text: 'Моя тренировка в PaceUp!',
        );
      } else {
        // Если не удалось сгенерировать изображение, делимся текстом
        await Share.share('Моя тренировка в PaceUp!');
      }
    } catch (e) {
      // Гарантируем закрытие диалога при любой ошибке
      if (mounted) {
        if (dialogContext != null) {
          Navigator.of(dialogContext!).pop();
        } else {
          // Пытаемся закрыть через основной контекст
          try {
            Navigator.of(context).pop();
          } catch (_) {
            // Игнорируем ошибку если диалог уже закрыт
          }
        }
      }
      debugPrint('Ошибка шаринга: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.currentUserId == widget.activityUserId;
    
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

        // Правая группа: «совместно» + шаринг (скрываем для тренировок, добавленных вручную)
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
              // Кнопка шаринга в сторис (только для владельца)
              if (isOwner) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _onShareTap,
                  child: const Icon(
                    CupertinoIcons.square_arrow_up,
                    size: 20,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}
