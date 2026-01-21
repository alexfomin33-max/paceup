import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/user_photos_provider.dart';

/// Вкладка с фотографиями пользователя
///
/// Отображает все фотографии из активностей и постов пользователя,
/// отсортированные по дате создания (свежие сверху)
class PhotosTab extends ConsumerStatefulWidget {
  /// ID пользователя, чьи фотографии нужно отобразить
  final int userId;
  const PhotosTab({super.key, required this.userId});

  @override
  ConsumerState<PhotosTab> createState() => _PhotosTabState();
}

class _PhotosTabState extends ConsumerState<PhotosTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _openGallery(int index, List<String> photoUrls) {
    // rootNavigator: true — галерея поверх bottom nav (как экран обрезки)
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: AppColors.scrim40,
        pageBuilder: (_, _, _) => _FullscreenGallery(
          initialIndex: index,
          photoUrls: photoUrls,
          userId: widget.userId,
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // ──────────────── Получаем состояние фотографий из провайдера ────────────────
    final photosState = ref.watch(userPhotosProvider(widget.userId));

    // ──────────────── Состояние загрузки ────────────────
    if (photosState.isLoading && photosState.photos.isEmpty) {
      return const Center(child: CupertinoActivityIndicator(radius: 10));
    }

    // ──────────────── Состояние ошибки ────────────────
    if (photosState.error != null && photosState.photos.isEmpty) {
      return CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    photosState.error ?? 'Ошибка загрузки фотографий',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: AppColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(userPhotosProvider(widget.userId).notifier)
                          .refresh();
                    },
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final photos = photosState.photos;
    final photoUrls = photos.map((p) => p.url).toList();

    // ──────────────── Пустое состояние ────────────────
    if (photos.isEmpty && !photosState.isLoading) {
      return CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'Нет фотографий',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: AppColors.getTextSecondaryColor(context),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ──────────────── Сетка фотографий ────────────────
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      cacheExtent: 600, // подгружаем сетку чуть раньше
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 3)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 колонки
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
              childAspectRatio: 1.0, // квадратные превью
            ),
            itemCount: photos.length,
            itemBuilder: (context, i) {
              final photo = photos[i];
              return GestureDetector(
                onTap: () => _openGallery(i, photoUrls),
                child: Hero(
                  tag: 'photo-${widget.userId}-$i-${photo.url}',
                  flightShuttleBuilder:
                      (
                        BuildContext flightContext,
                        Animation<double> animation,
                        HeroFlightDirection flightDirection,
                        BuildContext fromHeroContext,
                        BuildContext toHeroContext,
                      ) {
                        // Берём виджет-ребёнок у целевого Hero
                        final Hero toHero = toHeroContext.widget as Hero;
                        return toHero.child;
                      },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final dpr = MediaQuery.of(context).devicePixelRatio;

                      // ширина колонки = (ширина экрана - боковые паддинги 8*2 - два промежутка 6*2) / 3
                      final screenW = MediaQuery.of(context).size.width;
                      final columns = 3;
                      const sidePadding = 8.0;
                      const spacing = 6.0;
                      final cellW =
                          (screenW -
                              sidePadding * 2 -
                              spacing * (columns - 1)) /
                          columns;

                      final cacheWidth = (cellW * dpr).round();

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: CachedNetworkImage(
                          imageUrl: photo.url,
                          fit: BoxFit.cover,
                          memCacheWidth: cacheWidth,
                          filterQuality: FilterQuality.low,
                          placeholder: (context, url) => Container(
                            color: AppColors.getBackgroundColor(context),
                            child: Center(
                              child: CupertinoActivityIndicator(
                                radius: 10,
                                color: AppColors.getIconSecondaryColor(context),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.getBackgroundColor(context),
                            child: Icon(
                              CupertinoIcons.photo,
                              color: AppColors.getIconSecondaryColor(context),
                              size: 32,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
      ],
    );
  }
}

/// Полноэкранная галерея с перелистыванием, Hero и зумом
class _FullscreenGallery extends StatefulWidget {
  final int initialIndex;
  final List<String> photoUrls;
  final int userId;
  const _FullscreenGallery({
    required this.initialIndex,
    required this.photoUrls,
    required this.userId,
  });

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.textPrimary, // чисто чёрный фон
      body: Stack(
        children: [
          // Свайп между фотографиями
          PageView.builder(
            controller: _controller,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.photoUrls.length,
            itemBuilder: (_, i) {
              final photoUrl = widget.photoUrls[i];
              final isInitial = i == widget.initialIndex;

              // Для корректного HERO при зуме — свой InteractiveViewer на каждый слайд
              // Hero используется только для начального изображения
              // Тег должен совпадать с тегом в сетке: 'photo-${userId}-${initialIndex}-${photoUrl}'
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close, // закрытие одиночным тапом
                child: Center(
                  child: isInitial
                      ? Hero(
                          tag:
                              'photo-$widget.userId-$widget.initialIndex-$photoUrl',
                          child: _ZoomableImage(photoUrl: photoUrl),
                        )
                      : _ZoomableImage(photoUrl: photoUrl),
                ),
              );
            },
          ),

          // Верхняя панель: кнопка закрыть и счётчик
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  _CircleIconButton(icon: Icons.close, onTap: _close),
                  const Spacer(),
                  _CounterBadge(
                    text: '${_index + 1}/${widget.photoUrls.length}',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка в кружке (полупрозрачная на чёрном фоне)
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Icon(icon, size: 20, color: AppColors.surface),
      ),
    );
  }
}

/// Небольшой бейдж-счётчик вверху
class _CounterBadge extends StatelessWidget {
  final String text;
  const _CounterBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: AppColors.surface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Картинка с поддержкой pinch-to-zoom и перетаскиванием
class _ZoomableImage extends StatefulWidget {
  final String photoUrl;
  const _ZoomableImage({required this.photoUrl});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 1.0,
      maxScale: 4.0,
      panEnabled: true,
      scaleEnabled: true,
      child: CachedNetworkImage(
        imageUrl: widget.photoUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => Container(
          color: AppColors.getBackgroundColor(context),
          child: Center(
            child: CupertinoActivityIndicator(
              radius: 10,
              color: AppColors.getIconSecondaryColor(context),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: AppColors.getBackgroundColor(context),
          child: Center(
            child: Icon(
              CupertinoIcons.photo,
              color: AppColors.getIconSecondaryColor(context),
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
