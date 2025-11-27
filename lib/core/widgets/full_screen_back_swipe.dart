import 'package:flutter/material.dart';

/// Обёртка, которая позволяет закрывать экран свайпом вправо
/// из любой точки (а не только от кромки).
///
/// Особенности:
/// • Не делает «интерактивный» pop (как iOS-джест у кромки), просто вызывает pop()
///   по окончанию горизонтального свайпа с достаточной скоростью.
/// • Учитывает направление текста: в RTL «назад» — это свайп влево.
/// • Можно тонко настроить порог скорости, отключить, выбрать rootNavigator.
class FullScreenBackSwipe extends StatelessWidget {
  final Widget child;

  /// Включено ли поведение.
  final bool enabled;

  /// Порог скорости (px/сек). Чтобы случайные потяги не закрывали экран.
  final double velocityThreshold;

  /// Использовать корневой навигатор.
  final bool useRootNavigator;

  const FullScreenBackSwipe({
    super.key,
    required this.child,
    this.enabled = true,
    this.velocityThreshold = 200, // чуть инерции — и назад
    this.useRootNavigator = false,
  });

  void _onHorizontalDragEnd(BuildContext context, DragEndDetails d) {
    if (!enabled) return;

    final dir = Directionality.of(context);
    final v = d.primaryVelocity ?? 0;

    // В LTR «назад» = свайп вправо (v > 0), в RTL — влево (v < 0)
    final bool isBackGesture = dir == TextDirection.rtl
        ? v < -velocityThreshold
        : v > velocityThreshold;

    if (isBackGesture) {
      final nav = Navigator.of(context, rootNavigator: useRootNavigator);
      if (nav.canPop()) nav.maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // жест ловится по всей площади
      onHorizontalDragEnd: (d) => _onHorizontalDragEnd(context, d),
      child: child,
    );
  }
}
