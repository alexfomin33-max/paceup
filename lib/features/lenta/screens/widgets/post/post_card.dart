import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../domain/models/activity_lenta.dart';
import 'post_media_carousel.dart';
import '../../../widgets/user_header.dart';
import '../../../../../core/widgets/expandable_text.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../../../core/services/api_service.dart'; // для ApiException
import '../../../../../core/utils/feed_date.dart';

// ✅ универсальное всплывающее меню (уже вынесено в lib/widgets)
import '../../../../../core/widgets/more_menu_overlay.dart';
import '../../../../../core/widgets/transparent_route.dart';
import '../../../../profile/screens/profile_screen.dart';

/// ─────────────────────────────────────────────────────────────────────────────
///   КАРТОЧКА ПОСТА
///   Требование: при клике "Удалить пост" — отправить JSON на эндпоинт
///   { userId, postId } и при успешном ответе скрыть карточку без рефреша.
///   Визуальные стили/верстку/анимации — не меняем.
/// ─────────────────────────────────────────────────────────────────────────────
class PostCard extends ConsumerStatefulWidget {
  /// Модель поста (id, автор, даты, медиа, текст, лайки, комменты)
  final Activity post;

  /// Текущий пользователь (для лайка/комментирования/удаления)
  final int currentUserId;

  // Колбэки поведения — оставить для совместимости (не меняем сигнатуры).
  final VoidCallback? onEdit; // Нажали "Редактировать пост"
  final VoidCallback?
  onDelete; // Успешно удалили пост (опционально внеш. реакция)
  final VoidCallback? onOpenComments; // Нажали на "комментарии"

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    this.onEdit,
    this.onDelete,
    this.onOpenComments,
  });

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  /// Локально скрываем карточку после успешного ответа сервера.
  bool _visible = true;

  /// Защита от дабл-тапов на "Удалить".
  bool _deleting = false;

  /// Отправка JSON-запроса на удаление поста.
  Future<bool> _sendDeleteRequest({
    required int userId,
    required int postId,
  }) async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/post_delete.php',
        body: {
          'userId': '$userId',
          'postId': '$postId',
        }, // 🔹 PHP ожидает строки
        timeout: const Duration(seconds: 10),
      );

      // 🔹 Сервер может возвращать массив внутри 'data', достаём первый элемент
      final actualData =
          data['data'] is List && (data['data'] as List).isNotEmpty
          ? (data['data'] as List)[0] as Map<String, dynamic>
          : data;

      final ok =
          actualData['ok'] == true ||
          actualData['status'] == 'ok' ||
          actualData['success'] == true ||
          actualData['result'] == 'ok';

      return ok;
    } on ApiException {
      return false;
    } catch (e) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Показываем системный диалог подтверждения до удаления
  // ─────────────────────────────────────────────────────────────────────────────
  Future<bool> _confirmDelete() async {
    // Используем CupertinoAlertDialog, чтобы не менять стили в карточке.
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Удалить пост?'),
        content: const Text('Это действие нельзя отменить.'),
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

    // Нажатия закрывают диалог, но мы не привязываем колбэки к кнопкам,
    // поэтому трактуем choice по порядку в onPressed ниже.
    // Чтобы различать кнопки, используем Navigator.pop(context, bool).
    // Для этого меняем реализацию — см. ниже обновление builder.
    return result ?? false;
  }

  /// Хендлер пункта меню "Удалить пост": отправляем JSON и по успеху скрываем.
  Future<void> _handleDelete() async {
    if (_deleting) return;
    setState(() => _deleting = true);

    final ok = await _sendDeleteRequest(
      userId: widget.currentUserId,
      postId: widget.post.id,
    );

    if (!mounted) return;

    if (ok) {
      // 1) Скрываем карточку локально (без обновления всей ленты)
      setState(() => _visible = false);

      // 2) Сообщим наружу (если кто-то подписан на onDelete)
      widget.onDelete?.call(); // ✅ Раскомментировал!
    }

    // Возвращаем флаг — кнопка снова доступна (если карточка не скрыта)
    if (mounted) setState(() => _deleting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    // Ключ нам нужен, чтобы вычислить положение кнопки "…"
    // и привязать к ней универсальное всплывающее меню.
    final menuKey = GlobalKey();
    final post = widget.post;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        border: Border(
          top: BorderSide(width: 0.5, color: AppColors.getBorderColor(context)),
          bottom: BorderSide(
            width: 0.5,
            color: AppColors.getBorderColor(context),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ──────────────────────────────────────────────────────────────
          // ШАПКА: единый UserHeader (аватар, имя, дата, trailing-меню)
          // ──────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: UserHeader(
              userName: post.userName,
              userAvatar: post.userAvatar,
              dateText: formatFeedDateText(
                serverText: post.postDateText,
                date: post.dateStart,
              ),

              // ──────────────────────────────────────────────────────────────
              // ✅ ПЕРЕХОД В ПРОФИЛЬ: клик на аватар или имя открывает профиль автора
              // ──────────────────────────────────────────────────────────────
              onAvatarTap: () {
                Navigator.of(context).push(
                  TransparentPageRoute(
                    builder: (_) => ProfileScreen(userId: post.userId),
                  ),
                );
              },
              onNameTap: () {
                Navigator.of(context).push(
                  TransparentPageRoute(
                    builder: (_) => ProfileScreen(userId: post.userId),
                  ),
                );
              },

              // trailing — наша кнопка "…"
              // ──────────────────────────────────────────────────────────────
              // ✅ ПРОВЕРКА ВЛАДЕЛЬЦА: показываем меню только автору поста
              // ──────────────────────────────────────────────────────────────
              trailing: post.userId == widget.currentUserId
                  ? IconButton(
                      key: menuKey,
                      icon: Icon(
                        CupertinoIcons.ellipsis,
                        color: AppColors.getIconPrimaryColor(context),
                      ),
                      onPressed: () {
                        final items = <MoreMenuItem>[
                          MoreMenuItem(
                            text: 'Редактировать пост',
                            icon: CupertinoIcons.pencil,
                            onTap: widget.onEdit ?? () {},
                          ),
                          MoreMenuItem(
                            text: _deleting ? 'Удаление…' : 'Удалить пост',
                            icon: CupertinoIcons.minus_circle,
                            iconColor: AppColors.error,
                            textStyle: const TextStyle(color: AppColors.error),
                            // Ничего визуально не меняем — просто игнорим повторный тап
                            onTap: _deleting
                                ? () {}
                                : () async {
                                    // Дадим оверлею закрыться, чтобы диалог не накладывался визуально.
                                    await Future<void>.delayed(
                                      const Duration(milliseconds: 10),
                                    );

                                    // 1) Спрашиваем подтверждение ДО удаления
                                    final confirmed = await _confirmDelete();
                                    if (!confirmed) return;

                                    // 2) Только теперь запускаем удаление
                                    await _handleDelete();
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

          // ──────────────────────────────────────────────────────────────
          // МЕДИА-КАРУСЕЛЬ: картинки/видео, соотношение сторон 1.3:1
          // ──────────────────────────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              // Вычисляем высоту для соотношения сторон 1.3:1
              final width = constraints.maxWidth;
              final height = width / 1.3;
              return SizedBox(
                height: height,
                width: double.infinity,
                child: PostMediaCarousel(
                  imageUrls: post.mediaImages,
                  videoUrls: post.mediaVideos,
                ),
              );
            },
          ),

          // ──────────────────────────────────────────────────────────────
          // ТЕКСТ ПОСТА: после медиа, до лайков/комментариев (с раскрытием)
          // ──────────────────────────────────────────────────────────────
          if (post.postContent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: ExpandableText(text: post.postContent),
            ),

          // ──────────────────────────────────────────────────────────────
          // НИЖНЯЯ ПАНЕЛЬ: лайк и комментарии
          // ──────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Лайк-бар: локальная анимация + API
                _PostLikeBar(post: post, currentUserId: widget.currentUserId),
                const SizedBox(width: 16),

                // Кнопка «комментарии» — экран ленты откроет bottom sheet
                GestureDetector(
                  onTap: widget.onOpenComments,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.chat_bubble,
                        size: 20,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.comments.toString(),
                        style: AppTextStyles.h14w4.copyWith(
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Лайк-бар для поста: анимация сердца + вызов API.
/// Приватен для PostCard, чтобы экран ленты был проще.
class _PostLikeBar extends ConsumerStatefulWidget {
  final Activity post;
  final int currentUserId;

  const _PostLikeBar({required this.post, required this.currentUserId});

  @override
  ConsumerState<_PostLikeBar> createState() => _PostLikeBarState();
}

class _PostLikeBarState extends ConsumerState<_PostLikeBar>
    with SingleTickerProviderStateMixin {
  bool isLiked = false; // локальное состояние лайка
  int likesCount = 0; // локальный счётчик лайков
  bool _busy = false; // защита от дабл-тапов

  late AnimationController _likeController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
    // Инициализация из модели поста
    isLiked = widget.post.islike;
    likesCount = widget.post.likes;

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

  // Обработчик тапа по сердцу: оптимистичное обновление + синхронизация с сервером
  Future<void> _onTap() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      isLiked = !isLiked;
      likesCount += isLiked ? 1 : -1;
    });
    _likeController.forward(from: 0);

    final ok = await _sendLike(
      activityId: widget.post.id, // на бэке это id поста (тип = post)
      userId: widget.currentUserId,
      isLikedNow: isLiked,
      type: 'post',
    );

    // Откат при ошибке
    if (!ok && mounted) {
      setState(() {
        isLiked = !isLiked;
        likesCount += isLiked ? 1 : -1;
      });
    }
    if (mounted) setState(() => _busy = false);
  }

  // Сетевая часть: шлём действие like/dislike
  Future<bool> _sendLike({
    required int activityId,
    required int userId,
    required bool isLikedNow,
    required String type, // 'post'
  }) async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/activity_likes_toggle.php',
        body: {
          'userId': '$userId', // 🔹 PHP ожидает строки
          'activityId': '$activityId', // 🔹 PHP ожидает строки
          'type': type,
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

      // Если сервер отдал точное число лайков — синхронизируем
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Row(
        children: [
          ScaleTransition(
            scale: _likeAnimation,
            child: Icon(
              isLiked ? CupertinoIcons.heart_solid : CupertinoIcons.heart,
              size: 20,
              color: AppColors.error,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            likesCount.toString(),
            style: AppTextStyles.h14w4.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
