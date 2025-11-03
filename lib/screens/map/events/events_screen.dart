import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'addevent_screen.dart';
import 'events_bottom_sheet.dart';
import '../../../../../theme/app_theme.dart';
import '../../../widgets/transparent_route.dart';
import '../../../service/api_service.dart';

/// Возвращает маркеры для вкладки «События» через API.
/// Использует FutureBuilder для асинхронной загрузки данных.
Future<List<Map<String, dynamic>>> eventsMarkersAsync() async {
  try {
    final api = ApiService();
    final data = await api.get('/get_events.php');
    
    if (data['success'] == true && data['groups'] != null) {
      final groups = data['groups'] as List;
      return groups.map<Map<String, dynamic>>((group) {
        final lat = group['latitude'] as double;
        final lng = group['longitude'] as double;
        final count = group['count'] as int;
        final cityName = group['city_name'] as String? ?? 'Не указано';
        final events = group['events'] as List? ?? [];
        
        return {
          'point': LatLng(lat, lng),
          'title': 'События в $cityName',
          'count': count,
          'latitude': lat,
          'longitude': lng,
          'events': events, // Список событий для bottom sheet
        };
      }).toList();
    }
    
    return [];
  } catch (e) {
    // В случае ошибки возвращаем пустой список
    debugPrint('Ошибка загрузки событий: $e');
    return [];
  }
}

/// Синхронная функция-обертка для обратной совместимости.
/// Возвращает пустой список (реальные данные загружаются асинхронно в map_screen.dart).
List<Map<String, dynamic>> eventsMarkers(BuildContext context) {
  return []; // Реальные данные загружаются через eventsMarkersAsync
}

/// ——— Кнопки снизу для вкладки «События» (оставляем как было) ———
class EventsFloatingButtons extends StatelessWidget {
  const EventsFloatingButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: kBottomNavigationBarHeight - 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SolidPillButton(
            icon: Icons.tune,
            label: 'Фильтры',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Фильтры скоро будут')),
              );
            },
          ),
          _SolidPillButton(
            icon: Icons.add_circle_outline,
            label: 'Добавить',
            onTap: () {
              Navigator.push(
                context,
                TransparentPageRoute(builder: (_) => const AddEventScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Локальная «таблетка»
class _SolidPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SolidPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowMedium,
                blurRadius: 1,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.iconPrimary),
              const SizedBox(width: 8),
              Text(label, style: AppTextStyles.h14w4),
            ],
          ),
        ),
      ),
    );
  }
}
