import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'coaches_bottom_sheet.dart';
import '../../../../../core/theme/app_theme.dart';

/// Возвращает маркеры для вкладки «Тренеры».
List<Map<String, dynamic>> coachesMarkers(BuildContext context) {
  return [
    {
      'point': const LatLng(56.129057, 40.406635),
      'title': 'Тренеры Владимира',
      'count': 2,
      'content': const CoachesSheetText('Владимир: тренеры появятся здесь'),
      // когда будут ассеты — подставь:
      // 'content': const CoachesListVladimir(),
    },
    {
      'point': const LatLng(55.755864, 37.617698),
      'title': 'Тренеры Москвы',
      'count': 5,
      'content': const CoachesSheetText('Москва: тренеры появятся здесь'),
    },
    {
      'point': const LatLng(56.326797, 44.006516),
      'title': 'Тренеры Нижнего Новгорода',
      'count': 3,
      'content': const CoachesSheetText(
        'Нижний Новгород: тренеры появятся здесь',
      ),
    },
    {
      'point': const LatLng(57.626559, 39.893813),
      'title': 'Тренеры Ярославля',
      'count': 1,
      'content': const CoachesSheetText('Ярославль: тренеры появятся здесь'),
    },
  ];
}

// === Нижние кнопки для вкладки «Тренеры» (как раньше) ===
class CoachesFloatingButtons extends StatelessWidget {
  const CoachesFloatingButtons({super.key});

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
                const SnackBar(content: Text('Фильтры тренеров — скоро')),
              );
            },
          ),
          _SolidPillButton(
            icon: CupertinoIcons.person_crop_circle_badge_plus,
            label: 'Добавить',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Добавить тренера — скоро')),
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
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
