import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/transparent_route.dart';
import 'club_detail_screen.dart';

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
        decoration: BoxDecoration(
          color: AppColors.getBackgroundColor(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
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
                  color: AppColors.getBorderColor(context),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),

              // заголовок
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    title,
                    style: AppTextStyles.h17w6.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // контент — отдаем прокрутку на откуп дочернему виджету
              // чтобы списки могли лениво строиться без двойного скролла
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Text(
        'Здесь будет контент…',
        style: TextStyle(
          fontSize: 14,
          color: AppColors.getTextSecondaryColor(context),
        ),
      ),
    );
  }
}

/// Простой текст в шите «Клубы» (аналог EventsSheetText)
class ClubsSheetText extends StatelessWidget {
  final String text;
  const ClubsSheetText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: AppColors.getTextPrimaryColor(context),
      ),
    );
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
      return Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: Text(
          'Клубы не найдены',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.getTextSecondaryColor(context),
          ),
        ),
      );
    }

    // ───────────────────── Лёгкий префетч логотипов (топ-8) ─────────────────────
    // Выполняется при первом построении: подогреваем кэш под целевые размеры
    // для ускорения первого кадра и плавного скролла.
    () {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final targetW = (55 * dpr).round();
      final targetH = (55 * dpr).round();
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

    // ───────────────────── Карточка клуба ─────────────────────
    Widget clubCard({
      required String? logoUrl,
      required String title,
      required String subtitle,
      VoidCallback? onTap,
    }) {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final targetW = (55 * dpr).round();
      final targetH = (55 * dpr).round();

      final imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: logoUrl != null && logoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: logoUrl,
                width: 55,
                height: 55,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 120),
                memCacheWidth: targetW,
                memCacheHeight: targetH,
                maxWidthDiskCache: targetW,
                maxHeightDiskCache: targetH,
                errorWidget: (context, imageUrl, error) => Container(
                  width: 55,
                  height: 55,
                  color: AppColors.getSurfaceMutedColor(context),
                  alignment: Alignment.center,
                  child: Icon(
                    CupertinoIcons.photo,
                    size: 20,
                    color: AppColors.getIconSecondaryColor(context),
                  ),
                ),
              )
            : Container(
                width: 55,
                height: 55,
                color: AppColors.getSurfaceMutedColor(context),
                alignment: Alignment.center,
                child: Icon(
                  CupertinoIcons.photo,
                  size: 20,
                  color: AppColors.getIconSecondaryColor(context),
                ),
              ),
      );

      final content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            imageWidget,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h14w6.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h13w4.copyWith(
                      color: AppColors.getTextSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      // ── определяем цвет тени в зависимости от темы
      final brightness = Theme.of(context).brightness;
      final shadowColor = brightness == Brightness.dark
          ? AppColors.darkShadowSoft
          : AppColors.shadowSoft;

      final card = Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              offset: const Offset(0, 1),
              blurRadius: 1,
              spreadRadius: 0,
            ),
          ],
        ),
        child: content,
      );

      if (onTap == null) return card;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: card,
        ),
      );
    }

    // ─────────────────────────── Ленивый список ───────────────────────────
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 50),
      physics: const BouncingScrollPhysics(),
      itemCount: clubs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final club = clubs[index] as Map<String, dynamic>;
        final clubId = club['id'] as int?;
        final name = club['name'] as String? ?? '';
        final logoUrl = club['logo_url'] as String?;
        final membersCount = club['members_count'] as int? ?? 0;
        final subtitle = 'Участников: $membersCount';

        return clubCard(
          logoUrl: logoUrl,
          title: name,
          subtitle: subtitle,
          onTap: clubId != null
              ? () async {
                  final result = await Navigator.of(context).push(
                    TransparentPageRoute(
                      builder: (_) => ClubDetailScreen(clubId: clubId),
                    ),
                  );
                  // Если клуб был удалён, закрываем bottom sheet и обновляем данные
                  if (result == 'deleted' && context.mounted) {
                    Navigator.of(context).pop('club_deleted');
                  }
                }
              : null,
        );
      },
    );
  }
}
