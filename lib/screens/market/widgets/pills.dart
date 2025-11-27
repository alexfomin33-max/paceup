// lib/widgets/pills.dart

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// Пилюля с дистанцией (фикс. ширина, background фон в светлой теме)
class DistancePill extends StatelessWidget {
  final String text;
  const DistancePill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    // ── В светлой теме используем background, в темной — серый
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bgColor = isLight
        ? AppColors.background
        : AppColors.getSurfaceMutedColor(context);

    return Container(
      width: 70,
      height: 28,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.h13w4.copyWith(
          color: AppColors.getTextPrimaryColor(context),
        ),
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
    // ── В светлой теме используем цветные фоны и тексты, в темной — серые
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bgColor = isLight
        ? (female ? AppColors.bgfemale : AppColors.bgmale)
        : AppColors.getSurfaceMutedColor(context);
    final textColor = isLight
        ? (female ? AppColors.female : AppColors.male)
        : AppColors.getTextPrimaryColor(context);

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        female ? 'Ж' : 'М',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textColor,
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
    // ── В светлой теме используем желтый фон и коричневый текст, в темной — серые
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bgColor = isLight
        ? AppColors.backgroundYellow
        : AppColors.getSurfaceMutedColor(context);
    final textColor = isLight
        ? AppColors.price
        : AppColors.getTextPrimaryColor(context);

    return Container(
      width: 76,
      height: 28,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textColor,
        ),
      ),
    );
  }
}

/// Пилюля города (background фон в светлой теме, эластичная по ширине).
class CityPill extends StatelessWidget {
  final String text;
  const CityPill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    // ── В светлой теме используем background, в темной — серый
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bgColor = isLight
        ? AppColors.background
        : AppColors.getSurfaceMutedColor(context);

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: AppColors.getTextPrimaryColor(context),
        ),
      ),
    );
  }
}
