import 'package:flutter/material.dart';

/// Интерактивный full-screen свайп-назад.
/// Перетаскивает child вправо пальцем. На отпускании:
///  • если прошли порог/скорость — докатывает до края и делает pop();
///  • иначе — возвращает назад.
///
/// Замечания:
///  • Работает поверх обычных Material/Cupertino роутов.
///  • Может конфликтовать с горизонтальными скроллами внутри экрана.
///    Если на экране много горизонтального свайпа — ставьте enabled: false.
class InteractiveBackSwipe extends StatefulWidget {
  const InteractiveBackSwipe({
    super.key,
    required this.child,
    this.enabled = true,
    this.completeFraction = 0.33, // порог ~1/3 экрана
    this.completeVelocity = 900.0, // пикс/сек: «быстрый» свайп
    this.onlyWhenCanPop = true, // не активен на корневом экране
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
  NavigatorState? _navigator;        // кэш предка
  VoidCallback? _tickListener;       // чтобы не накапливать слушатели

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // сохраняем ссылку, чтобы потом не лезть в .of(context) после деактивации
    _navigator = Navigator.maybeOf(context);
  }

  @override
  void dispose() {
    if (_tickListener != null) {
      _settle.removeListener(_tickListener!);
      _tickListener = null;
    }
    _settle.dispose();
    super.dispose();
  }

  void _animateTo(double target, double width) {
    final begin = _drag.clamp(0.0, width);
    final distance = (target - begin);

    _settle
      ..stop()
      ..value = 0.0;

    // скидываем прежний слушатель, если был
    if (_tickListener != null) {
      _settle.removeListener(_tickListener!);
      _tickListener = null;
    }

    final anim = CurvedAnimation(parent: _settle, curve: Curves.easeOut);
    _tickListener = () {
      if (!mounted) return;
      setState(() => _drag = begin + distance * anim.value);
    };
    _settle.addListener(_tickListener!);

    _settle.forward().whenCompleteOrCancel(() {
      // почистим слушатель
      if (_tickListener != null) {
        _settle.removeListener(_tickListener!);
        _tickListener = null;
      }
      // докатились до края — закрываем экран без .of(context)
      if (target >= width * 0.999) {
        _navigator?.maybePop();
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
      onHorizontalDragUpdate: (d) {
        final next = (_drag + d.delta.dx).clamp(0.0, width);
        setState(() => _drag = next);
      },
      onHorizontalDragEnd: (d) {
        final fastEnough = (d.primaryVelocity ?? 0) > widget.completeVelocity;
        final farEnough = _drag > width * widget.completeFraction;
        if (fastEnough || farEnough) {
          _animateTo(width, width);
        } else {
          _animateTo(0, width);
        }
      },
      child: Stack(
        children: [
          Transform.translate(
            offset: Offset(_drag, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08 * (1.0 - progress)),
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
