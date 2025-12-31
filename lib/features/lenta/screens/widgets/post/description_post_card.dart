import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
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

class _PostDescriptionScreenState extends ConsumerState<PostDescriptionScreen> {
  /// Текущее состояние поста (для синхронизации лайков и комментариев)
  late Activity _currentPost;

  /// Список пользователей, которые поставили лайк
  List<_LikeUser> _likedUsers = [];
  bool _isLoadingLikes = false;
  String? _likesError;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    // Загружаем список лайков только если есть лайки
    if (_currentPost.likes > 0) {
      _loadLikedUsers();
    }
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
  /// ЗАГРУЗКА СПИСКА ПОЛЬЗОВАТЕЛЕЙ, КОТОРЫЕ ПОСТАВИЛИ ЛАЙК
  /// ─────────────────────────────────────────────────────────────────────────────
  Future<void> _loadLikedUsers() async {
    if (_isLoadingLikes) return;

    setState(() {
      _isLoadingLikes = true;
      _likesError = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/get_activity_likes.php',
        body: {'activityId': '${_currentPost.id}', 'type': 'post'},
        timeout: const Duration(seconds: 10),
      );

      if (data['ok'] == true || data['success'] == true) {
        final usersList = data['users'] as List<dynamic>? ?? [];
        setState(() {
          _likedUsers = usersList.map((item) {
            return _LikeUser(
              id: int.tryParse('${item['user_id']}') ?? 0,
              name: item['name']?.toString() ?? 'Пользователь',
              avatar: item['avatar']?.toString() ?? '',
            );
          }).toList();
          _isLoadingLikes = false;
        });
      } else {
        setState(() {
          _likesError =
              data['message']?.toString() ??
              'Не удалось загрузить список лайков';
          _isLoadingLikes = false;
        });
      }
    } catch (e) {
      setState(() {
        _likesError = 'Ошибка загрузки: ${e.toString()}';
        _isLoadingLikes = false;
      });
    }
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
        backgroundColor: AppColors.getBackgroundColor(context),

        appBar: const PaceAppBar(
          title: 'Пост',
          actions: [], // Без кнопок справа
        ),

        body: SafeArea(
          top: false,
          bottom: false,
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
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.getSurfaceColor(context),
                    border: Border(
                      top: BorderSide(
                        width: 0.5,
                        color: AppColors.getBorderColor(context),
                      ),
                      bottom: BorderSide(
                        width: 0.5,
                        color: AppColors.getBorderColor(context),
                      ),
                    ),
                  ),
                  child: Padding(
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
                ),

                // ──────────────────────────────────────────────────────────────
                // МЕДИА-КАРУСЕЛЬ: картинки/видео, высота 350
                // ──────────────────────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  color: AppColors.getSurfaceColor(context),
                  child: SizedBox(
                    height: 350,
                    width: double.infinity,
                    child: PostMediaCarousel(
                      imageUrls: _currentPost.mediaImages,
                      videoUrls: _currentPost.mediaVideos,
                    ),
                  ),
                ),

                // ──────────────────────────────────────────────────────────────
                // ТЕКСТ ПОСТА: после медиа, до лайков/комментариев (с раскрытием)
                // ──────────────────────────────────────────────────────────────
                if (_currentPost.postContent.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: AppColors.getSurfaceColor(context),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: ExpandableText(text: _currentPost.postContent),
                    ),
                  ),

                // ──────────────────────────────────────────────────────────────
                // НИЖНЯЯ ПАНЕЛЬ: лайк и комментарии
                // ──────────────────────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.getSurfaceColor(context),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AppRadius.xl),
                      bottomRight: Radius.circular(AppRadius.xl),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
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
                            // Обновляем список пользователей, которые поставили лайк
                            if (_currentPost.likes > 0) {
                              _loadLikedUsers();
                            } else {
                              setState(() {
                                _likedUsers = [];
                              });
                            }
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
                ),

                // ──────────────────────────────────────────────────────────────
                // СПИСОК ПОЛЬЗОВАТЕЛЕЙ, КОТОРЫЕ ПОСТАВИЛИ ЛАЙК
                // ──────────────────────────────────────────────────────────────
                if (_currentPost.likes > 0) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.getSurfaceColor(context),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.getBorderColor(context),
                          width: 1,
                        ),
                      ),
                      child: _LikedUsersList(
                        users: _likedUsers,
                        isLoading: _isLoadingLikes,
                        error: _likesError,
                        onRetry: _loadLikedUsers,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// МОДЕЛЬ ПОЛЬЗОВАТЕЛЯ, КОТОРЫЙ ПОСТАВИЛ ЛАЙК
/// ─────────────────────────────────────────────────────────────────────────────
class _LikeUser {
  final int id;
  final String name;
  final String avatar;

  const _LikeUser({required this.id, required this.name, required this.avatar});
}

/// ─────────────────────────────────────────────────────────────────────────────
/// СПИСОК ПОЛЬЗОВАТЕЛЕЙ, КОТОРЫЕ ПОСТАВИЛИ ЛАЙК
/// ─────────────────────────────────────────────────────────────────────────────
class _LikedUsersList extends StatelessWidget {
  final List<_LikeUser> users;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;

  const _LikedUsersList({
    required this.users,
    required this.isLoading,
    this.error,
    this.onRetry,
  });

  /// Формирование URL для аватара
  String _getAvatarUrl(String avatar, int userId) {
    if (avatar.isEmpty) {
      return 'http://uploads.paceup.ru/images/users/avatars/def.png';
    }
    if (avatar.startsWith('http')) return avatar;
    return 'http://uploads.paceup.ru/images/users/avatars/$userId/$avatar';
  }

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────
    // СОСТОЯНИЕ ЗАГРУЗКИ: показываем индикатор
    // ────────────────────────────────────────────────────────────────
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CupertinoActivityIndicator(radius: 10)),
      );
    }

    // ────────────────────────────────────────────────────────────────
    // СОСТОЯНИЕ ОШИБКИ: показываем ошибку с кнопкой повтора
    // ────────────────────────────────────────────────────────────────
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SelectableText.rich(
              TextSpan(
                text: error!,
                style: TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onRetry,
                child: Text(
                  'Повторить',
                  style: AppTextStyles.h14w5.copyWith(
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // ────────────────────────────────────────────────────────────────
    // ПУСТОЕ СОСТОЯНИЕ: если список пуст
    // ────────────────────────────────────────────────────────────────
    if (users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Нет данных о пользователях',
          style: AppTextStyles.h13w4.copyWith(
            color: AppColors.getTextSecondaryColor(context),
          ),
        ),
      );
    }

    // ────────────────────────────────────────────────────────────────
    // СПИСОК ПОЛЬЗОВАТЕЛЕЙ: отображаем всех пользователей
    // ────────────────────────────────────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Text(
            'Лайки',
            style: AppTextStyles.h15w6.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: AppColors.getBorderColor(context),
        ),
        // Список пользователей
        ...List.generate(users.length, (index) {
          final user = users[index];
          final avatarUrl = _getAvatarUrl(user.avatar, user.id);
          final isLast = index == users.length - 1;

          return Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).push(
                    TransparentPageRoute(
                      builder: (_) => ProfileScreen(userId: user.id),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      // Аватар
                      ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: avatarUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 44,
                            height: 44,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkSurfaceMuted
                                : AppColors.skeletonBase,
                            child: Center(
                              child: CupertinoActivityIndicator(
                                radius: 9,
                                color: AppColors.getIconSecondaryColor(context),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 44,
                            height: 44,
                            color: AppColors.skeletonBase,
                            child: const Icon(
                              CupertinoIcons.person_fill,
                              size: 24,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Имя пользователя
                      Expanded(
                        child: Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.h15w5.copyWith(
                            color: AppColors.getTextPrimaryColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppColors.getBorderColor(context),
                ),
            ],
          );
        }),
        const SizedBox(height: 8),
      ],
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

      final actualData =
          data['data'] is List && (data['data'] as List).isNotEmpty
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
