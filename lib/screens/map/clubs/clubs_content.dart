import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/app_theme.dart';

/// Возвращает маркеры для вкладки «Клубы».
List<Map<String, dynamic>> clubsMarkers(BuildContext context) {
  return [
    {
      'point': const LatLng(56.326797, 44.006516),
      'title': 'Клуб в Нижнем Новгороде',
      'count': 1,
      'content': const _ClubsList(),
    },
    {
      'point': const LatLng(57.626559, 39.893813),
      'title': 'Клуб в Ярославле',
      'count': 3,
      'content': const _SimpleText('Ярославль: список клубов скоро здесь'),
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
