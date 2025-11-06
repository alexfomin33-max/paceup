import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/transparent_route.dart';
import '../club_detail_screen.dart';

/// Каркас bottom sheet для вкладки «Клубы» — 1:1 как в events_bottom_sheet.dart
class ClubsBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final double maxHeightFraction;

  const ClubsBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.maxHeightFraction = 0.5, // не выше 50% экрана
  });

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final maxH = h * maxHeightFraction;

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // «ручка»
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10, top: 4),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),

              // заголовок
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(child: Text(title, style: AppTextStyles.h17w6)),
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 6),

              // контент — отдаем прокрутку на откуп дочернему виджету
              // чтобы списки могли лениво строиться без двойного скролла
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  child: child,
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

/// Заглушка (если контента нет)
class ClubsSheetPlaceholder extends StatelessWidget {
  const ClubsSheetPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 40),
      child: Text('Здесь будет контент…', style: TextStyle(fontSize: 14)),
    );
  }
}

/// Простой текст в шите «Клубы» (аналог EventsSheetText)
class ClubsSheetText extends StatelessWidget {
  final String text;
  const ClubsSheetText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 14));
  }
}

/// Список клубов из API (для отображения в bottom sheet)
class ClubsListFromApi extends StatelessWidget {
  final List<dynamic> clubs;
  final double? latitude;
  final double? longitude;

  const ClubsListFromApi({
    super.key,
    required this.clubs,
    this.latitude,
    this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    if (clubs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 40),
        child: Text('Клубы не найдены', style: TextStyle(fontSize: 14)),
      );
    }

    // ───────────────────── Лёгкий префетч логотипов (топ-8) ─────────────────────
    // Выполняется при первом построении: подогреваем кэш под целевые размеры
    // для ускорения первого кадра и плавного скролла.
    () {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final targetW = (90 * dpr).round();
      final targetH = (60 * dpr).round();
      final int limit = clubs.length < 8 ? clubs.length : 8;
      for (var i = 0; i < limit; i++) {
        final c = clubs[i] as Map<String, dynamic>;
        final logoUrl = c['logo_url'] as String?;
        if (logoUrl != null && logoUrl.isNotEmpty) {
          // precacheImage не блокирует UI; повторные вызовы недороги благодаря кэшу
          precacheImage(
            CachedNetworkImageProvider(
              logoUrl,
              maxWidth: targetW,
              maxHeight: targetH,
            ),
            context,
          );
        }
      }
    }();

    // ───────────────────── Строка карточки клуба ─────────────────────
    Widget cardRow({
      required String? logoUrl,
      required String title,
      required String subtitle,
      VoidCallback? onTap,
    }) {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final targetW = (90 * dpr).round();
      final targetH = (60 * dpr).round();

      final imageWidget = logoUrl != null && logoUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: logoUrl,
              width: 90,
              height: 60,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 120),
              memCacheWidth: targetW,
              memCacheHeight: targetH,
              maxWidthDiskCache: targetW,
              maxHeightDiskCache: targetH,
              errorWidget: (_, __, ___) => Container(
                width: 90,
                height: 60,
                color: AppColors.border,
                child: const Icon(Icons.broken_image, size: 24),
              ),
            )
          : Container(
              width: 90,
              height: 60,
              color: AppColors.border,
              child: const Icon(Icons.image, size: 24),
            );

      final row = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          imageWidget,
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      );

      if (onTap == null) return row;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onTap,
          child: row,
        ),
      );
    }

    // ─────────────────────────── Ленивый список ───────────────────────────
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 50),
      physics: const BouncingScrollPhysics(),
      itemCount: clubs.length,
      separatorBuilder: (_, __) => const _ClubsDivider(),
      itemBuilder: (context, index) {
        final club = clubs[index] as Map<String, dynamic>;
        final clubId = club['id'] as int?;
        final name = club['name'] as String? ?? '';
        final logoUrl = club['logo_url'] as String?;
        final city = club['city'] as String? ?? '';
        final membersCount = club['members_count'] as int? ?? 0;
        final subtitle = '$city · Участников: $membersCount';

        final row = cardRow(
          logoUrl: logoUrl,
          title: name,
          subtitle: subtitle,
          onTap: clubId != null
              ? () {
                  Navigator.of(context).push(
                    TransparentPageRoute(
                      builder: (_) => ClubDetailScreen(clubId: clubId),
                    ),
                  );
                }
              : null,
        );

        // Нижняя граница под самой последней карточкой
        if (index == clubs.length - 1) {
          return Column(children: [row, const _ClubsDivider()]);
        }

        return row;
      },
    );
  }
}

class _ClubsDivider extends StatelessWidget {
  const _ClubsDivider();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, thickness: 0.5, color: AppColors.border),
    );
  }
}
