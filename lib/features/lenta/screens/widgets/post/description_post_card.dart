import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../domain/models/activity_lenta.dart';
import '../../../../../core/widgets/app_bar.dart';
import '../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../core/widgets/expandable_text.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../../../core/services/api_service.dart';
import '../../../../../core/utils/feed_date.dart';
import 'post_media_carousel.dart';
import '../../../widgets/user_header.dart';
import '../../widgets/comments_bottom_sheet.dart';
import '../../../../profile/screens/profile_screen.dart';
import '../../../../../core/widgets/transparent_route.dart';

/// ─────────────────────────────────────────────────────────────────────────────
///   ЭКРАН ОПИСАНИЯ ПОСТА
///   Страница для просмотра поста с AppBar со стрелкой назад
///   Используется при переходе из уведомлений
/// ─────────────────────────────────────────────────────────────────────────────
class PostDescriptionScreen extends ConsumerStatefulWidget {
  /// Модель поста (id, автор, даты, медиа, текст, лайки, комменты)
  final Activity post;

  /// Текущий пользователь (для лайка/комментирования)
  final int currentUserId;

  const PostDescriptionScreen({
    super.key,
    required this.post,
    required this.currentUserId,
  });

  @override
  ConsumerState<PostDescriptionScreen> createState() =>
      _PostDescriptionScreenState();
}

class _PostDescriptionScreenState
    extends ConsumerState<PostDescriptionScreen> {
  /// Текущее состояние поста (для синхронизации лайков и комментариев)
  late Activity _currentPost;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
  }

  /// ─────────────────────────────────────────────────────────────────────────────
  /// ВСПОМОГАТЕЛЬНЫЙ МЕТОД: создание копии Activity с обновленными лайками и islike
  /// ─────────────────────────────────────────────────────────────────────────────
  Activity _updatePostLikes(int newLikes, bool newIslike) {
    return Activity(
      id: _currentPost.id,
      type: _currentPost.type,
      dateStart: _currentPost.dateStart,
      dateEnd: _currentPost.dateEnd,
      lentaId: _currentPost.lentaId,
      lentaDate: _currentPost.lentaDate,
      userId: _currentPost.userId,
      userName: _currentPost.userName,
      userAvatar: _currentPost.userAvatar,
      likes: newLikes,
      comments: _currentPost.comments,
      userGroup: _currentPost.userGroup,
      equipments: _currentPost.equipments,
      stats: _currentPost.stats,
      points: _currentPost.points,
      postDateText: _currentPost.postDateText,
      postMediaUrl: _currentPost.postMediaUrl,
      postContent: _currentPost.postContent,
      islike: newIslike,
      mediaImages: _currentPost.mediaImages,
      mediaVideos: _currentPost.mediaVideos,
      mapSortOrder: _currentPost.mapSortOrder,
    );
  }


  /// ─────────────────────────────────────────────────────────────────────────────
  /// ОТКРЫТИЕ КОММЕНТАРИЕВ: показываем bottom sheet с комментариями
  /// ─────────────────────────────────────────────────────────────────────────────
  void _openComments() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsBottomSheet(
        itemType: 'post',
        itemId: _currentPost.id,
        currentUserId: widget.currentUserId,
        lentaId: _currentPost.lentaId,
        onCommentAdded: () {
          // Обновляем счетчик комментариев
          setState(() {
            _currentPost = _currentPost.copyWithComments(
              _currentPost.comments + 1,
            );
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? AppColors.surface
            : AppColors.getBackgroundColor(context),

        appBar: PaceAppBar(
          title: 'Пост',
          actions: const [], // Без кнопок справа
        ),

        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ──────────────────────────────────────────────────────────────
                // ШАПКА: единый UserHeader (аватар, имя, дата)
                // ──────────────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: UserHeader(
                    userName: _currentPost.userName,
                    userAvatar: _currentPost.userAvatar,
                    dateText: formatFeedDateText(
                      serverText: _currentPost.postDateText,
                      date: _currentPost.dateStart,
                    ),

                    // ──────────────────────────────────────────────────────────────
                    // ПЕРЕХОД В ПРОФИЛЬ: клик на аватар или имя открывает профиль автора
                    // ──────────────────────────────────────────────────────────────
                    onAvatarTap: () {
                      Navigator.of(context).push(
                        TransparentPageRoute(
                          builder: (_) =>
                              ProfileScreen(userId: _currentPost.userId),
                        ),
                      );
                    },
                    onNameTap: () {
                      Navigator.of(context).push(
                        TransparentPageRoute(
                          builder: (_) =>
                              ProfileScreen(userId: _currentPost.userId),
                        ),
                      );
                    },
                  ),
                ),

                // ──────────────────────────────────────────────────────────────
                // МЕДИА-КАРУСЕЛЬ: картинки/видео, высота 350
                // ──────────────────────────────────────────────────────────────
                SizedBox(
                  height: 350,
                  width: double.infinity,
                  child: PostMediaCarousel(
                    imageUrls: _currentPost.mediaImages,
                    videoUrls: _currentPost.mediaVideos,
                  ),
                ),

                // ──────────────────────────────────────────────────────────────
                // ТЕКСТ ПОСТА: после медиа, до лайков/комментариев (с раскрытием)
                // ──────────────────────────────────────────────────────────────
                if (_currentPost.postContent.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: ExpandableText(text: _currentPost.postContent),
                  ),

                // ──────────────────────────────────────────────────────────────
                // НИЖНЯЯ ПАНЕЛЬ: лайк и комментарии
                // ──────────────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Лайк-бар: локальная анимация + API
                      _PostLikeBar(
                        post: _currentPost,
                        currentUserId: widget.currentUserId,
                        onLikeChanged: (likes, isLiked) {
                          // Обновляем состояние поста при изменении лайка
                          setState(() {
                            _currentPost = _updatePostLikes(likes, isLiked);
                          });
                        },
                      ),
                      const SizedBox(width: 16),

                      // Кнопка «комментарии» — открывает bottom sheet
                      GestureDetector(
                        onTap: _openComments,
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
                              _currentPost.comments.toString(),
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
          ),
        ),
      ),
    );
  }
}

/// Лайк-бар для поста: анимация сердца + вызов API.
class _PostLikeBar extends ConsumerStatefulWidget {
  final Activity post;
  final int currentUserId;
  final Function(int likes, bool isLiked)? onLikeChanged;

  const _PostLikeBar({
    required this.post,
    required this.currentUserId,
    this.onLikeChanged,
  });

  @override
  ConsumerState<_PostLikeBar> createState() => _PostLikeBarState();
}

class _PostLikeBarState extends ConsumerState<_PostLikeBar>
    with SingleTickerProviderStateMixin {
  bool isLiked = false;
  int likesCount = 0;
  bool _busy = false;

  late AnimationController _likeController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
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

  /// Обработчик тапа по сердцу: оптимистичное обновление + синхронизация с сервером
  Future<void> _onTap() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      isLiked = !isLiked;
      likesCount += isLiked ? 1 : -1;
    });
    _likeController.forward(from: 0);

    final ok = await _sendLike(
      activityId: widget.post.id,
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
    } else if (mounted) {
      // Уведомляем родителя об изменении
      widget.onLikeChanged?.call(likesCount, isLiked);
    }

    if (mounted) setState(() => _busy = false);
  }

  /// Сетевая часть: шлём действие like/dislike
  Future<bool> _sendLike({
    required int activityId,
    required int userId,
    required bool isLikedNow,
    required String type,
  }) async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/activity_likes_toggle.php',
        body: {
          'userId': '$userId',
          'activityId': '$activityId',
          'type': type,
          'action': isLikedNow ? 'like' : 'dislike',
        },
        timeout: const Duration(seconds: 10),
      );

      final actualData = data['data'] is List &&
              (data['data'] as List).isNotEmpty
          ? (data['data'] as List)[0] as Map<String, dynamic>
          : data;

      final ok = actualData['ok'] == true || actualData['status'] == 'ok';
      final serverLikes = int.tryParse('${actualData['likes']}');

      // Если сервер отдал точное число лайков — синхронизируем
      if (ok && serverLikes != null && mounted) {
        setState(() => likesCount = serverLikes);
        widget.onLikeChanged?.call(likesCount, isLiked);
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
