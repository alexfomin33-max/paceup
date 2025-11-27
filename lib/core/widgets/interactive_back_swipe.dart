import 'package:flutter/material.dart';

/// Интерактивный full-screen свайп-назад:
/// тянем child вправо; на отпускании либо докатываем и pop(), либо возвращаем.
class InteractiveBackSwipe extends StatefulWidget {
  const InteractiveBackSwipe({
    super.key,
    required this.child,
    this.enabled = true,
    this.completeFraction = 0.33, // порог ~1/3 ширины
    this.completeVelocity = 900.0, // пикс/сек — «быстрый» свайп
    this.onlyWhenCanPop = true, // выключен на корневом экране
  });

  final Widget child;
  final bool enabled;
  final double completeFraction;
  final double completeVelocity;
  final bool onlyWhenCanPop;

  @override
  State<InteractiveBackSwipe> createState() => _InteractiveBackSwipeState();
}

class _InteractiveBackSwipeState extends State<InteractiveBackSwipe>
    with SingleTickerProviderStateMixin {
  double _drag = 0.0;

  late final AnimationController _settle;
  Animation<double>? _anim; // актуальная анимация от begin к target
  VoidCallback? _animListener; // чтобы корректно отписываться

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    // аккуратно снимаем слушателя и гасим контроллер
    if (_animListener != null && _anim != null) {
      _anim!.removeListener(_animListener!);
      _animListener = null;
    }
    _settle.dispose();
    super.dispose();
  }

  void _animateTo(double target, double width) {
    final begin = _drag.clamp(0.0, width);
    final distance = target - begin;

    // Снять предыдущего слушателя (если был)
    if (_animListener != null && _anim != null) {
      _anim!.removeListener(_animListener!);
      _animListener = null;
    }

    _settle
      ..stop()
      ..value = 0.0;

    _anim = Tween<double>(
      begin: begin,
      end: target,
    ).animate(CurvedAnimation(parent: _settle, curve: Curves.easeOut));

    _animListener = () => setState(() {
      // анимируем саму величину сдвига
      _drag = begin + distance * _settle.value;
    });
    _anim!.addListener(_animListener!);

    _settle.forward().whenComplete(() {
      // Чистим слушателя по завершении
      if (_animListener != null && _anim != null) {
        _anim!.removeListener(_animListener!);
        _animListener = null;
      }
      // Полностью уехали к правому краю — закрываем экран
      if (target >= width * 0.999 && mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    if (widget.onlyWhenCanPop && !Navigator.canPop(context)) {
      return widget.child;
    }

    final width = MediaQuery.of(context).size.width;
    final progress = (_drag / width).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _settle.stop(),
      onHorizontalDragUpdate: (details) {
        final next = (_drag + details.delta.dx).clamp(0.0, width);
        if (next != _drag) setState(() => _drag = next);
      },
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0.0;
        final fastEnough = v > widget.completeVelocity;
        final farEnough = _drag > width * widget.completeFraction;
        if (fastEnough || farEnough) {
          _animateTo(width, width);
        } else {
          _animateTo(0, width);
        }
      },
      child: Stack(
        children: [
          // Сдвигаем текущий экран вправо
          Transform.translate(
            offset: Offset(_drag, 0),
            child: DecoratedBox(
              // легкая тень слева — приятнее глазу
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.08 * (1.0 - progress),
                    ),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
