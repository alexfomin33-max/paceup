import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class DescriptionContent extends StatelessWidget {
  const DescriptionContent({super.key});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      height: 1.35,
      color: AppColors.text,
    );

    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Бежим в лёгком разговорном темпе 👍🏻', style: style),
        SizedBox(height: 10),
        Text(
          'На финише нас уже будет ждать горячий кофе от кофейни Лица бесплатно! '
          'Поддержим ребят покупкой у них вкусных десертов.',
          style: style,
        ),
        SizedBox(height: 10),
        Text('📍 Паркуемся и стартуем от Маркета на горе (финиш там же).', style: style),
        SizedBox(height: 10),
        Text('⏰ Встречаемся в 8:00 у входа в Маркет рядом с Братом.', style: style),
        SizedBox(height: 10),
        Text('🎒 Вещи можно оставить в кофейне «Лица».', style: style),
        SizedBox(height: 10),
        Text('🗺 Маршрут по главным улицам города, 4–7 км с остановками для фото 📸.', style: style),
        SizedBox(height: 10),
        Text('И не забываем вступать в наше сообщество!', style: style),
      ],
    );
  }
}
