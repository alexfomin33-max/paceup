// lib/widgets/image_gallery.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';

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
    // Делаем прозрачный barrier, чтобы управлять затемнением сами и анимировать его.
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) {
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

class _FullscreenGalleryState extends State<_FullscreenGallery>
    with SingleTickerProviderStateMixin {
  late final PageController _controller; // управляет перелистыванием
  late int _index; // текущая страница

  // Ключ для измерения области ТЕКУЩЕГО изображения (чтобы понимать, куда тапнули)
  final GlobalKey _imageKey = GlobalKey();

  // База и текущее значение прозрачности фона (затемнение)
  static const double _backdropBaseOpacity = 0.60;
  double _backdropOpacity = _backdropBaseOpacity;

  // Для жеста «свайп вниз для закрытия»
  double _dragDy = 0;

  // Анимация возврата затемнения/позиции, если не закрыли
  late final AnimationController _restoreController;

  @override
  void initState() {
    super.initState();
    // Страхуемся от выхода за границы
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _index);

    _restoreController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 160),
        )..addListener(() {
          setState(() {
            // во время отката поднимаем контент обратно и восстанавливаем затемнение
            _backdropOpacity =
                _backdropBaseOpacity * (1 - _restoreController.value) +
                _backdropOpacity * _restoreController.value;
            _dragDy = _dragDy * (1 - _restoreController.value);
          });
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    _restoreController.dispose();
    super.dispose();
  }

  void _maybeCloseOnOutsideTap(TapUpDetails details) {
    final tapPos = details.globalPosition;
    final renderObj =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderObj != null) {
      final topLeft = renderObj.localToGlobal(Offset.zero);
      final rect = Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        renderObj.size.width,
        renderObj.size.height,
      );
      if (!rect.contains(tapPos)) {
        Navigator.of(context).pop();
      }
    } else {
      // fallback: если не смогли измерить — закрываем по тапу
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;

    // Нормируем протяжку вниз (вверх не учитываем)
    final double dragDown = _dragDy > 0 ? _dragDy : 0;
    // Насколько «сильно» тянем, 0..1 (после ~240px считаем максимум)
    final double t = (dragDown / 240).clamp(0.0, 1.0);
    // Прозрачность фона уменьшается при протягивании (проседание затемнения)
    final double currentBackdropOpacity = (_backdropBaseOpacity * (1 - t))
        .clamp(0.0, 1.0);

    // Лёгкий сдвиг контента вниз при протягивании
    final double contentShift = dragDown * 0.15; // мягкий коэффициент

    return Material(
      color: Colors.transparent, // фон прозрачен (затемнение рисуем сами)
      child: GestureDetector(
        // ───── Свайп вниз для закрытия ─────
        onVerticalDragStart: (_) {
          _restoreController.stop();
          _dragDy = 0;
          // фиксируем текущее как старт для плавного восстановления
          _backdropOpacity = currentBackdropOpacity;
        },
        onVerticalDragUpdate: (details) {
          setState(() {
            _dragDy += details.delta.dy;
            // обновляем текущую оценку затемнения в процессе
            final dragDownNow = _dragDy > 0 ? _dragDy : 0;
            final tNow = (dragDownNow / 240).clamp(0.0, 1.0);
            _backdropOpacity = (_backdropBaseOpacity * (1 - tNow)).clamp(
              0.0,
              1.0,
            );
          });
        },
        onVerticalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          final shouldClose = dragDown > 120 || v > 900;
          if (shouldClose) {
            Navigator.of(context).pop();
            return;
          }
          // иначе — плавно возвращаем состояние
          _animateRestore();
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // ───── Наш анимируемый фон-затемнение ─────
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  color: Colors.black.withValues(alpha: currentBackdropOpacity),
                ),
              ),
            ),

            // ───── Контент: перелистываем картинки горизонтальными свайпами ─────
            Transform.translate(
              offset: Offset(0, contentShift),
              child: PageView.builder(
                controller: _controller,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final isCurrent = i == _index;

                  return Center(
                    // Hero — «красивый полёт» превью ↔ полноэкранная
                    child: Hero(
                      tag: Object.hash(widget.heroGroup ?? images, i),
                      // InteractiveViewer — зум и перетаскивание
                      child: InteractiveViewer(
                        maxScale: 5,
                        child: Container(
                          // ключ только у текущего, чтобы измерения были корректными
                          key: isCurrent ? _imageKey : null,
                          child: Image.asset(
                            images[i],
                            fit: BoxFit.contain, // показываем целиком
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ───── Ловец тапа ВНЕ изображения — поверх PageView ─────
            // Не мешает жестам зума/свайпов, реагирует только на одиночный тап.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: _maybeCloseOnOutsideTap,
              ),
            ),

            // ───── Кнопка закрытия (крестик) — в правом верхнем углу ─────
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 28,
                  color: AppColors.getSurfaceColor(context),
                ),
                splashRadius: 24,
              ),
            ),

            // ───── Индикатор «текущая / всего» ─────
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
                      color: AppColors.scrim40,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: Text(
                      '${_index + 1} / ${images.length}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.getSurfaceColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _animateRestore() {
    // Запускаем «возврат» к исходному состоянию (поднимаем контент, возвращаем затемнение)
    final startOpacity = _backdropOpacity;
    final startDrag = _dragDy;
    _restoreController
      ..reset()
      ..addListener(() {
        // Линейный интерполяционный откат
        final t = _restoreController.value;
        setState(() {
          _backdropOpacity =
              startOpacity + (_backdropBaseOpacity - startOpacity) * t;
          _dragDy = startDrag * (1 - t);
        });
      })
      ..forward();
  }
}
