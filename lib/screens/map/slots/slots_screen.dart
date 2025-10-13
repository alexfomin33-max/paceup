import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'slots_bottom_sheet.dart';
import '../../../../../theme/app_theme.dart';

/// Возвращает маркеры для вкладки «Слоты».
List<Map<String, dynamic>> slotsMarkers(BuildContext context) {
  return [
    {
      'point': const LatLng(56.129057, 40.406635),
      'title': 'Слоты Владимира',
      'count': 2,
      'content': const SlotsSheetText('Владимир: слоты появятся здесь'),
      // когда будут ассеты — подставь:
      // 'content': const SlotsListVladimir(),
    },
    {
      'point': const LatLng(55.755864, 37.617698),
      'title': 'Слоты Москвы',
      'count': 5,
      'content': const SlotsSheetText('Москва: слоты появятся здесь'),
    },
    {
      'point': const LatLng(56.326797, 44.006516),
      'title': 'Слоты Нижнего Новгорода',
      'count': 3,
      'content': const SlotsSheetText('Нижний Новгород: слоты появятся здесь'),
    },
    {
      'point': const LatLng(57.626559, 39.893813),
      'title': 'Слоты Ярославля',
      'count': 1,
      'content': const SlotsSheetText('Ярославль: слоты появятся здесь'),
    },
  ];
}

// === Нижние кнопки для вкладки «Слоты» (как раньше) ===
class SlotsFloatingButtons extends StatelessWidget {
  const SlotsFloatingButtons({super.key});

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
                const SnackBar(content: Text('Фильтры слотов — скоро')),
              );
            },
          ),
          _SolidPillButton(
            icon: Icons.sell_outlined,
            label: 'Продать слот',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Продать слот — скоро')),
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
