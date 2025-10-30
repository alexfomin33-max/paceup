// lib/widgets/optimized_avatar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/avatar_version_provider.dart';

/// Универсальный аватар с fallback, gaplessPlayback и опциональным fade-in.
/// Поддерживает сеть (url) и ассет (asset).
/// Скругление делайте снаружи (ClipRRect/ClipOval).
///
/// Автоматически добавляет версию к URL для cache-busting при обновлении аватарки.
class OptimizedAvatar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // Получаем текущую версию аватарки для cache-busting
    final avatarVersion = ref.watch(avatarVersionProvider);

    // Определяем «эффективный» источник — нужен стабильный ключ для AnimatedSwitcher.
    final String effectiveSource = _effectiveSource(avatarVersion);

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

  String _effectiveSource(int version) {
    // Берём строку, по которой однозначно понять «сменился ли кадр»
    if (url != null && url!.trim().isNotEmpty) {
      final baseUrl = url!.trim();
      // Добавляем версию для cache-busting
      if (version > 0) {
        final separator = baseUrl.contains('?') ? '&' : '?';
        return 'net:$baseUrl${separator}v=$version';
      }
      return 'net:$baseUrl';
    }
    final p = (asset != null && asset!.trim().isNotEmpty)
        ? asset!.trim()
        : fallbackAsset;
    return 'asset:$p';
  }

  Widget _buildImage(String effectiveSource) {
    if (effectiveSource.startsWith('net:')) {
      // Сетевой кейс — используем CachedNetworkImage с unified кэш-менеджером
      // ✅ UNIFIED IMAGE CACHE:
      // Теперь ВСЁ приложение (лента, профиль, аватарки, посты) использует:
      // - ОДИН disk cache (flutter_cache_manager)
      // - ОДИН memory cache (ImageCache)
      // Это гарантирует:
      // - Одно изображение = один HTTP запрос для всего приложения
      // - Аватарка в ленте и профиле — одна и та же копия в памяти
      // - Автоматическая очистка старых файлов (7 дней)
      final url = effectiveSource.substring(4);

      return CachedNetworkImage(
        imageUrl: url,
        // НЕ передаем cacheManager - используется DefaultCacheManager с offline support
        width: size,
        height: size,
        fit: fit,
        // Плавный placeholder (прозрачный для gaplessPlayback эффекта)
        placeholder: (context, url) => const SizedBox.shrink(),
        // Fallback на дефолтную аватарку при ошибке
        errorWidget: (context, url, error) =>
            Image.asset(fallbackAsset, width: size, height: size, fit: fit),
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
