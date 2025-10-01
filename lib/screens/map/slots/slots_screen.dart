import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/app_theme.dart';

/// Возвращает маркеры для вкладки «Слоты».
List<Map<String, dynamic>> slotsMarkers(BuildContext context) {
  return [
    {
      'point': const LatLng(56.419333, 40.448757),
      'title': 'Слоты в Суздале',
      'count': 2,
      'content': const _SimpleList(items: ['Суздаль: слот Т100']),
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
