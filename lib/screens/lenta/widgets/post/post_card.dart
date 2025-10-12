import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../theme/app_theme.dart';
import '../../../../models/activity_lenta.dart';
import 'post_media_carousel.dart';
import '../../../../widgets/user_header.dart';

// ✅ универсальное всплывающее меню (уже вынесено в lib/widgets)
import '../../../../widgets/more_menu_overlay.dart';

/// Карточка поста (публичный виджет).
/// Вся навигация — через колбэки, чтобы виджет оставался переиспользуемым.
class PostCard extends StatelessWidget {
  /// Модель поста (id, автор, даты, медиа, текст, лайки, комменты)
  final Activity post;

  /// Текущий пользователь (для лайка/комментирования)
  final int currentUserId;

  // Колбэки поведения — экран решает, что делать:
  final VoidCallback? onEdit; // Нажали "Редактировать пост"
  final VoidCallback? onDelete; // Нажали "Удалить пост"
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
  Widget build(BuildContext context) {
    // Ключ нам нужен, чтобы вычислить положение кнопки "…"
    // и привязать к ней универсальное всплывающее меню.
    final menuKey = GlobalKey();

    return Container(
      width: double.infinity,
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
          // ШАПКА: единый UserHeader (аватар, имя, дата, trailing-меню)
          // ──────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: UserHeader(
              userName: post.userName,
              userAvatar: post.userAvatar,
              dateText: post.postDateText,

              // trailing — наша кнопка "…"
              trailing: IconButton(
                key: menuKey,
                icon: const Icon(CupertinoIcons.ellipsis),
                onPressed: () {
                  final items = <MoreMenuItem>[
                    MoreMenuItem(
                      text: 'Редактировать пост',
                      icon: CupertinoIcons.pencil,
                      onTap: onEdit ?? () {},
                    ),
                    MoreMenuItem(
                      text: 'Удалить пост',
                      icon: CupertinoIcons.minus_circle,
                      iconColor: const Color(0xFFE53935),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFE53935),
                      ),
                      onTap: onDelete ?? () {},
                    ),
                  ];
                  MoreMenuOverlay(
                    anchorKey: menuKey,
                    items: items,
                  ).show(context);
                },
              ),
            ),
          ),

          // ──────────────────────────────────────────────────────────────
          // МЕДИА-КАРУСЕЛЬ: картинки/видео, высота фиксирована (как у тебя)
          // ──────────────────────────────────────────────────────────────
          SizedBox(
            height: 300,
            width: double.infinity,
            child: PostMediaCarousel(
              imageUrls: post.mediaImages,
              videoUrls: post.mediaVideos,
            ),
          ),

          // ──────────────────────────────────────────────────────────────
          // ТЕКСТ ПОСТА (если пустой — ничего не рисуем)
          // ──────────────────────────────────────────────────────────────
          if (post.postContent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(post.postContent),
            ),

          // ──────────────────────────────────────────────────────────────
          // НИЖНЯЯ ПАНЕЛЬ: лайк и комментарии
          // ──────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Лайк-бар: локальная анимация + API
                _PostLikeBar(post: post, currentUserId: currentUserId),
                const SizedBox(width: 16),

                // Кнопка «комментарии» — экран ленты откроет bottom sheet
                GestureDetector(
                  onTap: onOpenComments,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.chat_bubble,
                        size: 20,
                        color: AppColors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(post.comments.toString()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Лайк-бар для поста: анимация сердца + вызов API.
/// Приватен для PostCard, чтобы экран ленты был проще.
class _PostLikeBar extends StatefulWidget {
  final Activity post;
  final int currentUserId;

  const _PostLikeBar({required this.post, required this.currentUserId});

  @override
  State<_PostLikeBar> createState() => _PostLikeBarState();
}

class _PostLikeBarState extends State<_PostLikeBar>
    with SingleTickerProviderStateMixin {
  bool isLiked = false; // локальное состояние лайка
  int likesCount = 0; // локальный счётчик лайков
  bool _busy = false; // защита от дабл-тапов

  late AnimationController _likeController;
  late Animation<double> _likeAnimation;

  // Тот же эндпойнт, что и для активностей (у тебя уже есть на бэке)
  static const String _likeEndpoint =
      'http://api.paceup.ru/activity_likes_toggle.php';

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
    final uri = Uri.parse(_likeEndpoint);

    try {
      final res = await http
          .post(
            uri,
            // У тебя сервер принимает JSON — так и оставим
            body: jsonEncode({
              'userId': '$userId',
              'activityId': '$activityId',
              'type': type,
              'action': isLikedNow ? 'like' : 'dislike',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return false;

      final raw = utf8.decode(res.bodyBytes);
      dynamic data;
      try {
        data = json.decode(raw);
      } catch (_) {
        data = null;
      }

      bool ok = false;
      int? serverLikes;

      if (data is Map<String, dynamic>) {
        ok = data['ok'] == true || data['status'] == 'ok';
        serverLikes = int.tryParse('${data['likes']}');
      } else if (data is List &&
          data.isNotEmpty &&
          data.first is Map<String, dynamic>) {
        final m = data.first as Map<String, dynamic>;
        ok = m['ok'] == true || m['status'] == 'ok';
        serverLikes = int.tryParse('${m['likes']}');
      } else {
        final t = raw.trim().toLowerCase();
        ok = (res.statusCode == 200) && (t == 'ok' || t == '1' || t == 'true');
      }

      // Если сервер отдал точное число лайков — синхронизируем
      if (ok && serverLikes != null && mounted) {
        setState(() => likesCount = serverLikes!);
      }
      return ok;
    } on TimeoutException {
      return false;
    } catch (_) {
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
              color: AppColors.red,
            ),
          ),
          const SizedBox(width: 4),
          Text(likesCount.toString()),
        ],
      ),
    );
  }
}
