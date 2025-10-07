import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'travelers_bottom_sheet.dart';

/// Возвращает маркеры для вкладки «Попутчики».
List<Map<String, dynamic>> travelersMarkers(BuildContext context) {
  return [
    {
      'point': const LatLng(56.419333, 40.448757),
      'title': 'Попутчики в Суздаль',
      'count': 3,
      'content': const TravelersSheetText('Суздаль: заявки появятся здесь'),
    },
    {
      'point': const LatLng(55.755864, 37.617698),
      'title': 'Попутчики в Москву',
      'count': 2,
      'content': const TravelersSheetText('Москва: заявки появятся здесь'),
    },
    {
      'point': const LatLng(56.326797, 44.006516),
      'title': 'Попутчики в Нижнем Новгороде',
      'count': 5,
      'content': const TravelersSheetText(
        'Нижний Новгород: заявки появятся здесь',
      ),
    },
    {
      'point': const LatLng(56.999799, 40.973014),
      'title': 'Попутчики в Иваново',
      'count': 1,
      'content': const TravelersSheetText('Иваново: заявки появятся здесь'),
    },
  ];
}

// === Нижние кнопки для вкладки «Попутчики» ===
class TravelersFloatingButtons extends StatelessWidget {
  const TravelersFloatingButtons({super.key});

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
                const SnackBar(content: Text('Фильтры попутчиков — скоро')),
              );
            },
          ),
          _SolidPillButton(
            icon: Icons.person_search_outlined,
            label: 'Разместить поиск',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Разместить поиск — скоро')),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Локальная кнопка-«таблетка»
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
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
                  fontWeight: FontWeight.w500,
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
