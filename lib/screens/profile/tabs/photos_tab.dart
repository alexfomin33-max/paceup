import 'package:flutter/material.dart';

class PhotosTab extends StatefulWidget {
  const PhotosTab({super.key});
  @override
  State<PhotosTab> createState() => _PhotosTabState();
}

class _PhotosTabState extends State<PhotosTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const _assets = <String>[
    'assets/foto_1.png',
    'assets/foto_2.png',
    'assets/foto_3.png',
    'assets/foto_4.png',
    'assets/foto_5.png',
    'assets/foto_6.png',
    'assets/foto_7.png',
    'assets/foto_8.png',
    'assets/foto_9.png',
    'assets/foto_10.png',
    'assets/foto_11.png',
    'assets/foto_12.png',
    // новые 3 фото ниже
    'assets/foto_13.png',
    'assets/foto_14.png',
    'assets/foto_15.png',
  ];

  void _openGallery(int index) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black.withValues(alpha: 0.98),
        pageBuilder: (_, __, ___) =>
            _FullscreenGallery(initialIndex: index, assets: _assets),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 колонки
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.0, // квадратные превью
            ),
            itemCount: _assets.length,
            itemBuilder: (context, i) {
              final path = _assets[i];
              return GestureDetector(
                onTap: () => _openGallery(i),
                child: Hero(
                  tag: 'photo-$i',
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(path, fit: BoxFit.cover),
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
  final List<String> assets;
  const _FullscreenGallery({required this.initialIndex, required this.assets});

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
      backgroundColor: Colors.black, // чисто чёрный фон
      body: Stack(
        children: [
          // Свайп между фотографиями
          PageView.builder(
            controller: _controller,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.assets.length,
            itemBuilder: (_, i) {
              final path = widget.assets[i];

              // Для корректного HERO при зуме — свой InteractiveViewer на каждый слайд
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close, // закрытие одиночным тапом
                child: Center(
                  child: Hero(
                    tag: 'photo-$i',
                    child: _ZoomableImage(path: path),
                  ),
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
                  _CounterBadge(text: '${_index + 1}/${widget.assets.length}'),
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
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
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
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Картинка с поддержкой pinch-to-zoom и перетаскиванием
class _ZoomableImage extends StatefulWidget {
  final String path;
  const _ZoomableImage({required this.path});

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
      child: Image.asset(widget.path, fit: BoxFit.contain),
    );
  }
}
