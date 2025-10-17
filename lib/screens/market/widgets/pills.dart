// lib/widgets/pills.dart

import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';

/// Пилюля с дистанцией (фикс. ширина, серый фон)
class DistancePill extends StatelessWidget {
  final String text;
  const DistancePill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.h13w4,
      ),
    );
  }
}

/// Круглая пилюля пола (Ж/М), разный цвет подложки/текста.
class GenderPill extends StatelessWidget {
  final bool female;

  const GenderPill.female({super.key}) : female = true;
  const GenderPill.male({super.key}) : female = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: female ? AppColors.bgfemale : AppColors.bgmale,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        female ? 'Ж' : 'М',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: female ? AppColors.female : AppColors.male,
        ),
      ),
    );
  }
}

/// Пилюля цены (жёлтая), узкая фикс. ширина.
class PricePill extends StatelessWidget {
  final String text;
  const PricePill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.backgroundYellow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.price,
        ),
      ),
    );
  }
}

/// Пилюля города (серый фон, эластичная по ширине).
class CityPill extends StatelessWidget {
  final String text;
  const CityPill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
      ),
    );
  }
}
