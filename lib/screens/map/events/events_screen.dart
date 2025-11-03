import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'addevent_screen.dart';
import 'events_bottom_sheet.dart';
import 'events_filters_bottom_sheet.dart';
import '../../../../../theme/app_theme.dart';
import '../../../widgets/transparent_route.dart';
import '../../../service/api_service.dart';
import 'dart:convert';

/// Возвращает маркеры для вкладки «События».
/// Загружает данные через API и группирует события по локациям
Future<List<Map<String, dynamic>>> eventsMarkers(BuildContext context) async {
  try {
    final api = ApiService();
    
    // Загружаем маркеры с группировкой по локациям
    final data = await api.get(
      '/get_events.php',
      queryParams: {'detail': 'false'},
    );
    
    if (data['success'] != true) {
      return [];
    }
    
    final markers = data['markers'] as List<dynamic>? ?? [];
    
    return markers.map<Map<String, dynamic>>((marker) {
      final lat = (marker['latitude'] as num).toDouble();
      final lng = (marker['longitude'] as num).toDouble();
      final count = marker['count'] as int? ?? 0;
      final place = marker['place'] as String? ?? '';
      final events = marker['events'] as List<dynamic>? ?? [];
      
      // Формируем заголовок для bottom sheet
      String title = 'События';
      if (place.isNotEmpty) {
        title = 'События в $place';
      }
      
      return {
        'point': LatLng(lat, lng),
        'title': title,
        'count': count,
        'events': events,
        'latitude': lat,
        'longitude': lng,
      };
    }).toList();
  } catch (e) {
    // В случае ошибки возвращаем пустой список
    return [];
  }
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
              showModalBottomSheet(
                context: context,
                useRootNavigator: true,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const EventsFiltersBottomSheet(),
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
