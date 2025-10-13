import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'addevent_screen.dart';
import 'events_bottom_sheet.dart';
import '../../../../../theme/app_theme.dart';

/// Возвращает маркеры для вкладки «События».
List<Map<String, dynamic>> eventsMarkers(BuildContext context) {
  return [
    {
      'point': const LatLng(56.129057, 40.406635),
      'title': 'События во Владимире',
      'count': 2,
      'content': const EventsListVladimir(), // ← перенесённый виджет
    },
    {
      'point': const LatLng(55.755864, 37.617698),
      'title': 'События в Москве',
      'count': 5,
      'content': const EventsSheetText('Москва: подборка событий скоро здесь'),
    },
    {
      'point': const LatLng(56.739194, 38.854382),
      'title': 'События в Переславле-Залесском',
      'count': 3,
      'content': const EventsSheetText(
        'Переславль-Залесский: подборка событий скоро здесь',
      ),
    },
    {
      'point': const LatLng(57.767918, 40.926894),
      'title': 'События в Костроме',
      'count': 1,
      'content': const EventsSheetText(
        'Кострома: подборка событий скоро здесь',
      ),
    },
  ];
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
                MaterialPageRoute(builder: (_) => const AddEventScreen()),
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
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 1,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.black87),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
