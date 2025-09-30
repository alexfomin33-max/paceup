import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/app_theme.dart';

/// Возвращает маркеры для вкладки «Попутчики».
List<Map<String, dynamic>> travelersMarkers(BuildContext context) {
  return [
    {
      'point': const LatLng(55.45, 37.36),
      'title': 'Попутчик в Подольске',
      'count': 2,
      'content': const _Travelers(),
    },
    {
      'point': const LatLng(56.85, 35.9),
      'title': 'Попутчик в Твери',
      'count': 1,
      'content': const _SimpleText('Тверь: попутчики скоро здесь'),
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
