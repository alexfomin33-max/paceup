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
import '../../../../../core/utils/error_handler.dart';
import 'post_media_carousel.dart';
import '../../../widgets/user_header.dart';
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

  /// Список комментариев
  List<_CommentItem> _comments = [];
  bool _isLoadingComments = false;
  String? _commentsError;
  int _commentsPage = 1;
  bool _hasMoreComments = true;

  /// Поле ввода комментария
  late TextEditingController _commentController;
  late FocusNode _commentFocusNode;
  bool _sendingComment = false;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _commentController = TextEditingController();
    _commentFocusNode = FocusNode();
    // Загружаем список лайков только если есть лайки
    if (_currentPost.likes > 0) {
      _loadLikedUsers();
    }
    // Загружаем комментарии только если есть комментарии
    if (_currentPost.comments > 0) {
      _loadComments();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
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
  /// ЗАГРУЗКА КОММЕНТАРИЕВ
  /// ─────────────────────────────────────────────────────────────────────────────
  Future<void> _loadComments({bool refresh = false}) async {
    if (_isLoadingComments) return;
    if (refresh) {
      _commentsPage = 1;
      _hasMoreComments = true;
      _commentsError = null;
    }
    if (!_hasMoreComments) return;

    setState(() {
      _isLoadingComments = true;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/comments_list.php',
        body: {
          // Используем фактический тип активности, как в bottom sheet
          'type': _currentPost.type,
          'item_id': '${_currentPost.id}',
          'page': '$_commentsPage',
          'limit': '20',
          'userId': '${widget.currentUserId}',
        },
        timeout: const Duration(seconds: 10),
      );

      if (!(_isTruthy(data['success']) || _isTruthy(data['status']))) {
        throw Exception((data['error'] ?? 'Ошибка формата данных').toString());
      }

      final List<_CommentItem> list = (data['comments'] as List? ?? [])
          .map((e) => _CommentItem.fromApi(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        if (refresh) {
          _comments
            ..clear()
            ..addAll(list);
        } else {
          _comments.addAll(list);
        }
        _hasMoreComments = list.length >= 20;
        _commentsPage += 1;
        _isLoadingComments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _commentsError = ErrorHandler.format(e);
        _isLoadingComments = false;
      });
    }
  }

  /// ─────────────────────────────────────────────────────────────────────────────
  /// ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ: проверка истинности значения
  /// ─────────────────────────────────────────────────────────────────────────────
  bool _isTruthy(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' ||
          s == '1' ||
          s == 'ok' ||
          s == 'success' ||
          s == 'yes';
    }
    return false;
  }

  /// ─────────────────────────────────────────────────────────────────────────────
  /// ОТПРАВКА КОММЕНТАРИЯ
  /// ─────────────────────────────────────────────────────────────────────────────
  Future<void> _sendComment(String text) async {
    if (text.isEmpty || _sendingComment) return;
    setState(() => _sendingComment = true);

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/comments_add.php',
        body: {
          'type': _currentPost.type,
          'item_id': '${_currentPost.id}',
          'text': text,
          'userId': '${widget.currentUserId}',
        },
        timeout: const Duration(seconds: 10),
      );

      if (!(_isTruthy(data['success']) || _isTruthy(data['status']))) {
        throw Exception(
          (data['error'] ?? 'Не удалось отправить комментарий').toString(),
        );
      }

      _CommentItem? newItem;
      final c = data['comment'];
      if (c is Map<String, dynamic>) {
        newItem = _CommentItem.fromApi(c);
      } else if (c is List && c.isNotEmpty && c.first is Map<String, dynamic>) {
        newItem = _CommentItem.fromApi(c.first as Map<String, dynamic>);
      }

      if (!mounted) return;
      if (newItem != null) {
        setState(() {
          _comments.insert(0, newItem!); // свежие сверху
          _currentPost = _currentPost.copyWithComments(
            _currentPost.comments + 1,
          );
        });
      } else {
        // Если не получили новый комментарий, перезагружаем список
        await _loadComments(refresh: true);
        setState(() {
          _currentPost = _currentPost.copyWithComments(
            _currentPost.comments + 1,
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Показываем ошибку через debugPrint (согласно правилам)
      debugPrint('Ошибка отправки комментария: $e');
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
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
          child: Column(
            children: [
              // ──────────────────────────────────────────────────────────────
              // ПРОКРУЧИВАЕМЫЙ КОНТЕНТ
              // ──────────────────────────────────────────────────────────────
              Expanded(
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
                                  builder: (_) => ProfileScreen(
                                    userId: _currentPost.userId,
                                  ),
                                ),
                              );
                            },
                            onNameTap: () {
                              Navigator.of(context).push(
                                TransparentPageRoute(
                                  builder: (_) => ProfileScreen(
                                    userId: _currentPost.userId,
                                  ),
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
                            child: ExpandableText(
                              text: _currentPost.postContent,
                            ),
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
                                likedUsers: _likedUsers,
                                onLikeChanged: (likes, isLiked) {
                                  // Обновляем состояние поста при изменении лайка
                                  setState(() {
                                    _currentPost = _updatePostLikes(
                                      likes,
                                      isLiked,
                                    );
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

                      // ──────────────────────────────────────────────────────────────
                      // СПИСОК КОММЕНТАРИЕВ
                      // ──────────────────────────────────────────────────────────────
                      if (_currentPost.comments > 0) ...[
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
                            child: _CommentsList(
                              comments: _comments,
                              isLoading: _isLoadingComments,
                              error: _commentsError,
                              hasMore: _hasMoreComments,
                              onRetry: () => _loadComments(refresh: true),
                              onLoadMore: () => _loadComments(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // ──────────────────────────────────────────────────────────────
        // БЛОК ВВОДА КОММЕНТАРИЯ: зафиксирован внизу экрана
        // ──────────────────────────────────────────────────────────────
        bottomNavigationBar: SafeArea(
          top: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.getSurfaceColor(context),
                border: Border(
                  top: BorderSide(
                    width: 0.5,
                    color: AppColors.getBorderColor(context),
                  ),
                ),
              ),
              child: _ComposerBar(
                controller: _commentController,
                focusNode: _commentFocusNode,
                sending: _sendingComment,
                onSend: _sendComment,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// БЛОК ВВОДА КОММЕНТАРИЯ: поле ввода + кнопка отправки
/// ─────────────────────────────────────────────────────────────────────────────
class _ComposerBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final Future<void> Function(String text) onSend;

  const _ComposerBar({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────
    // 🔹 Отслеживаем изменения текста для активации/деактивации кнопки
    // ────────────────────────────────────────────────────────────────
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        final isEnabled = hasText && !sending;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: AppTextStyles.h14w4.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: "Написать комментарий...",
                    hintStyle: AppTextStyles.h14w4Place.copyWith(
                      color: AppColors.getTextPlaceholderColor(context),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.getBackgroundColor(context),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: isEnabled
                    ? () async {
                        // 1) аккуратно забираем текст
                        controller.clearComposing();
                        final text = controller.text.trim();
                        if (text.isEmpty) return;

                        // 2) СРАЗУ очищаем поле (до сети)
                        controller.value = const TextEditingValue(
                          text: '',
                          selection: TextSelection.collapsed(offset: 0),
                          composing: TextRange.empty,
                        );

                        // 3) Можно оставить фокус в поле
                        focusNode.requestFocus();

                        // 4) Отправляем наверх уже «снятый» текст
                        await onSend(text);
                      }
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CupertinoActivityIndicator(),
                      )
                    : Icon(
                        Icons.send,
                        size: 22,
                        color: isEnabled
                            ? AppColors.brandPrimary
                            : AppColors.getTextPlaceholderColor(context),
                      ),
              ),
            ],
          ),
        );
      },
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
/// МОДЕЛЬ КОММЕНТАРИЯ
/// ─────────────────────────────────────────────────────────────────────────────
class _CommentItem {
  final int id;
  final String userName;
  final String? userAvatar;
  final String text;
  final String createdAt;

  const _CommentItem({
    required this.id,
    required this.userName,
    required this.text,
    required this.createdAt,
    this.userAvatar,
  });

  factory _CommentItem.fromApi(Map<String, dynamic> json) {
    return _CommentItem(
      id: int.tryParse('${json['id']}') ?? 0,
      userName: (json['user_name'] ?? '').toString(),
      userAvatar: (json['user_avatar']?.toString().isNotEmpty ?? false)
          ? json['user_avatar'].toString()
          : null,
      text: (json['text'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
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
                style: const TextStyle(color: AppColors.error, fontSize: 13),
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

/// ─────────────────────────────────────────────────────────────────────────────
/// СПИСОК КОММЕНТАРИЕВ
/// ─────────────────────────────────────────────────────────────────────────────
class _CommentsList extends StatelessWidget {
  final List<_CommentItem> comments;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final VoidCallback? onRetry;
  final VoidCallback? onLoadMore;

  const _CommentsList({
    required this.comments,
    required this.isLoading,
    this.error,
    required this.hasMore,
    this.onRetry,
    this.onLoadMore,
  });

  /// Форматирование даты: "сегодня, 18:50" / "вчера, 18:50" / "12 июл, 18:50"
  String _formatHumanDate(String raw) {
    final dt = _tryParseDate(raw);
    if (dt == null) return raw;

    final now = DateTime.now();
    final local = dt.toLocal();

    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(day).inDays;

    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final time = '$hh:$mm';

    if (diffDays == 0) return 'сегодня, $time';
    if (diffDays == 1) return 'вчера, $time';

    final month = _ruMonth(local.month, short: true);
    if (local.year == now.year) {
      return '${local.day} $month, $time';
    } else {
      return '${local.day} $month ${local.year}, $time';
    }
  }

  DateTime? _tryParseDate(String s) {
    try {
      final t = s.contains(' ') ? s.replaceFirst(' ', 'T') : s;
      return DateTime.parse(t);
    } catch (_) {
      try {
        final parts = s.split(' ');
        if (parts.length >= 2) {
          final d = parts[0]
              .split('-')
              .map((e) => int.tryParse(e) ?? 0)
              .toList();
          final tm = parts[1]
              .split(':')
              .map((e) => int.tryParse(e) ?? 0)
              .toList();
          if (d.length >= 3 && tm.length >= 2) {
            return DateTime(
              d[0],
              d[1],
              d[2],
              tm[0],
              tm[1],
              tm.length >= 3 ? tm[2] : 0,
            );
          }
        }
      } catch (_) {}
      return null;
    }
  }

  String _ruMonth(int m, {bool short = false}) {
    const monthsShort = [
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    if (m < 1 || m > 12) return '';
    return monthsShort[m - 1];
  }

  /// ─────────────────────────────────────────────────────────────────────────────
  /// ФОРМИРОВАНИЕ ТЕКСТА ЗАГОЛОВКА С ПРАВИЛЬНЫМ СКЛОНЕНИЕМ
  /// ─────────────────────────────────────────────────────────────────────────────
  String _getCommentsTitle(int count) {
    if (count == 0) return 'Комментарии';

    final lastDigit = count % 10;
    final lastTwoDigits = count % 100;

    // Исключения для 11-14
    if (lastTwoDigits >= 11 && lastTwoDigits <= 14) {
      return '$count комментариев';
    }

    // 1, 21, 31, 41... комментарий
    if (lastDigit == 1) {
      return '$count комментарий';
    }

    // 2, 3, 4, 22, 23, 24... комментария
    if (lastDigit >= 2 && lastDigit <= 4) {
      return '$count комментария';
    }

    // Остальные: комментариев
    return '$count комментариев';
  }

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────
    // СОСТОЯНИЕ ЗАГРУЗКИ: показываем индикатор
    // ────────────────────────────────────────────────────────────────
    if (isLoading && comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CupertinoActivityIndicator(radius: 10)),
      );
    }

    // ────────────────────────────────────────────────────────────────
    // СОСТОЯНИЕ ОШИБКИ: показываем ошибку с кнопкой повтора
    // ────────────────────────────────────────────────────────────────
    if (error != null && comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SelectableText.rich(
              TextSpan(
                text: error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
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
    if (comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Нет комментариев',
          style: AppTextStyles.h13w4.copyWith(
            color: AppColors.getTextSecondaryColor(context),
          ),
        ),
      );
    }

    // ────────────────────────────────────────────────────────────────
    // СПИСОК КОММЕНТАРИЕВ: отображаем все комментарии
    // ────────────────────────────────────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок с количеством комментариев
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Text(
            _getCommentsTitle(comments.length),
            style: AppTextStyles.h15w5.copyWith(
              color: AppColors.getTextSecondaryColor(context),
            ),
          ),
        ),
        // Список комментариев
        ...List.generate(comments.length, (index) {
          final comment = comments[index];
          final humanDate = _formatHumanDate(comment.createdAt);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Аватар
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.getSurfaceMutedColor(context),
                      backgroundImage:
                          (comment.userAvatar != null &&
                              comment.userAvatar!.isNotEmpty)
                          ? NetworkImage(comment.userAvatar!)
                          : null,
                      child:
                          (comment.userAvatar == null ||
                              comment.userAvatar!.isEmpty)
                          ? Text(
                              comment.userName.isNotEmpty
                                  ? comment.userName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    // Имя, дата и текст
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Имя пользователя и дата
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  comment.userName,
                                  style: AppTextStyles.h14w6.copyWith(
                                    letterSpacing: 0,
                                    color: AppColors.getTextPrimaryColor(
                                      context,
                                    ),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '· $humanDate',
                                style: AppTextStyles.h12w4Ter.copyWith(
                                  color: AppColors.getTextTertiaryColor(
                                    context,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Текст комментария
                          Text(
                            comment.text,
                            style: AppTextStyles.h13w4.copyWith(
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
          );
        }),
        // Индикатор загрузки следующей страницы
        if (isLoading && comments.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator(radius: 10)),
          ),
        // Кнопка "Загрузить ещё" если есть ещё комментарии
        if (hasMore && !isLoading && comments.isNotEmpty && onLoadMore != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: GestureDetector(
                onTap: onLoadMore,
                child: Text(
                  'Загрузить ещё',
                  style: AppTextStyles.h14w5.copyWith(
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Лайк-бар для поста: анимация сердца + вызов API.
class _PostLikeBar extends ConsumerStatefulWidget {
  final Activity post;
  final int currentUserId;
  final List<_LikeUser> likedUsers;
  final Function(int likes, bool isLiked)? onLikeChanged;

  const _PostLikeBar({
    required this.post,
    required this.currentUserId,
    required this.likedUsers,
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
          // ──────────────────────────────────────────────────────────────
          // МИНИ-АВАТАРКИ ПОЛЬЗОВАТЕЛЕЙ, КОТОРЫЕ ПОСТАВИЛИ ЛАЙК
          // ──────────────────────────────────────────────────────────────
          if (widget.likedUsers.isNotEmpty) ...[
            const SizedBox(width: 8),
            _LikedUsersAvatars(users: widget.likedUsers),
          ],
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// МИНИ-АВАТАРКИ ПОЛЬЗОВАТЕЛЕЙ, КОТОРЫЕ ПОСТАВИЛИ ЛАЙК
/// Показываем максимум 3 аватарки с наложением (аналогично участникам клуба)
/// ─────────────────────────────────────────────────────────────────────────────
class _LikedUsersAvatars extends StatelessWidget {
  final List<_LikeUser> users;

  const _LikedUsersAvatars({required this.users});

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
    if (users.isEmpty) {
      return const SizedBox.shrink();
    }

    // Берем первые 3 пользователя
    final displayUsers = users.take(3).toList();
    final avatarSize = 20.0; // Очень маленький размер
    final overlap = 4.0; // Наложение между аватарками

    return SizedBox(
      height: avatarSize,
      width: avatarSize + (displayUsers.length - 1) * (avatarSize - overlap),
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(displayUsers.length, (index) {
          final user = displayUsers[index];
          final avatarUrl = _getAvatarUrl(user.avatar, user.id);
          return Positioned(
            left: index * (avatarSize - overlap),
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.getSurfaceColor(context),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: avatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        width: avatarSize,
                        height: avatarSize,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: avatarSize,
                          height: avatarSize,
                          color: AppColors.getBorderColor(context),
                          child: Center(
                            child: CupertinoActivityIndicator(
                              radius: avatarSize * 0.2,
                              color: AppColors.getIconSecondaryColor(context),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: avatarSize,
                          height: avatarSize,
                          color: AppColors.getBorderColor(context),
                          child: Icon(
                            Icons.person,
                            size: avatarSize * 0.6,
                            color: AppColors.getIconSecondaryColor(context),
                          ),
                        ),
                      )
                    : Container(
                        width: avatarSize,
                        height: avatarSize,
                        color: AppColors.getBorderColor(context),
                        child: Icon(
                          Icons.person,
                          size: avatarSize * 0.6,
                          color: AppColors.getIconSecondaryColor(context),
                        ),
                      ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
