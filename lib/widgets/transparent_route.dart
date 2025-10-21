import 'package:flutter/material.dart';

class TransparentPageRoute<T> extends PageRoute<T> {
  TransparentPageRoute({
    required this.builder,
    RouteSettings? settings,
    this.transitionDurationMs = 0, // без анимации — управляем жестом сами
  }) : super(settings: settings);

  final WidgetBuilder builder;
  final int transitionDurationMs;

  @override
  bool get opaque => false; // ← ключ! ниже лежащий экран продолжит рисоваться

  @override
  bool get barrierDismissible => false;

  @override
  Color get barrierColor => Colors.transparent; // прозрачный фон, чтобы реально была видна предыдущая страница

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration =>
      Duration(milliseconds: transitionDurationMs);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
