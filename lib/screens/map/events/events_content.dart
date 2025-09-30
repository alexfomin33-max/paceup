import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/app_theme.dart';

/// Возвращает маркеры для вкладки «События».
List<Map<String, dynamic>> eventsMarkers(BuildContext context) {
  return [
    {
      'point': const LatLng(56.129057, 40.406635),
      'title': 'События во Владимире',
      'count': 2,
      'content': const _VladimirEvents(),
    },
    {
      'point': const LatLng(55.755864, 37.617698),
      'title': 'События в Москве',
      'count': 5,
      'content': const _SimpleText('Москва: подборка событий скоро здесь'),
    },
  ];
}

class _VladimirEvents extends StatelessWidget {
  const _VladimirEvents();

  @override
  Widget build(BuildContext context) {
    Widget card({
      required String asset,
      required String title,
      required String subtitle,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(asset, width: 90, height: 60, fit: BoxFit.cover),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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
        card(
          asset: 'assets/Vlad_event_1.png',
          title: 'Субботний коферан',
          subtitle: '14 июня 2025  ·  Участников: 32',
        ),
        const SizedBox(height: 16),
        card(
          asset: 'assets/Vlad_event_2.png',
          title: 'Владимирский полумарафон «Золотые ворота»',
          subtitle: '31 августа 2025  ·  Участников: 1426',
        ),
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
