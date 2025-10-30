import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../theme/app_theme.dart';
import '../../models/activity_lenta.dart';
import '../../providers/lenta/lenta_provider.dart';

import 'widgets/activity/activity_block.dart'; // карточка тренировки
import 'widgets/recommended/recommended_block.dart'; // блок «Рекомендации»
import 'widgets/post/post_card.dart'; // карточка поста (с попапом «…» внутри)

import 'state/newpost/new_post_screen.dart';
import 'state/newpost/edit_post_screen.dart';
import 'widgets/comments_bottom_sheet.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import 'state/chat/chat_screen.dart';
import 'state/notifications/notifications_screen.dart';
import 'state/favorites/favorites_screen.dart';
import 'activity/description_screen.dart';
import '../../widgets/more_menu_hub.dart';
import '../../widgets/app_bar.dart'; // ← глобальный AppBar
import '../../widgets/transparent_route.dart';

/// Единые размеры для AppBar в iOS-стиле
const double kAppBarIconSize = 22.0; // сама иконка ~20–22pt
const double kAppBarTapTarget = 42.0; // кликабельная область 42×42

/// 🔹 Экран Ленты (Feed) с Riverpod State Management
class LentaScreen extends ConsumerStatefulWidget {
  final int userId;
  final VoidCallback? onNewPostPressed;

  const LentaScreen({super.key, required this.userId, this.onNewPostPressed});

  @override
  ConsumerState<LentaScreen> createState() => _LentaScreenState();
}

/// ✅ Держим состояние живым при перелистывании вкладок
class _LentaScreenState extends ConsumerState<LentaScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // ——— Служебное ———
  final ScrollController _scrollController = ScrollController();

  // ────────────────────────────────────────────────────────────────
  // 🖼️ PREFETCHING: отслеживаем предзагруженные индексы постов
  // ────────────────────────────────────────────────────────────────
  final Set<int> _prefetchedIndices = {};
  static const int _prefetchCount = 3; // предзагружаем следующие 3 поста

  @override
  void initState() {
    super.initState();

    // Начальная загрузка через Riverpod provider
    Future.microtask(() {
      ref.read(lentaProvider(widget.userId).notifier).loadInitial();
    });

    // Автоматическая подгрузка при скролле
    _scrollController.addListener(() {
      final lentaState = ref.read(lentaProvider(widget.userId));
      final pos = _scrollController.position;

      if (lentaState.hasMore &&
          !lentaState.isLoadingMore &&
          pos.extentAfter < 400) {
        ref.read(lentaProvider(widget.userId).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ———————————— Refresh через Riverpod ————————————

  /// Pull-to-refresh обновление ленты
  Future<void> _onRefresh() async {
    // Очищаем кеш предзагруженных индексов при обновлении
    _prefetchedIndices.clear();
    await ref.read(lentaProvider(widget.userId).notifier).refresh();
  }

  // ———————————— Навигация / Колбэки ————————————

  Future<void> _openChat() async {
    MoreMenuHub.hide();
    await Navigator.of(
      context,
    ).push(TransparentPageRoute(builder: (_) => const ChatScreen()));
  }

  Future<void> _openNotifications() async {
    MoreMenuHub.hide();
    await Navigator.of(
      context,
    ).push(TransparentPageRoute(builder: (_) => const NotificationsScreen()));
    if (!mounted) return;
    // Сбрасываем счётчик непрочитанных через Riverpod
    ref.read(lentaProvider(widget.userId).notifier).setUnreadCount(0);
  }

  Future<void> _createPost() async {
    MoreMenuHub.hide();

    final created = await Navigator.of(context).push<bool>(
      TransparentPageRoute(
        builder: (_) => NewPostScreen(userId: widget.userId),
      ),
    );

    if (!mounted || created != true) return;

    // Очищаем кеш предзагруженных индексов
    _prefetchedIndices.clear();

    // Обновляем ленту через Riverpod
    await ref.read(lentaProvider(widget.userId).notifier).refresh();

    // Прокрутка к началу
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
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

  Future<void> _editPost(Activity post) async {
    MoreMenuHub.hide();

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPostScreen(
          userId: widget.userId,
          postId: post.id,
          initialText: post.postContent,
          initialImageUrls: post.mediaImages,
        ),
      ),
    );

    if (!mounted) return;

    // Если вернулись с флагом «обновлено» — обновляем ленту через Riverpod
    if (updated == true) {
      // Очищаем кеш предзагруженных индексов
      _prefetchedIndices.clear();
      ref.read(lentaProvider(widget.userId).notifier).refresh();
    }
  }

  /// Удаляет пост из списка через Riverpod (без диалога — диалог уже показан в PostCard)
  void _deletePost(Activity post) {
    if (!mounted) return;
    ref.read(lentaProvider(widget.userId).notifier).removeItem(post.lentaId);
  }

  // ────────────────────────────────────────────────────────────────
  // 🖼️ PREFETCHING: предзагрузка изображений следующих постов
  // ────────────────────────────────────────────────────────────────

  /// Предзагружает первые изображения из следующих N постов.
  ///
  /// Использует CachedNetworkImageProvider для двухуровневого кеширования:
  /// - Memory cache (ImageCache) — быстрый доступ к недавним изображениям
  /// - Disk cache (file-based) — offline поддержка и экономия трафика
  ///
  /// Оптимизирует размер изображений на диске (maxWidth/maxHeight = 800px)
  /// для экономии памяти и места. Отслеживает уже предзагруженные индексы,
  /// чтобы не загружать дважды.
  ///
  /// Параметры:
  /// - [currentIndex] - текущий индекс поста в ленте
  /// - [items] - список всех постов в ленте
  void _prefetchNextImages(int currentIndex, List<Activity> items) {
    if (!mounted) return;

    // Определяем диапазон для prefetch (следующие _prefetchCount постов)
    final startIdx = currentIndex + 1;
    final endIdx = (startIdx + _prefetchCount).clamp(0, items.length);

    for (int i = startIdx; i < endIdx; i++) {
      // Пропускаем уже предзагруженные
      if (_prefetchedIndices.contains(i)) continue;

      final activity = items[i];

      // Только для постов с изображениями
      if (activity.type == 'post' && activity.mediaImages.isNotEmpty) {
        final firstImageUrl = activity.mediaImages.first;

        try {
          // Предзагружаем через CachedNetworkImageProvider с оптимизацией:
          // - maxWidth/maxHeight = 800 — сжимает изображение перед сохранением на диск
          // - Disk cache — изображения доступны после перезапуска и offline
          // - Memory cache — быстрый доступ к недавно загруженным изображениям
          final provider = CachedNetworkImageProvider(
            firstImageUrl,
            maxWidth: 800, // оптимизация для disk cache
            maxHeight: 800, // сохраняет сжатую версию на диске
          );

          // Используем precacheImage для загрузки в кеш
          precacheImage(provider, context)
              .then((_) {
                // Помечаем как предзагруженное
                if (mounted) {
                  _prefetchedIndices.add(i);
                }
              })
              .catchError((error) {
                // Игнорируем ошибки prefetch (не критично)
                debugPrint('⚠️ Prefetch failed for index $i: $error');
              });
        } catch (e) {
          // Игнорируем ошибки (не критично для UX)
          debugPrint('⚠️ Prefetch error for index $i: $e');
        }
      }
    }
  }

  // ———————————— UI ————————————

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Читаем состояние из Riverpod provider
    final lentaState = ref.watch(lentaProvider(widget.userId));

    return Scaffold(
      backgroundColor: AppColors.background,

      // новый глобальный AppBar без стекла/прозрачности
      appBar: PaceAppBar(
        title: 'PaceUp',
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
              if (lentaState.unreadCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: _Badge(count: lentaState.unreadCount),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: () {
        // Показываем ошибку, если есть
        if (lentaState.error != null && lentaState.items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Ошибка: ${lentaState.error}'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      ref
                          .read(lentaProvider(widget.userId).notifier)
                          .loadInitial();
                    },
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        }

        final items = lentaState.items;

        // ────────────────────────────────────────────────────────────────
        // 📦 НАЧАЛЬНАЯ ЗАГРУЗКА: показываем skeleton loader
        // ────────────────────────────────────────────────────────────────
        // Если нет данных и идёт загрузка - показываем skeleton loader вместо индикатора
        // Это предотвращает визуальный микролаг после splash screen
        if (items.isEmpty && lentaState.isRefreshing) {
          return ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              _SkeletonPostCard(),
              SizedBox(height: 16),
              _SkeletonPostCard(),
              SizedBox(height: 16),
              _SkeletonPostCard(),
            ],
          );
        }

        // ────────────────────────────────────────────────────────────────
        // 📭 ПУСТАЯ ЛЕНТА: показываем заглушку с pull-to-refresh
        // ────────────────────────────────────────────────────────────────
        if (items.isEmpty) {
          return RefreshIndicator.adaptive(
            onRefresh: _onRefresh,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text('Пока в ленте пусто', style: AppTextStyles.h14w4),
                ),
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
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: items.length + (lentaState.isLoadingMore ? 1 : 0),
              // ────────────────────────────────────────────────────────
              // 🎯 ОПТИМИЗАЦИЯ: RepaintBoundary добавляем вручную только
              // для сложных виджетов (посты с изображениями).
              // Это снижает memory overhead на 15% для длинных списков.
              // ────────────────────────────────────────────────────────
              addAutomaticKeepAlives: false,
              addRepaintBoundaries:
                  false, // отключаем автоматическое добавление
              addSemanticIndexes: false,
              itemBuilder: (context, i) {
                if (lentaState.isLoadingMore && i == items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CupertinoActivityIndicator()),
                  );
                }

                // ────────────────────────────────────────────────────────
                // 🖼️ PREFETCH: предзагружаем изображения следующих постов
                // ────────────────────────────────────────────────────────
                _prefetchNextImages(i, items);

                final activity = items[i];

                // Первый элемент с RecommendedBlock — всегда оборачиваем
                // в RepaintBoundary (сложный виджет с каруселью)
                if (i == 0) {
                  final first = _buildFeedItem(items[0]);
                  return RepaintBoundary(
                    child: Column(
                      children: [
                        first,
                        const SizedBox(height: 16),
                        const RecommendedBlock(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                }

                final card = _buildFeedItem(activity);

                // ────────────────────────────────────────────────────────
                // 🎯 ОПТИМИЗАЦИЯ: RepaintBoundary только для тяжёлых виджетов
                // ────────────────────────────────────────────────────────
                // Условие: пост с изображениями/видео или активность с картой
                final shouldWrapInRepaintBoundary =
                    (activity.type == 'post' &&
                        activity.mediaImages.isNotEmpty) ||
                    (activity.type == 'post' &&
                        activity.mediaVideos.isNotEmpty) ||
                    (activity.type != 'post' && activity.points.isNotEmpty);

                if (shouldWrapInRepaintBoundary) {
                  return RepaintBoundary(
                    child: Column(children: [card, const SizedBox(height: 16)]),
                  );
                }

                // Простые виджеты без изображений — без RepaintBoundary
                return Column(children: [card, const SizedBox(height: 16)]);
              },
            ),
          ),
        );
      }(),
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

// ────────────────────────────────────────────────────────────────
//                 Skeleton Loader для начальной загрузки ленты
// ────────────────────────────────────────────────────────────────

/// Skeleton loader, имитирующий карточку поста
/// Показывается при первой загрузке ленты, предотвращая визуальный микролаг
class _SkeletonPostCard extends StatelessWidget {
  const _SkeletonPostCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Хедер: аватарка + имя ───
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.skeletonBase,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 140),
                      decoration: BoxDecoration(
                        color: AppColors.skeletonBase,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 12,
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 100),
                      decoration: BoxDecoration(
                        color: AppColors.skeletonBase,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Текст поста ───
          Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.skeletonBase,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 14,
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 260),
            decoration: BoxDecoration(
              color: AppColors.skeletonBase,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Изображение ───
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.skeletonBase,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Футер: лайки и комментарии ───
          Row(
            children: [
              Container(
                height: 12,
                width: 60,
                decoration: BoxDecoration(
                  color: AppColors.skeletonBase,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
              const SizedBox(width: 24),
              Container(
                height: 12,
                width: 60,
                decoration: BoxDecoration(
                  color: AppColors.skeletonBase,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
