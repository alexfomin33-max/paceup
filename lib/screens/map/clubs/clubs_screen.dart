import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
// Контент шитов теперь здесь:
import 'widgets/clubs_bottom_sheet.dart';

/// Возвращает маркеры для вкладки «Клубы».
List<Map<String, dynamic>> clubsMarkers(BuildContext context) {
  return [
    {
      'point': const LatLng(56.326797, 44.006516),
      'title': 'Клубы в Нижнем Новгороде',
      'count': 7,
      'content': const ClubsSheetText(
        'Нижний Новгород: список клубов скоро здесь',
      ),
    },
    {
      'point': const LatLng(57.626559, 39.893813),
      'title': 'Клубы в Ярославле',
      'count': 4,
      'content': const ClubsSheetText('Ярославль: список клубов скоро здесь'),
    },
    {
      'point': const LatLng(56.999799, 40.973014),
      'title': 'Клубы в Иваново',
      'count': 4,
      'content': const ClubsSheetText('Иваново: список клубов скоро здесь'),
    },
    {
      'point': const LatLng(56.129057, 40.406635),
      'title': 'Клубы Владимира',
      'count': 3,
      'content': const ClubsListVladimir(), // ← контент перенесён сюда
    },
    {
      'point': const LatLng(55.755864, 37.617698),
      'title': 'Клубы в Москве',
      'count': 9,
      'content': const ClubsSheetText('Москва: список клубов скоро здесь'),
    },
  ];
}

// === Нижние кнопки для вкладки «Клубы» (оставляем как было) ===
class ClubsFloatingButtons extends StatelessWidget {
  const ClubsFloatingButtons({super.key});

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
                const SnackBar(content: Text('Фильтры клубов — скоро')),
              );
            },
          ),
          _SolidPillButton(
            icon: Icons.group_add_outlined,
            label: 'Создать клуб',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Экран создания клуба — скоро')),
              );
            },
          ),
        ],
      ),
    );
  }
}

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
