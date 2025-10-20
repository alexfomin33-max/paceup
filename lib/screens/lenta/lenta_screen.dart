import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../theme/app_theme.dart';
import '../../models/activity_lenta.dart';

import 'widgets/activity/activity_block.dart'; // карточка тренировки
import 'widgets/recommended/recommended_block.dart'; // блок «Рекомендации»
import 'widgets/post/post_card.dart'; // карточка поста (с попапом «…» внутри)

import 'state/newpost/newpost_screen.dart';
import 'widgets/comments_bottom_sheet.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import 'state/chat/chat_screen.dart';
import 'state/notifications/notifications_screen.dart';
import 'state/favorites/favorites_screen.dart';
import 'activity/description_screen.dart';
import '../../widgets/more_menu_hub.dart';
import '../../widgets/app_bar.dart'; // ← глобальный AppBar

/// Единые размеры для AppBar в iOS-стиле
const double kAppBarIconSize = 22.0; // сама иконка ~20–22pt
const double kAppBarTapTarget = 42.0; // кликабельная область 42×42

/// 🔹 Экран Ленты (Feed)
class LentaScreen extends StatefulWidget {
  final int userId;
  final VoidCallback? onNewPostPressed;

  const LentaScreen({super.key, required this.userId, this.onNewPostPressed});

  @override
  State<LentaScreen> createState() => _LentaScreenState();
}

/// ✅ Держим состояние живым при перелистывании вкладок
class _LentaScreenState extends State<LentaScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // ——— Загрузка начального состояния ———
  late Future<List<Activity>> _future;

  // ——— Пагинация ———
  final int _limit = 5;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // ——— Данные ленты ———
  List<Activity> _items = [];
  final Set<int> _seenIds = {};
  int _unreadCount = 3;

  // ——— Служебное ———
  final ScrollController _scrollController = ScrollController();

  int _getId(Activity a) => a.lentaId;

  @override
  void initState() {
    super.initState();

    _future = _loadActivities(page: 1, limit: _limit).then((list) {
      _items = list;
      _page = 1;
      _hasMore = list.length == _limit;
      _seenIds
        ..clear()
        ..addAll(list.map(_getId));

      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoLoadMore());
      return list;
    });

    _scrollController.addListener(() {
      final pos = _scrollController.position;
      if (_hasMore && !_isLoadingMore && pos.extentAfter < 400) {
        _loadNextPage();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ————————————————— API —————————————————

  Future<List<Activity>> _loadActivities({
    required int page,
    required int limit,
  }) async {
    final payload = {
      'userId': widget.userId,
      'limit': limit,
      'page': page,
      'offset': (page - 1) * limit,
      'order': 'desc',
    };

    final res = await http.post(
      Uri.parse('http://api.paceup.ru/activities_lenta.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
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

  // ———————————— Пагинация/Refresh ————————————

  Future<void> _loadNextPage() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    final nextPage = _page + 1;
    final newItems = await _loadActivities(page: nextPage, limit: _limit);

    final unique = <Activity>[];
    for (final a in newItems) {
      final id = _getId(a);
      if (_seenIds.add(id)) unique.add(a);
    }

    if (!mounted) return;
    setState(() {
      if (unique.isEmpty) {
        _hasMore = false;
      } else {
        _items.addAll(unique);
        _page = nextPage;
        _hasMore = unique.length == _limit;
      }
      _isLoadingMore = false;
    });
  }

  Future<void> _onRefresh() async {
    final fresh = await _loadActivities(page: 1, limit: _limit);
    if (!mounted) return;

    setState(() {
      _items = fresh;
      _page = 1;
      _hasMore = fresh.length == _limit;
      _isLoadingMore = false;
      _seenIds
        ..clear()
        ..addAll(fresh.map(_getId));
      _future = Future.value(fresh);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoLoadMore());
  }

  void _maybeAutoLoadMore() {
    if (!_hasMore || _isLoadingMore) return;
    if (!_scrollController.hasClients) return;

    final pos = _scrollController.position;
    final isShortList = pos.maxScrollExtent <= 0;
    final nearBottom = pos.extentAfter < 400;

    if (isShortList || nearBottom) _loadNextPage();
  }

  // ———————————— Навигация / Колбэки ————————————

  void _openChat() {
    MoreMenuHub.hide();
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  Future<void> _openNotifications() async {
    MoreMenuHub.hide();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (!mounted) return;
    setState(() => _unreadCount = 0);
  }

  Future<void> _createPost() async {
    MoreMenuHub.hide();
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NewPostScreen(userId: widget.userId)),
    );
    if (!mounted) return;
    if (created == true) {
      setState(() {
        _future = _loadActivities(page: 1, limit: _limit).then((list) {
          _items = list;
          _page = 1;
          _hasMore = list.length == _limit;
          _isLoadingMore = false;
          _seenIds
            ..clear()
            ..addAll(list.map(_getId));
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _maybeAutoLoadMore(),
          );
          return list;
        });
      });

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _openFavorites() {
    MoreMenuHub.hide();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
    );
  }

  void _openActivity(Activity a) {
    MoreMenuHub.hide();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) =>
            ActivityDescriptionPage(activity: a, currentUserId: widget.userId),
      ),
    );
  }

  void _openComments({required String type, required int itemId}) {
    MoreMenuHub.hide();
    showCupertinoModalBottomSheet(
      context: context,
      builder: (_) => CommentsBottomSheet(
        itemType: type,
        itemId: itemId,
        currentUserId: widget.userId,
      ),
    );
  }

  void _editPost(Activity post) {
    debugPrint('Редактировать пост id=${post.id}');
  }

  bool _deleteInProgress = false;

  Future<void> _deletePost(Activity post) async {
    if (_deleteInProgress) return;
    _deleteInProgress = true;

    final NavigatorState rootNav = Navigator.of(context, rootNavigator: true);
    final BuildContext dialogHost = rootNav.context;

    final bool? ok = await showCupertinoDialog<bool>(
      context: dialogHost,
      barrierDismissible: true,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Удалить пост?'),
        content: const Text('Действие нельзя отменить.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => rootNav.pop(false),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => rootNav.pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (!mounted) {
      _deleteInProgress = false;
      return;
    }

    if (ok == true) {
      setState(() {
        _items.removeWhere((e) => e.id == post.id);
      });
    }

    _deleteInProgress = false;
  }

  // ———————————— UI ————————————

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppColors.background,

      // новый глобальный AppBar без стекла/прозрачности
      appBar: PaceAppBar(
        title: 'Лента',
        showBottomDivider: true,
        leadingWidth: 96, // две иконки слева
        // слева — избранное и «создать пост»
        leading: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Row(
            children: [
              _NavIcon(icon: CupertinoIcons.star, onPressed: _openFavorites),
              const SizedBox(width: 4),
              _NavIcon(
                icon: CupertinoIcons.add_circled,
                onPressed: _createPost,
              ),
            ],
          ),
        ),
        // справа — чат и колокол с бейджем
        actions: [
          _NavIcon(
            icon: CupertinoIcons.bubble_left_bubble_right,
            onPressed: _openChat,
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _NavIcon(
                icon: CupertinoIcons.bell,
                onPressed: _openNotifications,
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
                      onPressed: () {
                        setState(() {
                          _future = _loadActivities(page: 1, limit: _limit)
                              .then((list) {
                                _items = list;
                                _page = 1;
                                _hasMore = list.length == _limit;
                                _isLoadingMore = false;
                                _seenIds
                                  ..clear()
                                  ..addAll(list.map(_getId));
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => _maybeAutoLoadMore(),
                                );
                                return list;
                              });
                        });
                      },
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }

          final items = _items.isNotEmpty
              ? _items
              : (snap.data ?? const <Activity>[]);

          if (items.isEmpty) {
            return RefreshIndicator.adaptive(
              onRefresh: _onRefresh,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Пока в ленте пусто')),
                  SizedBox(height: 120),
                ],
              ),
            );
          }

          return RefreshIndicator.adaptive(
            onRefresh: _onRefresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollStartNotification ||
                    n is ScrollUpdateNotification ||
                    n is OverscrollNotification ||
                    n is UserScrollNotification) {
                  MoreMenuHub.hide();
                }
                return false;
              },
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                itemCount: items.length + (_isLoadingMore ? 1 : 0),
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                addSemanticIndexes: false,
                itemBuilder: (context, i) {
                  if (_isLoadingMore && i == items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CupertinoActivityIndicator()),
                    );
                  }

                  if (i == 0) {
                    final first = _buildFeedItem(items[0]);
                    return Column(
                      children: [
                        first,
                        const SizedBox(height: 16),
                        const RecommendedBlock(),
                        const SizedBox(height: 16),
                      ],
                    );
                  }

                  final card = _buildFeedItem(items[i]);
                  return Column(children: [card, const SizedBox(height: 16)]);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeedItem(Activity a) {
    if (a.type == 'post') {
      return PostCard(
        post: a,
        currentUserId: widget.userId,
        onOpenComments: () => _openComments(type: 'post', itemId: a.id),
        onEdit: () => _editPost(a),
        onDelete: () => _deletePost(a),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: () => _openActivity(a),
      child: ActivityBlock(activity: a, currentUserId: widget.userId),
    );
  }
}

// ————————————————————————————————————————————————————————————————
//                 Мелкие утилиты UI: иконка и бейдж
// ————————————————————————————————————————————————————————————————

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
    final text = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          height: 1,
          color: AppColors.surface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
