// lib/widgets/optimized_avatar.dart
import 'package:flutter/material.dart';

/// Универсальный аватар с fallback, gaplessPlayback и опциональным fade-in.
/// Поддерживает сеть (url) и ассет (asset).
/// Скругление делайте снаружи (ClipRRect/ClipOval).
class OptimizedAvatar extends StatelessWidget {
  /// URL картинки (если null — используется [asset])
  final String? url;

  /// Путь к ассету (если [url] == null)
  final String? asset;

  /// Квадратный размер (например, 50)
  final double size;

  /// Радиус — оставлен для совместимости (скругляем снаружи)
  final double? radius;

  /// Ассет, который покажем при ошибке/пустых данных
  final String fallbackAsset;

  /// Если true — Image переиспользует предыдущий кадр (анти-мигание)
  final bool gaplessPlayback;

  /// Как вписывать картинку
  final BoxFit fit;

  /// 🔹 Опциональный fade-in при первом показе/смене источника
  final bool fadeIn;

  /// Длительность fade-in
  final Duration fadeDuration;

  /// Кривая fade-in
  final Curve fadeCurve;

  const OptimizedAvatar({
    super.key,
    this.url,
    this.asset,
    required this.size,
    this.radius,
    required this.fallbackAsset,
    this.gaplessPlayback = false,
    this.fit = BoxFit.cover,
    this.fadeIn = false,
    this.fadeDuration = const Duration(milliseconds: 180),
    this.fadeCurve = Curves.easeOut,
  });

  @override
  Widget build(BuildContext context) {
    // Определяем «эффективный» источник — нужен стабильный ключ для AnimatedSwitcher.
    final String effectiveSource = _effectiveSource();

    final Widget image = _buildImage(effectiveSource);

    // Без fade — рендерим как есть (ноль лишней стоимости)
    if (!fadeIn) {
      return SizedBox(width: size, height: size, child: image);
    }

    // С fade — мягко проявляем новое изображение при смене источника.
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedSwitcher(
        duration: fadeDuration,
        switchInCurve: fadeCurve,
        switchOutCurve: fadeCurve,
        layoutBuilder: (currentChild, previousChildren) {
          // Без сдвигов лэйаута: поверх старого — новое
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(key: ValueKey(effectiveSource), child: image),
      ),
    );
  }

  String _effectiveSource() {
    // Берём строку, по которой однозначно понять «сменился ли кадр»
    if (url != null && url!.trim().isNotEmpty) {
      return 'net:${url!.trim()}';
    }
    final p = (asset != null && asset!.trim().isNotEmpty)
        ? asset!.trim()
        : fallbackAsset;
    return 'asset:$p';
  }

  Widget _buildImage(String effectiveSource) {
    if (effectiveSource.startsWith('net:')) {
      // Сетевой кейс
      return Image.network(
        effectiveSource.substring(4),
        width: size,
        height: size,
        fit: fit,
        gaplessPlayback: gaplessPlayback,
        errorBuilder: (_, __, ___) => Image.asset(
          fallbackAsset,
          width: size,
          height: size,
          fit: fit,
          gaplessPlayback: gaplessPlayback,
        ),
      );
    }

    // Ассет/фолбэк
    final path = effectiveSource.substring(6); // после 'asset:'
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: fit,
      gaplessPlayback: gaplessPlayback,
    );
  }
}
