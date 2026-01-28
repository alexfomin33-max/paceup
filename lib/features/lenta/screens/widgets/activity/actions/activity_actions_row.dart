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
import '../../../../../lenta/providers/lenta_provider.dart';
import '../../../activity/together/together_providers.dart';

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
      // Если нет ни фото, ни карты - делимся текстом
      if (mounted) {
        try {
          await Share.share('Моя тренировка в PaceUp!');
          debugPrint('Текстовый share выполнен успешно');
        } catch (shareError) {
          debugPrint('Ошибка при текстовом share: $shareError');
          if (mounted) {
            showCupertinoDialog(
              context: context,
              builder: (context) => CupertinoAlertDialog(
                title: const Text('Ошибка'),
                content: Text('Не удалось открыть меню шаринга: $shareError'),
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
    
    // ───────────────────────────────────────────────────────────────────────
    // 🏊 ПРОВЕРКА ТИПА ТРЕНИРОВКИ: для плавания скрываем только иконку "совместно"
    // ───────────────────────────────────────────────────────────────────────
    final activityType = widget.activity?.type.toLowerCase() ?? '';
    final isSwim = activityType == 'swim' || activityType == 'swimming';
    
    // ───────────────────────────────────────────────────────────────────────
    // ✅ ИКОНКА ШАРИНГА: показывается всегда для владельца, независимо от наличия
    // карты или фото (можно репостить даже без карты и фото)
    // ───────────────────────────────────────────────────────────────────────

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
        // ✅ ИСПРАВЛЕНО: иконка совместной тренировки показывается всегда для владельца
        // ✅ ИКОНКА ШАРИНГА: показывается всегда для владельца, даже без карты и фото
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
            hideTogetherIcon: isSwim, // 🏊 Скрываем иконку "совместно" для плавания
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// 🔹 ВИДЖЕТ ПРАВОЙ ГРУППЫ ДЕЙСТВИЙ: проверяет участие в совместной тренировке
// ─────────────────────────────────────────────────────────────────────────────
// Иконка «совместно» показывается только если:
// 1. Пользователь является владельцем тренировки
// 2. Пользователь является участником совместной тренировки (принял приглашение)
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
  final bool hideTogetherIcon; // 🏊 Скрывать иконку "совместно" для плавания

  const _RightActionsGroup({
    required this.activityId,
    required this.activityUserId,
    required this.currentUserId,
    required this.activity,
    required this.isOwner,
    this.onOpenTogether,
    required this.onShareTap,
    this.hideShare = false,
    this.hideTogetherIcon = false, // 🏊 По умолчанию показываем иконку
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ───────────────────────────────────────────────────────────────────────
    // ✅ ВЛАДЕЛЕЦ: всегда видит иконку совместной тренировки
    // ✅ ИКОНКА ШАРИНГА: показывается всегда, даже без карты и фото
    // 🏊 ДЛЯ ПЛАВАНИЯ: скрываем иконку "совместно", но показываем шаринг
    // ───────────────────────────────────────────────────────────────────────
    if (isOwner) {
      return _buildActionsRow(
        context: context,
        showTogetherIcon: !hideTogetherIcon, // 🏊 Скрываем для плавания
        togetherCount: activity?.togetherCount ?? 1,
        showShareIcon: true, // ✅ Шаринг всегда показывается для владельца
        onOpenTogether: onOpenTogether,
        onShareTap: onShareTap,
        isOwner: true, // ✅ Передаем флаг владельца
      );
    }

    // ───────────────────────────────────────────────────────────────────────
    // ✅ ПРОВЕРКА УЧАСТИЯ: если нет других участников, иконку не показываем
    // ───────────────────────────────────────────────────────────────────────
    final togetherCount = activity?.togetherCount ?? 1;
    if (togetherCount <= 1) {
      // Если только владелец - не показываем иконку для других пользователей
      return const SizedBox.shrink();
    }

    // ───────────────────────────────────────────────────────────────────────
    // ✅ АСИНХРОННАЯ ПРОВЕРКА: проверяем, является ли текущий пользователь
    // участником совместной тренировки
    // ───────────────────────────────────────────────────────────────────────
    // ⚡ ОПТИМИЗАЦИЯ: используем кэширование провайдера для избежания
    // дублирующих запросов. Riverpod автоматически кэширует результаты для
    // одного и того же activityId.
    // ⚠️ ПОТЕНЦИАЛЬНОЕ УЛУЧШЕНИЕ: было бы эффективнее, если бы бэкенд
    // возвращал флаг current_user_is_member вместе с данными о тренировке
    // в activities_lenta.php, чтобы не делать дополнительные запросы.
    // ───────────────────────────────────────────────────────────────────────
    final membersState = ref.watch(
      togetherMembersProvider(activityId),
    );

    return membersState.when(
      loading: () => const SizedBox.shrink(), // При загрузке не показываем
      error: (_, __) => const SizedBox.shrink(), // При ошибке не показываем
      data: (members) {
        // ───────────────────────────────────────────────────────────────────
        // ✅ ПРОВЕРКА УЧАСТИЯ: ищем текущего пользователя в списке участников
        // ───────────────────────────────────────────────────────────────────
        final isMember = members.any(
          (member) => member.id == currentUserId,
        );

        if (!isMember) {
          // Не является участником - не показываем иконку
          return const SizedBox.shrink();
        }

        // ───────────────────────────────────────────────────────────────────
        // ✅ ЯВЛЯЕТСЯ УЧАСТНИКОМ: показываем иконку
        // Шаринг только для владельца
        // 🏊 ДЛЯ ПЛАВАНИЯ: скрываем иконку "совместно"
        // ───────────────────────────────────────────────────────────────────
        return _buildActionsRow(
          context: context,
          showTogetherIcon: !hideTogetherIcon, // 🏊 Скрываем для плавания
          togetherCount: togetherCount,
          showShareIcon: false, // Шаринг только для владельца
          onOpenTogether: onOpenTogether,
          onShareTap: onShareTap,
          isOwner: false, // ✅ Не владелец
        );
      },
    );
  }

  Widget _buildActionsRow({
    required BuildContext context,
    required bool showTogetherIcon,
    required int togetherCount,
    required bool showShareIcon,
    required VoidCallback? onOpenTogether,
    required VoidCallback onShareTap,
    required bool isOwner, // ✅ Флаг владельца для отображения счетчика
  }) {
    return Row(
      children: [
        // ───────────────────────────────────────────────────────────────────
        // 🏊 ИКОНКА И СЧЕТЧИК УЧАСТНИКОВ: показываем только если не скрыта
        // иконка "совместно" (для плавания скрываем)
        // ───────────────────────────────────────────────────────────────────
        if (showTogetherIcon) ...[
          const Icon(
            CupertinoIcons.person_2,
            size: 20,
            color: AppColors.success,
          ),
          const SizedBox(width: 4),
          Text(
            togetherCount.toString(), // ✅ Исправлен хардкод '48'
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
        // ✅ КОЛИЧЕСТВО УЧАСТНИКОВ: для владельца показываем всегда (даже если 1),
        // для остальных - только если больше 1
        // ───────────────────────────────────────────────────────────────────
        if (showTogetherIcon && (isOwner || togetherCount > 1)) ...[
          const SizedBox(width: 4),
          Text(
            togetherCount.toString(),
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
