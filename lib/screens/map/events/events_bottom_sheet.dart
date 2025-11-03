import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'coffeerun/coffeerun_screen.dart';
import 'event_detail_screen.dart';

/// Каркас bottom sheet для вкладки «События».
class EventsBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final double maxHeightFraction;

  const EventsBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.maxHeightFraction = 0.4, // не выше 50% экрана
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

              // контент
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    child: child,
                  ),
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
class EventsSheetPlaceholder extends StatelessWidget {
  const EventsSheetPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 40),
      child: Text('Здесь будет контент…', style: TextStyle(fontSize: 14)),
    );
  }
}

/// Простой текст для шита «События» (замена _SimpleText)
class EventsSheetText extends StatelessWidget {
  final String text;
  const EventsSheetText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 14));
  }
}

/// Список событий для Владимира (замена _VladimirEvents)
class EventsListVladimir extends StatelessWidget {
  const EventsListVladimir({super.key});

  @override
  Widget build(BuildContext context) {
    // Универсальная строка карточки. Если есть onTap — делаем кликабельной.
    Widget cardRow({
      required String asset,
      required String title,
      required String subtitle,
      VoidCallback? onTap,
    }) {
      final row = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: Image.asset(asset, width: 80, height: 55, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  title,
                  style: AppTextStyles.h14w6,
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: AppTextStyles.h13w4),
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

    return Padding(
      // небольшой нижний отступ, чтобы не прилипало к краю шита
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 50),
      child: Column(
        children: [
          // Карточка 1 — кликабельная → открывает «Субботний коферан»
          cardRow(
            asset: 'assets/Vlad_event_1.png',
            title: 'Субботний коферан',
            subtitle: '14 июня 2025  ·  Участников: 32',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CoffeerunScreen()),
              );
            },
          ),

          const _ClubsDivider(),

          // Карточка 2
          cardRow(
            asset: 'assets/Vlad_event_2.png',
            title: 'Владимирский полумарафон «Золотые ворота»',
            subtitle: '31 августа 2025  ·  Участников: 1426',
          ),
          const _ClubsDivider(),
        ],
      ),
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
      return const Padding(
        padding: EdgeInsets.only(bottom: 40),
        child: Text(
          'События не найдены',
          style: TextStyle(fontSize: 14),
        ),
      );
    }

    // Универсальная строка карточки. Если есть onTap — делаем кликабельной.
    Widget cardRow({
      required String? logoUrl,
      required String title,
      required String subtitle,
      VoidCallback? onTap,
    }) {
      final row = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: logoUrl != null && logoUrl.isNotEmpty
                ? Image.network(
                    logoUrl,
                    width: 80,
                    height: 55,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 55,
                      color: AppColors.border,
                      child: const Icon(Icons.image, size: 24),
                    ),
                  )
                : Container(
                    width: 80,
                    height: 55,
                    color: AppColors.border,
                    child: const Icon(Icons.image, size: 24),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  title,
                  style: AppTextStyles.h14w6,
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: AppTextStyles.h13w4),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 50),
      child: Column(
        children: List.generate(events.length, (index) {
          final event = events[index] as Map<String, dynamic>;
          final eventId = event['id'] as int?;
          final name = event['name'] as String? ?? '';
          final logoUrl = event['logo_url'] as String?;
          final date = event['date'] as String? ?? '';
          final participantsCount = event['participants_count'] as int? ?? 0;
          final subtitle = '$date  ·  Участников: $participantsCount';

          return Column(
            children: [
              cardRow(
                logoUrl: logoUrl,
                title: name,
                subtitle: subtitle,
                onTap: eventId != null
                    ? () {
                        // Открываем детальную страницу события
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EventDetailScreen(eventId: eventId),
                          ),
                        );
                      }
                    : null,
              ),
              if (index < events.length - 1) const _ClubsDivider(),
            ],
          );
        }),
      ),
    );
  }
}
