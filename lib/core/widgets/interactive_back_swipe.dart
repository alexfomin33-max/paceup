import 'package:flutter/material.dart';

/// Обёртка над экраном. Свайп-назад отключён — всегда отображается только [child].
/// Параметры [enabled], [completeFraction], [completeVelocity], [onlyWhenCanPop]
/// сохранены для совместимости и не используются.
class InteractiveBackSwipe extends StatelessWidget {
  const InteractiveBackSwipe({
    super.key,
    required this.child,
    this.enabled = true,
    this.completeFraction = 0.33,
    this.completeVelocity = 900.0,
    this.onlyWhenCanPop = true,
  });

  final Widget child;
  final bool enabled;
  final double completeFraction;
  final double completeVelocity;
  final bool onlyWhenCanPop;

  @override
  Widget build(BuildContext context) => child;
}
