import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../service/api_service.dart';
import 'event_detail_screen.dart';

/// Каркас bottom sheet для вкладки «События».
class EventsBottomSheet extends StatelessWidget {
  final String title;
  final List<dynamic> events; // Список событий из API (краткая версия)
  final double? latitude;
  final double? longitude;
  final double maxHeightFraction;

  const EventsBottomSheet({
    super.key,
    required this.title,
    required this.events,
    this.latitude,
    this.longitude,
    this.maxHeightFraction = 0.6, // увеличен до 60% для списка событий
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

              // контент: список событий
              Expanded(
                child: events.isEmpty
                    ? const EventsSheetPlaceholder()
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 2,
                          ),
                          child: EventsListFromApi(
                            events: events,
                            latitude: latitude,
                            longitude: longitude,
                          ),
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

/// Список событий из API для отображения в bottom sheet
class EventsListFromApi extends StatelessWidget {
  final List<dynamic> events; // Краткая версия событий
  final double? latitude;
  final double? longitude;

  const EventsListFromApi({
    super.key,
    required this.events,
    this.latitude,
    this.longitude,
  });

  /// Загрузка детальной информации о событии по ID
  Future<Map<String, dynamic>?> _loadEventDetails(int eventId) async {
    try {
      final api = ApiService();
      final data = await api.get('/get_events.php', queryParams: {
        'event_id': eventId.toString(),
      });
      if (data['success'] == true && data['event'] != null) {
        return data['event'] as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Ошибка загрузки детальной информации о событии: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        children: [
          for (int i = 0; i < events.length; i++) ...[
            if (i > 0) const _ClubsDivider(),
            _EventCard(
              eventId: events[i]['id'] as int,
              name: events[i]['name'] as String? ?? 'Название события',
              participantsCount: events[i]['participants_count'] as int? ?? 0,
              onTap: () async {
                // Загружаем детальную информацию и открываем экран
                final details = await _loadEventDetails(events[i]['id'] as int);
                if (context.mounted && details != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(eventData: details),
                    ),
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Не удалось загрузить информацию о событии'),
                    ),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Карточка события в списке
class _EventCard extends StatelessWidget {
  final int eventId;
  final String name;
  final int participantsCount;
  final VoidCallback onTap;

  const _EventCard({
    required this.eventId,
    required this.name,
    required this.participantsCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Плейсхолдер для изображения (80x55)
              Container(
                width: 80,
                height: 55,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: const Icon(
                  Icons.event,
                  color: AppColors.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h14w6,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Участников: $participantsCount',
                      style: AppTextStyles.h13w4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
