import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/app_theme.dart';

/// Возвращает маркеры для вкладки «Попутчики».
List<Map<String, dynamic>> travelersMarkers(BuildContext context) {
  return [
    {
      'point': const LatLng(56.419333, 40.448757),
      'title': 'Попутчики в Суздаль',
      'count': 3,
      'content': const _Travelers(),
    },
    {
      'point': const LatLng(55.755864, 37.617698),
      'title': 'Попутчики в Москву',
      'count': 2,
      'content': const _Travelers(),
    },
  ];
}

class _Travelers extends StatelessWidget {
  const _Travelers();

  Widget row(String name, String city, String avatar) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(avatar, width: 40, height: 40, fit: BoxFit.cover),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$name · $city',
            style: const TextStyle(fontSize: 14, color: AppColors.text),
          ),
        ),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          child: const Text(
            'Написать',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        row('Алексей Лукашин', 'Подольск', 'assets/Avatar_1.png'),
        const SizedBox(height: 12),
        row('Екатерина Виноградова', 'Климовск', 'assets/Avatar_4.png'),
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
