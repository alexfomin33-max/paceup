import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/app_theme.dart';

/// Возвращает маркеры для вкладки «Слоты».
List<Map<String, dynamic>> slotsMarkers(BuildContext context) {
  return [
    {
      'point': const LatLng(58.048640, 38.855711),
      'title': 'Слоты в Рыбинске',
      'count': 2,
      'content': const _SimpleList(items: ['Рыбинск: слот Т100']),
    },
    {
      'point': const LatLng(56.419333, 40.448757),
      'title': 'Слоты в Суздале',
      'count': 3,
      'content': const _SimpleList(items: ['Суздаль: слот Т100']),
    },
    {
      'point': const LatLng(55.579174, 42.052411),
      'title': 'Слоты в Муроме',
      'count': 1,
      'content': const _SimpleList(items: ['Муром: слот Т100']),
    },
    {
      'point': const LatLng(55.755864, 37.617698),
      'title': 'Слоты в Москве',
      'count': 6,
      'content': const _SimpleList(items: ['Москва: слот Т100']),
    },
  ];
}

class _SimpleList extends StatelessWidget {
  final List<String> items;
  const _SimpleList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final s in items) ...[
          Row(
            children: [
              const Icon(Icons.event_available, color: AppColors.text),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.greytext,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 40),
      ],
    );
  }
}

// === Нижние кнопки для вкладки «Слоты» ===
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
              // TODO: открыть фильтры слотов
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Фильтры слотов — скоро')),
              );
            },
          ),
          _SolidPillButton(
            icon: Icons.sell_outlined,
            label: 'Продать слот',
            onTap: () {
              // TODO: экран/шит продажи слота
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
