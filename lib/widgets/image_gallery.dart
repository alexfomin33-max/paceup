// lib/widgets/image_gallery.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Публичная функция — покажет диалог-галерею поверх экрана.
/// [images] — список путей к ассетам.
/// [initialIndex] — с какой картинки начать.
/// [heroGroup] — общий объект для Hero-анимации (чтобы анимация красиво «летала»).
Future<void> showImageGallery(
  BuildContext context, {
  required List<String> images,
  int initialIndex = 0,
  Object? heroGroup,
}) {
  return showGeneralDialog(
    context: context,
    barrierLabel: 'gallery',
    barrierDismissible: true, // нажал вне — закрыл
    barrierColor: Colors.black.withValues(alpha: 0.85), // затемнение фона
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) {
      return _FullscreenGallery(
        images: images,
        initialIndex: initialIndex,
        heroGroup: heroGroup,
      );
    },
  );
}

/// Внутренний виджет полноэкранной галереи.
class _FullscreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final Object? heroGroup;

  const _FullscreenGallery({
    required this.images,
    this.initialIndex = 0,
    this.heroGroup,
  });

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _controller; // управляет перелистыванием
  late int _index; // текущая страница

  @override
  void initState() {
    super.initState();
    // Страхуемся от выхода за границы
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return Material(
      color: Colors.transparent, // фон прозрачен (чтобы увидеть затемнение)
      child: Stack(
        children: [
          // Перелистываем картинки горизонтальными свайпами
          PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              return Center(
                // Hero отвечает за «красивый полёт» превью → полноэкранная и обратно
                child: Hero(
                  tag: Object.hash(widget.heroGroup ?? images, i),
                  // InteractiveViewer даёт зум и перемещение
                  child: InteractiveViewer(
                    maxScale: 5,
                    child: Image.asset(
                      images[i],
                      fit: BoxFit.contain, // показываем целиком
                    ),
                  ),
                ),
              );
            },
          ),

          // Кнопка закрытия (крестик) — в правом верхнем углу
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                CupertinoIcons.xmark_circle_fill,
                size: 28,
                color: Colors.white,
              ),
              splashRadius: 24,
            ),
          ),

          // Индикатор «текущая / всего»
          if (images.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_index + 1} / ${images.length}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
