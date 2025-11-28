import 'package:flutter/material.dart';
import '../../../core/utils/image_precache.dart';

/// Единый каркас auth-экранов: фон + затемнение + логотип + нижний слот для контента.
/// Используйте как body любого экрана: Scaffold(body: AuthShell(child: ...))
class AuthShell extends StatefulWidget {
  final Widget child;

  /// Отступы контейнера с контентом у нижнего края (как было в ваших экранах).
  final EdgeInsetsGeometry contentPadding;

  /// Прозрачность чёрного слоя поверх фона (0.0–1.0).
  final double overlayAlpha;

  const AuthShell({
    super.key,
    required this.child,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 40,
      vertical: 100,
    ),
    this.overlayAlpha = 0.4,
  });

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Предзагрузка фона один раз. Повторные вызовы безопасны.
    ImagePrecache.precacheOnce(context, 'assets/background.webp');
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // 🔹 Адаптивный размер логотипа: 25% от ширины экрана, но в пределах 140-220px
    final logoSize = (screenSize.width * 0.25).clamp(140.0, 220.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          "assets/background.webp",
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
        ),
        Container(color: Colors.black.withValues(alpha: widget.overlayAlpha)),
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: screenSize.height * 0.11),
            child: Image.asset(
              "assets/logo_icon.png",
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(padding: widget.contentPadding, child: widget.child),
        ),
      ],
    );
  }
}
