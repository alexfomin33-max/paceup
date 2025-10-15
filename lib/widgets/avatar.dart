// lib/widgets/avatar.dart
import 'package:flutter/material.dart';
import 'optimized_avatar.dart';

/// ──────────────────────────────────────────────────────────────
/// AVATAR (универсальный): круглая картинка, url или asset, fallback
/// ──────────────────────────────────────────────────────────────
/// Зачем: унифицировать аватар для Поста и Активности.
/// Что даст: единое поведение (gaplessPlayback + опц. fadeIn), единый вид.
class Avatar extends StatelessWidget {
  final String image; // может быть url или путь к ассету
  final double size; // сторона квадрата (по умолчанию 40)
  final bool fadeIn; // мягкое проявление при смене источника
  final bool gapless; // анти-мигание при быстрой прокрутке

  const Avatar({
    super.key,
    required this.image,
    this.size = 40,
    this.fadeIn = true,
    this.gapless = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isNet =
        image.startsWith('http://') || image.startsWith('https://');

    return ClipOval(
      child: OptimizedAvatar(
        url: isNet ? image : null,
        asset: isNet
            ? null
            : (image.isNotEmpty ? image : 'assets/avatar_2.png'),
        size: size,
        radius: size / 2, // скругление выше, оставлено для совместимости
        fallbackAsset: 'assets/avatar_2.png',
        gaplessPlayback: gapless, // Зачем: «без разрыва» → нет мигания
        fadeIn: fadeIn, // Что даст: мягкая смена кадра
        // fadeDuration / fadeCurve можно кастомизировать при желании
      ),
    );
  }
}
