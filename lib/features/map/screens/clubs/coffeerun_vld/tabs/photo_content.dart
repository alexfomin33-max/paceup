import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_theme.dart';

class CoffeeRunVldPhotoContent extends StatelessWidget {
  const CoffeeRunVldPhotoContent({super.key});

  static const photos = <String>[
    'assets/coffeerun_vld_photo_1.png',
    'assets/coffeerun_vld_photo_2.png',
    'assets/coffeerun_vld_photo_3.png',
    'assets/coffeerun_vld_photo_4.png',
    'assets/coffeerun_vld_photo_5.png',
    'assets/coffeerun_vld_photo_6.png',
    'assets/coffeerun_vld_photo_7.png',
    'assets/coffeerun_vld_photo_8.png',
    'assets/coffeerun_vld_photo_9.png',
  ];

  void _openGallery(BuildContext context, int index) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: AppColors.scrim40,
        pageBuilder: (_, _, _) =>
            _FullscreenGallery(initialIndex: index, assets: photos),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Внешний отступ минимальный, как просили (tight layout)
    return ClipRRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          const columns = 3;
          const spacing = 2.0;
          final cellW =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          final dpr = MediaQuery.of(context).devicePixelRatio;
          final cacheWidth = (cellW * dpr).round();

          return GridView.builder(
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (_, i) {
              final path = photos[i];
              return GestureDetector(
                onTap: () => _openGallery(context, i),
                child: Hero(
                  tag: 'vld-photo-$i', // уникальный tag, чтобы не конфликтовать
                  flightShuttleBuilder:
                      (
                        BuildContext flightContext,
                        Animation<double> animation,
                        HeroFlightDirection flightDirection,
                        BuildContext fromHeroContext,
                        BuildContext toHeroContext,
                      ) {
                        final Hero toHero = toHeroContext.widget as Hero;
                        return toHero.child;
                      },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppRadius.sm,
                    ), // как в photos_tab
                    child: Image.asset(
                      path,
                      fit: BoxFit.cover,
                      cacheWidth: cacheWidth, // дешёвый превью-даунскейл
                      filterQuality: FilterQuality.low,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
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
  late int _index = widget.initialIndex;

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scrim90,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.assets.length,
            itemBuilder: (_, i) {
              final path = widget.assets[i];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close, // закрываем по тапу
                child: Center(
                  child: Hero(
                    tag: 'vld-photo-$i',
                    child: _ZoomableImage(path: path),
                  ),
                ),
              );
            },
          ),
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

/// Картинка с pinch-to-zoom и перетаскиванием
class _ZoomableImage extends StatefulWidget {
  final String path;
  const _ZoomableImage({required this.path});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final TransformationController _tc = TransformationController();

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _tc,
      minScale: 1.0,
      maxScale: 4.0,
      panEnabled: true,
      scaleEnabled: true,
      child: Image.asset(widget.path, fit: BoxFit.contain),
    );
  }
}
