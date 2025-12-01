import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/transparent_route.dart';
import 'event_detail_screen.dart';
import 'official_event_detail_screen.dart';

/// Каркас bottom sheet для вкладки «События».
class EventsBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final double maxHeightFraction;

  const EventsBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.maxHeightFraction = 0.4,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top; // Высота верхней брови (notch)
    final bottomPadding = mediaQuery.padding.bottom; // Высота нижней безопасной зоны
    // Максимальная высота: от низа экрана до верхней брови
    // Вычитаем небольшой отступ снизу для визуального комфорта
    final maxH = screenHeight - topPadding - (bottomPadding > 0 ? bottomPadding : 16);

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Вычисляем доступную высоту для контента
            // Вычитаем высоту ручки (4 + 10), заголовка (~40), отступов (12 + 10 + 12)
            final availableHeight = maxH - 88;
            final contentMaxHeight = availableHeight > 0 ? availableHeight : 100.0;

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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

                  // контент — динамическая высота: занимает только необходимое место
                  // до максимальной высоты, после чего включается скролл
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: contentMaxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        child: child,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Заглушка (если контента нет)
class EventsSheetPlaceholder extends StatelessWidget {
  const EventsSheetPlaceholder({super.key});
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

/// Простой текст для шита «События» (замена _SimpleText)
class EventsSheetText extends StatelessWidget {
  final String text;
  const EventsSheetText(this.text, {super.key});

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

/// Список событий из API (для отображения в bottom sheet)
class EventsListFromApi extends StatelessWidget {
  final List<dynamic> events;
  final double? latitude;
  final double? longitude;

  const EventsListFromApi({
    super.key,
    required this.events,
    this.latitude,
    this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: Text(
          'События не найдены',
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
      final int limit = events.length < 8 ? events.length : 8;
      for (var i = 0; i < limit; i++) {
        final e = events[i] as Map<String, dynamic>;
        final logoUrl = e['logo_url'] as String?;
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

    // ───────────────────── Карточка события ─────────────────────
    Widget eventCard({
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
    // Используем shrinkWrap для динамической высоты bottom sheet
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 50),
      physics: const BouncingScrollPhysics(),
      itemCount: events.length,
      separatorBuilder: (context, index) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final event = events[index] as Map<String, dynamic>;
        final eventId = event['id'] as int?;
        final name = event['name'] as String? ?? '';
        final logoUrl = event['logo_url'] as String?;
        final date = event['date'] as String? ?? '';
        final participantsCount = event['participants_count'] as int? ?? 0;
        final subtitle = '$date  ·  Участников: $participantsCount';
        // ── Проверяем, является ли событие официальным (топ событием)
        // Используем event_type для точного определения, так как registration_link может отсутствовать в кратком списке
        final eventType = event['event_type'] as String? ?? 'amateur';
        final registrationLink = event['registration_link'] as String? ??
            event['event_link'] as String? ??
            '';
        final isOfficialEvent = eventType == 'official' || registrationLink.isNotEmpty;

        return eventCard(
          logoUrl: logoUrl,
          title: name,
          subtitle: subtitle,
          onTap: eventId != null
              ? () async {
                  final result = await Navigator.of(context).push<dynamic>(
                    TransparentPageRoute(
                      builder: (_) => isOfficialEvent
                          ? OfficialEventDetailScreen(eventId: eventId)
                          : EventDetailScreen(eventId: eventId),
                    ),
                  );
                  // Если событие было удалено, закрываем bottom sheet с результатом
                  if (result == true && context.mounted) {
                    Navigator.of(context).pop('event_deleted');
                  }
                }
              : null,
        );
      },
    );
  }
}
