import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'widgets/activity_block.dart';
import 'newpost_screen.dart';
import 'widgets/comments_bottom_sheet.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'chat/chat_screen.dart'; // импортируем страницу чата
import 'notifications/notifications_screen.dart';
import 'dart:ui'; // для ImageFilter.blur
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:paceup/models/activity_lenta.dart';
import 'widgets/activity_description_block.dart';
import 'widgets/recommended_block.dart';

import 'dart:async';

/// Единые размеры для AppBar в iOS-стиле
const double kAppBarIconSize = 22.0; // сама иконка ~20–22pt
const double kAppBarTapTarget = 42.0; // кликабельная область 42×42
const double kToolbarH = 52.0; // высота AppBar (iOS-лайк, компактнее 56)

/// 🔹 Экран Ленты (Feed)
class LentaScreen extends StatefulWidget {
  final int userId;
  final VoidCallback? onNewPostPressed;

  const LentaScreen({super.key, required this.userId, this.onNewPostPressed});

  @override
  State<LentaScreen> createState() => _LentaScreenState();
}

// ✅ сохраняем позицию скролла при переключении вкладок
class _LentaScreenState extends State<LentaScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late Future<List<Activity>> _future;

  /// Контроллер списка — нужен для скролла в начало по двойному тапу по заголовку
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _future = _loadActivities();
  }

  Future<List<Activity>> _loadActivities() async {
    final res = await http.post(
      Uri.parse('http://api.paceup.ru/activities_lenta.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'userId': widget.userId, 'limit': 20, 'page': 1}),
    );
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final decoded = json.decode(res.body);
    final List list = decoded is Map<String, dynamic>
        ? (decoded['data'] as List)
        : (decoded as List);

    return list
        .map((e) => Activity.fromApi(e as Map<String, dynamic>))
        .toList();
  }

  int _unreadCount =
      3; // пример начального количества непрочитанных уведомлений

  @override
  Widget build(BuildContext context) {
    super.build(context); // важно для keep-alive

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        toolbarHeight: kToolbarH, // ← явная высота AppBar
        backgroundColor: Colors.white.withValues(alpha: 0.50),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.transparent),
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,

        // Чуть меньше дефолта, чтобы пара иконок слева точно помещалась
        leadingWidth: 96,

        shape: const Border(
          bottom: BorderSide(color: Color(0x33FFFFFF), width: 0.6),
        ),

        // Левая группа иконок
        leading: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _NavIcon(icon: CupertinoIcons.star, onPressed: () {}),
              const SizedBox(width: 4),
              _NavIcon(
                icon: CupertinoIcons.add_circled,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NewPostScreen(userId: widget.userId)),
                  );
                },
              ),
            ],
          ),
        ),

        title: const Text("Лента", style: AppTextStyles.h1),

        // Правая группа иконок + бейдж
        actions: [
          _NavIcon(
            icon: CupertinoIcons.bubble_left_bubble_right,
            onPressed: () {
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const ChatScreen()),
              );
            },
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _NavIcon(
                icon: CupertinoIcons.bell,
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NotificationsScreen()),
                  );
                  setState(() {
                    _unreadCount = 0;
                  });
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: _Badge(count: _unreadCount),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: FutureBuilder<List<Activity>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ошибка: ${snap.error}'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          setState(() => _future = _loadActivities()),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }

          final items = snap.data ?? const <Activity>[];

          if (items.isEmpty) {
            return const Center(child: Text('Пока в ленте пусто'));
          }

          // ✅ ленивый список с «окном» под рекомендации после первого элемента
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: kToolbarH + 38, bottom: 12),
            itemCount: items.length + 1, // +1 — окно под рекомендации
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            addSemanticIndexes: false,
            itemBuilder: (context, i) {
              if (i == 0) {
                final first = _buildFeedItem(context, items[0]);
                return Column(
                  children: [
                    first,
                    const SizedBox(height: 16),
                    const RecommendedBlock(),
                    const SizedBox(height: 16),
                  ],
                );
              }

              final idx = i; // из-за окна индексы совпадают
              if (idx >= items.length) return const SizedBox.shrink();

              final item = _buildFeedItem(context, items[idx]);
              return Column(children: [item, const SizedBox(height: 16)]);
            },
          );
        },
      ),
    );
  }

  /// Возвращает нужную карточку для элемента ленты:
  /// пост → карточка поста; тренировка → ActivityBlock.
  Widget _buildFeedItem(BuildContext context, Activity a) {
    if (a.type == 'post') {
      return _buildPostCard(context, a);
    }

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild, // не перехватываем тапы детей
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => ActivityDescriptionPage(
              activity: a,
              currentUserId: widget.userId,
            ),
          ),
        );
      },
      child: ActivityBlock(activity: a, currentUserId: widget.userId),
    );
  }

  Widget _buildPostCard(BuildContext context, Activity a) {
    if (a.type != 'post') return const SizedBox.shrink();

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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    a.userAvatar,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.userName,
                        style: AppTextStyles.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        a.postDateText,
                        style: AppTextStyles.date,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(CupertinoIcons.ellipsis),
                ),
              ],
            ),
          ),

          // ✅ дешёвое масштабирование и правильный cacheWidth
          SizedBox(
            height: 300,
            width: double.infinity,
            child: PostMediaCarousel(
              imageUrls: a.mediaImages, // массив полных URL картинок
              videoUrls: a.mediaVideos, // массив полных URL видео
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(a.postContent),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _PostLikeBar(post: a, currentUserId: widget.userId),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    showCupertinoModalBottomSheet(
                      context: context,
                      builder: (context) => CommentsBottomSheet(
                        itemType: 'post',
                        itemId: a.id,
                        currentUserId: widget.userId,
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.chat_bubble,
                        size: 20,
                        color: AppColors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(a.comments.toString()),
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

/// Единый вид для иконок в AppBar — размер 22, tap-target 44×44
class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kAppBarTapTarget,
      height: kAppBarTapTarget,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: kAppBarTapTarget,
          minHeight: kAppBarTapTarget,
        ),
        icon: Icon(icon, size: kAppBarIconSize),
        splashRadius: 22,
      ),
    );
  }
}

/// Компактный бейдж для колокольчика
class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final String text = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          height: 1,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Лайк-бар для поста. Ходит в тот же API, но с type='post'
class _PostLikeBar extends StatefulWidget {
  final Activity post;
  final int currentUserId;

  const _PostLikeBar({required this.post, required this.currentUserId});

  @override
  State<_PostLikeBar> createState() => _PostLikeBarState();
}

class _PostLikeBarState extends State<_PostLikeBar>
    with SingleTickerProviderStateMixin {
  bool isLiked = false;
  int likesCount = 0;
  bool _busy = false;

  late AnimationController _likeController;
  late Animation<double> _likeAnimation;

  // тот же эндпойнт, что и для активностей
  static const String _likeEndpoint =
      'http://api.paceup.ru/activity_likes_toggle.php';

  @override
  void initState() {
    super.initState();
    isLiked = widget.post.islike; // старт из модели
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

  Future<void> _onTap() async {
    if (_busy) return;

    // оптимистичное обновление
    setState(() {
      _busy = true;
      isLiked = !isLiked;
      likesCount += isLiked ? 1 : -1;
    });
    _likeController.forward(from: 0);

    final ok = await _sendLike(
      activityId: widget.post.id, // id поста
      userId: widget.currentUserId,
      isLikedNow: isLiked,
      type: 'post',
    );

    if (!ok && mounted) {
      // откат при ошибке
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
    required String type, // 'activity' | 'post'
  }) async {
    final uri = Uri.parse(_likeEndpoint);
    try {
      final res = await http
          .post(
            uri,
            // form-urlencoded (сервер уже это принимает)
            body: jsonEncode({
              'userId': '$userId',
              'activityId': '$activityId', // одно имя для обоих типов
              'type': type, // <-- добавили тип
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

class PostMediaCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final List<String> videoUrls;

  const PostMediaCarousel({
    super.key,
    required this.imageUrls,
    required this.videoUrls,
  });

  @override
  State<PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<PostMediaCarousel> {
  late final PageController _pc;
  int _index = 0;

  static const _dotsBottom = 10.0;
  static const _dotsPad = EdgeInsets.symmetric(horizontal: 8, vertical: 4);

  // Можно заменить на свою картинку-заглушку для превью видео
  static const _videoPlaceholder =
      'http://uploads.paceup.ru/defaults/video_placeholder.jpg';

  @override
  void initState() {
    super.initState();
    _pc = PageController();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // общий список: сначала картинки, потом видео
    final total = widget.imageUrls.length + widget.videoUrls.length;
    if (total == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // переносим твою оптимизацию cacheWidth внутрь каждого слайда
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final cacheWidth = (constraints.maxWidth * dpr).round();

        return Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pc,
              itemCount: total,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final isImage = i < widget.imageUrls.length;
                if (isImage) {
                  final url = widget.imageUrls[i];
                  return Image.network(
                    url,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    cacheWidth: cacheWidth,
                    gaplessPlayback: true,
                  );
                } else {
                  final vIndex = i - widget.imageUrls.length;
                  final url = widget.videoUrls[vIndex];
                  return _buildVideoPreview(url);
                }
              },
            ),

            // точки-индикаторы поверх, чтобы итоговая высота оставалась 300
            Positioned(
              bottom: _dotsBottom,
              left: 0,
              right: 0,
              child: _buildDots(total),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVideoPreview(String url) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // превью (плейсхолдер) для видео
        Image.network(_videoPlaceholder, fit: BoxFit.cover),
        Container(color: const Color(0x33000000)), // лёгкий затемняющий слой
        const Center(
          child: Icon(CupertinoIcons.play_circle_fill, size: 64, color: Color(0xFFFFFFFF)),
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // TODO: открыть экран плеера, проиграть `url`
                // Navigator.push(... VideoPlayerScreen(url: url));
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDots(int total) {
    if (total <= 1) return const SizedBox.shrink();
    return Center(
      child: Container(
        padding: _dotsPad,
        decoration: BoxDecoration(
          color: const Color(0x33000000), // полупрозрачный чип под точки
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(total, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 16 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: active ? AppColors.secondary : const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ),
    );
  }
}
