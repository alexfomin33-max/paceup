import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';

class ViewingSneakersContent extends StatelessWidget {
  const ViewingSneakersContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        GearViewCard.shoes(
          brand: 'Asics',
          model: 'Jolt 3 Wide',
          asset: 'assets/view_asics.png',
          km: 582,
          workouts: 46,
          hours: 48,
          pace: '4:18 /км',
          since: 'В использовании с 21 июля 2023 г.',
          mainBadgeText: 'Основные',
        ),
        SizedBox(height: 12),
        GearViewCard.shoes(
          brand: 'Anta',
          model: 'M C202',
          asset: 'assets/view_anta.png',
          km: 1204,
          workouts: 68,
          hours: 102,
          pace: '3:42 /км',
          since: 'В использовании с 18 августа 2022 г.',
        ),
      ],
    );
  }
}

/// Публичная карточка для «Просмотра снаряжения»
class GearViewCard extends StatelessWidget {
  final String brand;
  final String model;
  final String asset;
  final int km;
  final int workouts;
  final int hours;
  final String thirdValue; // pace/speed
  final String thirdLabel;
  final String since;
  final String? mainBadgeText;

  const GearViewCard.shoes({
    super.key,
    required this.brand,
    required this.model,
    required this.asset,
    required this.km,
    required this.workouts,
    required this.hours,
    required String pace,
    required this.since,
    this.mainBadgeText,
  }) : thirdValue = pace,
       thirdLabel = 'Средний темп';

  const GearViewCard.bike({
    super.key,
    required this.brand,
    required this.model,
    required this.asset,
    required this.km,
    required this.workouts,
    required this.hours,
    required String speed,
    required this.since,
    this.mainBadgeText,
  }) : thirdValue = speed,
       thirdLabel = 'Скорость';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: const Color(0xFFEAEAEA), width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Заголовок (иконка в одной строке с названием)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$brand ',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        TextSpan(
                          text: model,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  tooltip: 'Меню',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: const Icon(
                    CupertinoIcons.ellipsis, // горизонтальная иконка
                    size: 18,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),

          // ── Чип «Основные/Основной» сразу под названием
          if (mainBadgeText != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20), // пилюля
                ),
                child: Text(
                  mainBadgeText!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.surface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // ── Изображение
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: AspectRatio(
              aspectRatio: 16 / 7.8,
              child: Image.asset(asset, fit: BoxFit.contain),
            ),
          ),

          // ── Пробег
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.text,
                  ),
                  children: [
                    const TextSpan(text: 'Пробег '),
                    TextSpan(
                      text: '$km',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: ' км'),
                  ],
                ),
              ),
            ),
          ),

          // ── Разделитель между пробегом и метриками
          const Divider(
            height: 1,
            thickness: 0.5,
            color: Color(0xFFEAEAEA),
            indent: 12,
            endIndent: 12,
          ),

          // ── Метрики (левое выравнивание чисел)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                _metric('Тренировок', '$workouts'),
                _metric('Время', '$hours ч'),
                _metric(thirdLabel, thirdValue),
              ],
            ),
          ),

          // ── Дата
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Text(
              since,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.greytext,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // ← левое выравнивание
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.left, // ← на всякий случай
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
