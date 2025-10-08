import 'package:flutter/material.dart';

/// Универсальная аватарка с дешёвым декодированием:
/// - сам считает cacheWidth под реальный размер на экране
/// - работает и с сетью (url), и с ассетами (asset)
/// - есть запасной ассет, если картинка не загрузилась
class OptimizedAvatar extends StatelessWidget {
  final String? url;
  final String? asset;
  final double size;
  final double? radius;
  final String fallbackAsset;

  const OptimizedAvatar({
    super.key,
    this.url,
    this.asset,
    this.size = 40,
    this.radius,
    this.fallbackAsset = 'assets/Avatar_2.png',
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cw = (size * dpr).round();
    final r = radius ?? size / 2;

    Widget child;
    if ((url ?? '').startsWith('http')) {
      child = Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: cw,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => Image.asset(
          asset ?? fallbackAsset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: cw,
          filterQuality: FilterQuality.low,
        ),
      );
    } else {
      child = Image.asset(
        (asset?.isNotEmpty ?? false) ? asset! : fallbackAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: cw,
        filterQuality: FilterQuality.low,
      );
    }

    return ClipRRect(borderRadius: BorderRadius.circular(r), child: child);
  }
}
