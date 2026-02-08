import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// МОДЕЛЬ МАРШРУТА ДЛЯ ЧАТА
// ─────────────────────────────────────────────────────────────────────────────
class ChatRouteInfo {
  final int id;
  final String name;
  final String difficulty;
  final double distanceKm;
  final int ascentM;
  final String? routeMapUrl;
  final String? sportType;

  const ChatRouteInfo({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.distanceKm,
    required this.ascentM,
    this.routeMapUrl,
    this.sportType,
  });

  // ────────────────────────────────────────────────────────────
  // 🔹 Парсинг JSON маршрута из API
  // ────────────────────────────────────────────────────────────
  factory ChatRouteInfo.fromJson(Map<String, dynamic> json) {
    return ChatRouteInfo(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      difficulty: (json['difficulty'] as String?) ?? 'medium',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      ascentM: (json['ascent_m'] as num?)?.toInt() ?? 0,
      routeMapUrl: json['route_map_url'] as String?,
      sportType: json['sport_type'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// КАРТОЧКА МАРШРУТА ДЛЯ ЧАТА
// ─────────────────────────────────────────────────────────────────────────────
class ChatRouteCard extends StatelessWidget {
  final ChatRouteInfo route;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ChatRouteCard({
    super.key,
    required this.route,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // ──────────────────────────────────────────────────────────
    // 🔹 Размеры кэша карты с учётом DPR
    // ──────────────────────────────────────────────────────────
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (80 * dpr).round();
    final cacheHeight = (76 * dpr).round();

    // ──────────────────────────────────────────────────────────
    // 🔹 Базовые отступы из токенов
    // ──────────────────────────────────────────────────────────
    const horizontalGap = AppSpacing.sm;
    const verticalGap = AppSpacing.xs;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        // ────────────────────────────────────────────────────────
        // 🔹 Контейнер карточки маршрута
        // ────────────────────────────────────────────────────────
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.twinchip,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ──────────────────────────────────────────────────
            // 🗺️ Статичная карта маршрута
            // ──────────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: route.routeMapUrl != null &&
                      route.routeMapUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: route.routeMapUrl!,
                      width: 80,
                      height: 76,
                      fit: BoxFit.cover,
                      memCacheWidth: cacheWidth,
                      memCacheHeight: cacheHeight,
                      errorWidget: (_, __, ___) =>
                          _mapPlaceholder(context),
                    )
                  : _mapPlaceholder(context),
            ),
            const SizedBox(width: horizontalGap),
            // ──────────────────────────────────────────────────
            // 🧾 Текстовая часть карточки
            // ──────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ──────────────────────────────────────────
                  // 🔹 Название + сложность
                  // ──────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          route.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.h13w4.copyWith(
                            color: AppColors.getTextPrimaryColor(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _difficultyChip(route.difficulty),
                    ],
                  ),
                  const SizedBox(height: verticalGap),
                  // ──────────────────────────────────────────
                  // 🔹 Метрики: вид спорта, дистанция, набор
                  // ──────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _sportChip(),
                      const SizedBox(width: AppSpacing.xs),
                      _metric(
                        context,
                        '${_formatDistanceKm(route.distanceKm)} км',
                      ),
                      const Spacer(),
                      _metric(context, '${route.ascentM} м'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // 🔹 Плейсхолдер карты
  // ────────────────────────────────────────────────────────────
  Widget _mapPlaceholder(BuildContext context) {
    return Container(
      width: 80,
      height: 76,
      color: AppColors.getBackgroundColor(context),
      alignment: Alignment.center,
      child: Icon(
        CupertinoIcons.map,
        size: 24,
        color: AppColors.getIconSecondaryColor(context),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // 🔹 Иконка вида спорта
  // ────────────────────────────────────────────────────────────
  Widget _sportChip() {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: AppColors.brandPrimary,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      alignment: Alignment.center,
      child: Icon(
        _sportIcon(route.sportType),
        size: 12,
        color: AppColors.surface,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // 🔹 Иконка по типу спорта
  // ────────────────────────────────────────────────────────────
  IconData _sportIcon(String? sportType) {
    final type = (sportType ?? '').toLowerCase();
    if (type == 'run' || type == 'running' || type == 'indoor-running') {
      return Icons.directions_run;
    }
    if (type == 'bike' ||
        type == 'cycling' ||
        type == 'bicycle' ||
        type == 'indoor-cycling') {
      return Icons.directions_bike;
    }
    if (type == 'swim' || type == 'swimming') {
      return Icons.pool;
    }
    if (type == 'ski' || type == 'skiing') {
      return Icons.downhill_skiing;
    }
    if (type == 'walking' || type == 'hiking') {
      return Icons.directions_walk;
    }
    return Icons.directions_run;
  }

  // ────────────────────────────────────────────────────────────
  // 🔹 Формат дистанции: без округления вверх, до 2 знаков
  // ────────────────────────────────────────────────────────────
  String _formatDistanceKm(double km) {
    final truncated = (km * 100).truncateToDouble() / 100;
    return truncated.toStringAsFixed(2);
  }

  // ────────────────────────────────────────────────────────────
  // 🔹 Метрика (число + единицы)
  // ────────────────────────────────────────────────────────────
  Widget _metric(BuildContext context, String text) {
    final unitPattern = RegExp(
      r'\s*(км|м|ч|мин|сек|/км|/100м|км/ч|м/с)\s*$',
      caseSensitive: false,
    );
    final match = unitPattern.firstMatch(text);

    var numberPart = text;
    String? unitPart;

    if (match != null) {
      numberPart = text.substring(0, match.start).trim();
      unitPart = match.group(0)?.trim();
    }

    return Text.rich(
      TextSpan(
        text: numberPart,
        style: AppTextStyles.h15w5.copyWith(
          color: AppColors.getTextPrimaryColor(context),
        ),
        children: unitPart != null
            ? [
                TextSpan(
                  text: ' $unitPart',
                  style: AppTextStyles.h13w4.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
              ]
            : null,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // 🔹 Чип сложности
  // ────────────────────────────────────────────────────────────
  Widget _difficultyChip(String difficulty) {
    late final Color color;
    switch (difficulty) {
      case 'easy':
        color = AppColors.success;
        break;
      case 'hard':
        color = AppColors.error;
        break;
      default:
        color = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Icon(
        CupertinoIcons.flame_fill,
        size: 14,
        color: color,
      ),
    );
  }
}
