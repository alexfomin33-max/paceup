import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/app_theme.dart';
import 'clubs_bottom_sheet.dart';

/// Возвращает маркеры для вкладки «Клубы».
List<Map<String, dynamic>> clubsMarkers(BuildContext context) {
  return [
    {
      'point': const LatLng(56.326797, 44.006516),
      'title': 'Клубы в Нижнем Новгороде',
      'count': 7,
      'content': const _ClubsList(),
    },
    {
      'point': const LatLng(57.626559, 39.893813),
      'title': 'Клубы в Ярославле',
      'count': 4,
      'content': const _SimpleText('Ярославль: список клубов скоро здесь'),
    },
    {
      'point': const LatLng(56.999799, 40.973014),
      'title': 'Клубы в Иваново',
      'count': 4,
      'content': const _SimpleText('Иваново: список клубов скоро здесь'),
    },
    {
      'point': const LatLng(56.129057, 40.406635),
      'title': 'Клубы Владимира', // как на скрине
      'count': 3,
      'content':
          const ClubsListVladimir(), // контент из clubs_bottom_sheet.dart
    },
    {
      'point': const LatLng(55.755864, 37.617698),
      'title': 'Клубы в Москве',
      'count': 9,
      'content': const _SimpleText('Москва: список клубов скоро здесь'),
    },
  ];
}

class _ClubsList extends StatelessWidget {
  const _ClubsList();

  @override
  Widget build(BuildContext context) {
    Widget club(String img, String name, String members) {
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(img, width: 64, height: 64, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Участников: $members',
                  style: const TextStyle(fontSize: 13, color: AppColors.text),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        club('assets/find_club_1.png', 'PaceUp Club', '58 234'),
        const SizedBox(height: 12),
        club('assets/find_club_2.png', '"CoffeeRun_vld"', '400'),
        const SizedBox(height: 12),
        club('assets/find_club_3.png', 'I Love Swimming', '1 670'),
        const SizedBox(height: 50),
      ],
    );
  }
}

class _SimpleText extends StatelessWidget {
  final String text;
  const _SimpleText(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 14, color: AppColors.text));
}

// === Нижние кнопки для вкладки «Клубы» ===
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
              // TODO: открыть фильтры клубов (sheet/экран)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Фильтры клубов — скоро')),
              );
            },
          ),
          _SolidPillButton(
            icon: Icons.group_add_outlined,
            label: 'Создать клуб',
            onTap: () {
              // TODO: перейти на экран создания клуба
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

/// Локальная кнопка-«таблетка» (как в событиях)
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
                blurRadius: 4,
                offset: Offset(0, 2),
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
