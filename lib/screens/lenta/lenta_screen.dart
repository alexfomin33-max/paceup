import 'dart:async';
import 'dart:convert';
import 'dart:ui';

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

/// Единые размеры для AppBar в iOS-стиле
const double kAppBarIconSize = 22.0; // сама иконка ~20–22pt
const double kAppBarTapTarget = 42.0; // кликабельная область 42×42
const double kToolbarH = 52.0; // высота AppBar (iOS-лайк, компактнее 56)

/// 🔹 Экран Ленты (Feed)
/// Ответственности:
/// 1) Держит состояние ленты (список, пагинация, pull-to-refresh)
/// 2) Управляет навигацией верхних кнопок (чат/уведомления/избранное/создать пост)
/// 3) Решает поведение карточек (комменты/редактирование/удаление) через колбэки
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
  final int _limit = 5; // грузим пачками по 5
  int _page = 1; // текущая страница (1-индексация)
  bool _hasMore = true; // признак «на сервере есть ещё»
  bool _isLoadingMore = false; // сейчас идёт нижняя догрузка

  // ——— Данные ленты ———
  List<Activity> _items = []; // локальный буфер элементов
  final Set<int> _seenIds = {}; // защита от дублей (по id элементов)
  int _unreadCount =
      3; // пример счётчика уведомлений (обновляется после визита в Notifications)

  // ——— Служебное ———
  final ScrollController _scrollController = ScrollController();

  /// Нормализованная точка уникальности элемента
  /// Если в модели id другой (например, `lentaId`), поменяй здесь.
  int _getId(Activity a) => a.lentaId;

  @override
  void initState() {
    super.initState();

    // Первая загрузка — «самые свежие»
    _future = _loadActivities(page: 1, limit: _limit).then((list) {
      _items = list;
      _page = 1;
      _hasMore = list.length == _limit;
      _seenIds
        ..clear()
        ..addAll(list.map(_getId));

      // Если на экране мало контента — авто-догружаем ещё одну пачку
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoLoadMore());
      return list;
    });

    // Нижняя догрузка при прокрутке
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

  // ————————————————————————————————————————————————————————————————
  //                            API
  // ————————————————————————————————————————————————————————————————

  /// Загрузка пачки элементов ленты с сервера
  Future<List<Activity>> _loadActivities({
    required int page,
    required int limit,
  }) async {
    final payload = {
      'userId': widget.userId,
      'limit': limit,
      'page': page, // если бэк понимает page
      'offset': (page - 1) * limit, // если бэк понимает offset
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

  // ————————————————————————————————————————————————————————————————
  //                        Пагинация/Refresh
  // ————————————————————————————————————————————————————————————————

  /// Догрузить следующую страницу
  Future<void> _loadNextPage() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    final nextPage = _page + 1;
    final newItems = await _loadActivities(page: nextPage, limit: _limit);

    // Отбрасываем дубли
    final unique = <Activity>[];
    for (final a in newItems) {
      final id = _getId(a);
      if (_seenIds.add(id)) unique.add(a);
    }

    if (!mounted) return;
    setState(() {
      if (unique.isEmpty) {
        // Сервер вернул уже виденные записи — считаем, что дальше пусто
        _hasMore = false;
      } else {
        _items.addAll(unique);
        _page = nextPage;
        _hasMore = unique.length == _limit; // меньше лимита — хвост
      }
      _isLoadingMore = false;
    });
  }

  /// Pull-to-refresh: полностью перезагрузить «самые свежие»
  Future<void> _onRefresh() async {
    final fresh = await _loadActivities(page: 1, limit: _limit);
    if (!mounted) return;

    setState(() {
      _items = fresh;
      _page = 1;
      _hasMore = fresh.length == _limit;
      _isLoadingMore = false; // важно сбросить флаг
      _seenIds
        ..clear()
        ..addAll(fresh.map(_getId));
      _future = Future.value(fresh);
    });

    // Если контента снова мало — авто-догружаем
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoLoadMore());
  }

  /// Если список маленький (не заполняет экран) — грузим ещё
  void _maybeAutoLoadMore() {
    if (!_hasMore || _isLoadingMore) return;
    if (!_scrollController.hasClients) return;

    final pos = _scrollController.position;
    final isShortList = pos.maxScrollExtent <= 0;
    final nearBottom = pos.extentAfter < 400;

    if (isShortList || nearBottom) _loadNextPage();
  }

  // ————————————————————————————————————————————————————————————————
  //                       Навигация / Колбэки
  // ————————————————————————————————————————————————————————————————

  /// Открыть чат
  void _openChat() {
    MoreMenuHub.hide();
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  /// Открыть уведомления
  Future<void> _openNotifications() async {
    MoreMenuHub.hide();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (!mounted) return;
    setState(() => _unreadCount = 0);
  }

  /// Создать пост
  Future<void> _createPost() async {
    MoreMenuHub.hide();
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NewPostScreen(userId: widget.userId)),
    );
    if (!mounted) return;
    if (created == true) {
      // После создания — жёсткий перезапрос «самых свежих» и сброс set'ов
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

      // Прокрутить к началу, чтобы увидеть новый пост
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
  }

  /// Открыть список «Избранное»
  void _openFavorites() {
    MoreMenuHub.hide();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
    );
  }

  /// Открыть экран описания тренировки
  void _openActivity(Activity a) {
    MoreMenuHub.hide();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) =>
            ActivityDescriptionPage(activity: a, currentUserId: widget.userId),
      ),
    );
  }

  /// Открыть комментарии (тип='post' | 'activity') в Купертино-bottom-sheet.
  /// Важно: showCupertinoModalBottomSheet живёт здесь (в экране), а не в карточке.
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

  /// Редактировать пост (заглушка: подключишь экран редактора при необходимости)
  void _editPost(Activity post) {
    // Navigator.push(context, CupertinoPageRoute(builder: (_) => EditPostScreen(postId: post.id)));
    debugPrint('Редактировать пост id=${post.id}');
  }

  bool _deleteInProgress = false; // защита от повторных кликов

  Future<void> _deletePost(Activity post) async {
    if (_deleteInProgress) return; // не даём открыть два диалога подряд
    _deleteInProgress = true;

    // Захватываем РУТовый навигатор и его контекст заранее.
    // Так мы точно не будем обращаться к "мертвому" context из поддерева карточки.
    final NavigatorState rootNav = Navigator.of(context, rootNavigator: true);
    final BuildContext dialogHost = rootNav.context;

    // Показываем диалог на rootNavigator. Внутри экшенов тоже пользуемся rootNav.pop(...)
    final bool? ok = await showCupertinoDialog<bool>(
      context: dialogHost,
      barrierDismissible: true, // по желанию
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Удалить пост?'),
        content: const Text('Действие нельзя отменить.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => rootNav.pop(false), // важно: используем rootNav
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => rootNav.pop(true), // важно: используем rootNav
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    // Диалог уже закрылся. Экран мог успеть быть демонтирован (например, пользователь ушёл назад).
    if (!mounted) {
      _deleteInProgress = false;
      return;
    }

    if (ok == true) {
      // TODO: тут вызов API удаления. После успеха — обновляем список.
      setState(() {
        _items.removeWhere((e) => e.id == post.id);
      });
    }

    _deleteInProgress = false;
  }

  // ————————————————————————————————————————————————————————————————
  //                             UI
  // ————————————————————————————————————————————————————————————————

  @override
  Widget build(BuildContext context) {
    super.build(context); // важно для keep-alive

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      extendBodyBehindAppBar: true,

      // ——— Верхняя панель ———
      appBar: AppBar(
        toolbarHeight: kToolbarH,
        // Если у вас старая версия Flutter — замените на .withOpacity(0.5)
        backgroundColor: Colors.white.withValues(alpha: 0.50),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: 96,
        shape: const Border(
          bottom: BorderSide(color: Color(0x33FFFFFF), width: 0.6),
        ),
        // стеклянное размытие
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.transparent),
          ),
        ),

        // Левая группа иконок
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

        title: const Text('Лента', style: AppTextStyles.h1),

        // Правая группа: чат + колокол с бейджем
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
              // ⚠️ Фикс: показываем реальное значение _unreadCount (раньше было «3» жестко)
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

      // ——— Тело экрана ———
      body: FutureBuilder<List<Activity>>(
        future: _future,
        builder: (context, snap) {
          // 1) Идёт начальная загрузка
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2) Ошибка начальной загрузки
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

          // 3) Берём фактические элементы из локального буфера (он актуальнее)
          final items = _items.isNotEmpty
              ? _items
              : (snap.data ?? const <Activity>[]);

          // 4) Совсем пусто — отдаём пустой список, но с pull-to-refresh
          if (items.isEmpty) {
            return RefreshIndicator.adaptive(
              onRefresh: _onRefresh,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: kToolbarH + 38, bottom: 12),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Пока в ленте пусто')),
                  SizedBox(height: 120),
                ],
              ),
            );
          }

          // 5) Основной сценарий — ленивый список, «рекомендации» после первого элемента
          return RefreshIndicator.adaptive(
            onRefresh: _onRefresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollStartNotification ||
                    n is ScrollUpdateNotification ||
                    n is OverscrollNotification ||
                    n is UserScrollNotification) {
                  MoreMenuHub.hide(); // скрыть активное меню
                }
                return false;
              },
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: kToolbarH + 38, bottom: 12),
                itemCount: items.length + (_isLoadingMore ? 1 : 0),
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                addSemanticIndexes: false,
                itemBuilder: (context, i) {
                  // «подвал» — индикатор нижней догрузки
                  if (_isLoadingMore && i == items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CupertinoActivityIndicator()),
                    );
                  }

                  // Первый элемент + блок рекомендаций — одной группой
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

                  // Обычные элементы
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

  /// Вернём нужную карточку в зависимости от типа элемента:
  ///  - post  → PostCard (вынос, с попапом «…»; комментарии открываем здесь)
  ///  - other → ActivityBlock (тренировка). Тап по карточке — в описание.
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

    // Тренировка
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: () => _openActivity(a),
      child: ActivityBlock(
        activity: a,
        currentUserId: widget.userId,
        // если добавишь onAvatarTap в ActivityBlock — сюда можно прокинуть переход в профиль
      ),
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
    // Если хочется «более iOS», можно поменять на Capsule + тонкий шрифт.
  }
}
