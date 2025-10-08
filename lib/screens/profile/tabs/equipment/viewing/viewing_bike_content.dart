import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'viewing_sneakers_content.dart'
    show GearViewCard; // теперь публичный класс

class ViewingBikeContent extends StatelessWidget {
  const ViewingBikeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        GearViewCard.bike(
          brand: 'Pinarello',
          model: 'Bolide TR Ultegra Di2',
          asset: 'assets/view_pinarello.png',
          km: 3475,
          workouts: 57,
          hours: 94,
          speed: '37 км/ч',
          since: 'В использовании с 16 августа 2022 г.',
          mainBadgeText: 'Основной',
        ),
        SizedBox(height: 12),
        GearViewCard.bike(
          brand: 'SCOTT',
          model: 'Addict Gravel 10',
          asset: 'assets/view_scott.png',
          km: 2136,
          workouts: 41,
          hours: 67,
          speed: '32 км/ч',
          since: 'В использовании с 25 июня 2020 г.',
        ),
      ],
    );
  }
}
