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
    {
      'point': const LatLng(56.326797, 44.006516),
      'title': 'Попутчики в Нижнем Новгороде',
      'count': 5,
      'content': const _Travelers(),
    },
    {
      'point': const LatLng(56.999799, 40.973014),
      'title': 'Попутчики в Иваново',
      'count': 1,
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
              // TODO: открыть фильтры попутчиков
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Фильтры попутчиков — скоро')),
              );
            },
          ),
          _SolidPillButton(
            icon: Icons.person_search_outlined,
            label: 'Разместить поиск',
            onTap: () {
              // TODO: форма/шит создания заявки на поиск попутчиков
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
