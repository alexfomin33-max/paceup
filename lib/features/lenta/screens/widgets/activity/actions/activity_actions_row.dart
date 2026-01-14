// lib/screens/lenta/widgets/activity/actions/activity_actions_row.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';

import 'package:share_plus/share_plus.dart';

import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../providers/services/api_provider.dart';
import '../../../../../../core/services/api_service.dart'; // для ApiException
import '../../../../../../core/services/share_image_generator.dart';
import '../../../../../../domain/models/activity_lenta.dart' as al;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'share_image_selector_dialog.dart';
import 'package:latlong2/latlong.dart';
import '../../../../../../core/utils/static_map_url_builder.dart';

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

    // Если только карта (нет фото) - сразу репостим карту
    if (hasMap && !hasPhotos) {
      // Генерируем URL карты с размерами для Stories (чтобы использовать кэш)
      final points = activity.points.map((c) => LatLng(c.lat, c.lng)).toList();
      final mapUrl = StaticMapUrlBuilder.fromPoints(
        points: points,
        widthPx: ShareImageGenerator.storyWidth.toDouble(),
        heightPx: ShareImageGenerator.storyHeight.toDouble(),
        strokeWidth: 3.0,
        padding: 12.0,
        maxWidth: 1280.0,
        maxHeight: 1280.0,
      );

      await _generateAndShare(
        activity: activity,
        useMap: true,
        selectedPhotoUrl: null,
        mapImageUrl: mapUrl,
      );
      return;
    }

    // Если есть фото (с картой или без) - показываем слайдер выбора
    if (hasPhotos) {
      // Проверяем mounted перед показом диалога
      if (!mounted) return;
      
      final selection = await ShareImageSelectorDialog.show(
        context: context,
        photoUrls: activity.mediaImages,
        hasMap: hasMap,
        activity: activity,
      );

      // Проверяем mounted после закрытия диалога
      if (selection == null || !mounted) return;

      // Небольшая задержка для стабилизации состояния после закрытия диалога
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Еще раз проверяем mounted перед генерацией
      if (!mounted) return;

      await _generateAndShare(
        activity: activity,
        useMap: selection.type == ShareImageType.map,
        selectedPhotoUrl: selection.photoUrl,
        mapImageUrl: selection.mapImageUrl,
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
    String? mapImageUrl,
  }) async {
    // Проверяем, что виджет все еще смонтирован перед началом операции
    if (!mounted) return;

    BuildContext? dialogContext;

    try {
      // Показываем индикатор загрузки только если контекст валиден
      if (!mounted) return;
      
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
      // Используем контекст только если виджет все еще смонтирован
      if (!mounted) {
        if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
          Navigator.of(dialogContext!).pop();
        }
        return;
      }

      final imagePath = await ShareImageGenerator.generateShareImage(
        activity: activity,
        context: context,
        routeImageBytes: null,
        selectedPhotoUrl: selectedPhotoUrl,
        useMap: useMap,
        mapImageUrl: mapImageUrl,
      );

      debugPrint('Изображение сгенерировано: $imagePath');

      // Закрываем индикатор загрузки безопасно
      if (mounted && dialogContext != null) {
        try {
          if (Navigator.of(dialogContext!).canPop()) {
            Navigator.of(dialogContext!).pop();
          }
        } catch (_) {
          // Игнорируем ошибку если диалог уже закрыт или история пуста
        }
        dialogContext = null;
      }

      // Небольшая задержка после закрытия диалога загрузки для стабилизации состояния
      await Future.delayed(const Duration(milliseconds: 200));

      // Проверяем mounted перед открытием share sheet
      if (!mounted) {
        debugPrint('Виджет размонтирован перед открытием share sheet');
        return;
      }

      if (imagePath != null) {
        // Проверяем, что файл существует
        final file = File(imagePath);
        if (!await file.exists()) {
          debugPrint('Файл изображения не существует: $imagePath');
          if (mounted) {
            showCupertinoDialog(
              context: context,
              builder: (context) => const CupertinoAlertDialog(
                title: Text('Ошибка'),
                content: Text('Не удалось найти сгенерированное изображение'),
                actions: [
                  CupertinoDialogAction(
                    child: Text('ОК'),
                  ),
                ],
              ),
            );
          }
          return;
        }

        debugPrint('Открываем share sheet с изображением: $imagePath');
        try {
          // Получаем размер экрана для sharePositionOrigin (требуется на iOS)
          final mediaQuery = MediaQuery.of(context);
          final screenSize = mediaQuery.size;
          
          // Используем центр экрана для позиционирования share sheet
          // На iOS требуется sharePositionOrigin для правильного позиционирования popover
          final sharePositionOrigin = Rect.fromLTWH(
            screenSize.width / 2 - 1,
            screenSize.height / 2 - 1,
            2,
            2,
          );
          
          // Открываем системный share sheet
          await Share.shareXFiles(
            [XFile(imagePath)],
            text: 'Моя тренировка в PaceUp!',
            sharePositionOrigin: sharePositionOrigin,
          );
          debugPrint('Share sheet открыт успешно');
          
          // Небольшая задержка после закрытия share sheet для стабилизации состояния на iOS
          await Future.delayed(const Duration(milliseconds: 300));
          
          // Проверяем mounted после закрытия share sheet
          if (!mounted) return;
        } catch (shareError) {
          debugPrint('Ошибка при открытии share sheet: $shareError');
          // Показываем сообщение об ошибке пользователю
          if (mounted) {
            showCupertinoDialog(
              context: context,
              builder: (context) => CupertinoAlertDialog(
                title: const Text('Ошибка'),
                content: Text('Не удалось открыть меню шаринга: $shareError'),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('ОК'),
                  ),
                ],
              ),
            );
          }
        }
      } else {
        debugPrint('Изображение не сгенерировано, делимся текстом');
        // Если не удалось сгенерировать изображение, делимся текстом
        if (mounted) {
          try {
            await Share.share('Моя тренировка в PaceUp!');
            debugPrint('Текстовый share выполнен успешно');
            
            // Небольшая задержка после закрытия share sheet для стабилизации состояния на iOS
            await Future.delayed(const Duration(milliseconds: 300));
          } catch (shareError) {
            debugPrint('Ошибка при текстовом share: $shareError');
          }
        }
      }
    } catch (e) {
      // Гарантируем закрытие диалога при любой ошибке безопасно
      if (mounted) {
        if (dialogContext != null) {
          try {
            if (Navigator.of(dialogContext!).canPop()) {
              Navigator.of(dialogContext!).pop();
            }
          } catch (_) {
            // Игнорируем ошибку если диалог уже закрыт или история пуста
          }
        } else {
          // Пытаемся закрыть через основной контекст
          try {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          } catch (_) {
            // Игнорируем ошибку если диалог уже закрыт или история пуста
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
