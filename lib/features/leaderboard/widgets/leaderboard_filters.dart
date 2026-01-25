// lib/features/leaderboard/widgets/leaderboard_filters.dart
// ─────────────────────────────────────────────────────────────────────────────
// Виджеты фильтров лидерборда: параметры, период, вид спорта, пол
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/leaderboard_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
//                     ВЫПАДАЮЩИЙ СПИСОК ПАРАМЕТРОВ
// ─────────────────────────────────────────────────────────────────────────────
/// Виджет выпадающего списка параметров лидерборда (стиль как "Вид активности")
class ParameterDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const ParameterDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.getSurfaceColor(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(
              color: AppColors.twinchip,
                          width: 0.7,
            ),
            
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(
              color: AppColors.twinchip,
                          width: 0.7,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(
              color: AppColors.twinchip,
                          width: 0.7,
            ),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            hint: const Text(
              'Выберите параметр',
              style: AppTextStyles.h14w4Place,
            ),
            onChanged: onChanged,
            dropdownColor: AppColors.getSurfaceColor(context),
            menuMaxHeight: 300,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            icon: Icon(
              Icons.arrow_drop_down,
              color: AppColors.getIconSecondaryColor(context),
            ),
            style: AppTextStyles.h14w4.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
            items: kLeaderboardParameters.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Builder(
                  builder: (context) => Text(
                    option,
                    style: AppTextStyles.h14w4.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ВЫПАДАЮЩИЙ СПИСОК ПЕРИОДА
// ─────────────────────────────────────────────────────────────────────────────
/// Виджет выпадающего списка периода лидерборда
class PeriodDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const PeriodDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.getSurfaceColor(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(
              color: AppColors.twinchip,
                          width: 0.7,
            ),
            
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(
              color: AppColors.twinchip,
                          width: 0.7,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(
              color: AppColors.twinchip,
                          width: 0.7,
            ),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            hint: const Text(
              'Выберите период',
              style: AppTextStyles.h14w4Place,
            ),
            onChanged: onChanged,
            dropdownColor: AppColors.getSurfaceColor(context),
            menuMaxHeight: 300,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            icon: Icon(
              Icons.arrow_drop_down,
              color: AppColors.getIconSecondaryColor(context),
            ),
            style: AppTextStyles.h14w4.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
            items: kPeriods.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Builder(
                  builder: (context) => Text(
                    option,
                    style: AppTextStyles.h14w4.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ИКОНКА ВИДА СПОРТА
// ─────────────────────────────────────────────────────────────────────────────
/// Иконка вида спорта с кружком (аналогична general_stats_content.dart)
class SportIcon extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const SportIcon({
    super.key,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandPrimary
              : AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: AppColors.twinchip,
                          width: 0.7,
          ),
          
        ),
        child: Icon(
          icon,
          size: 20,
          color: selected
              ? AppColors.getSurfaceColor(context)
              : AppColors.getIconPrimaryColor(context),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ИКОНКА ПОЛА
// ─────────────────────────────────────────────────────────────────────────────
/// Иконка пола с текстом "М" или "Ж" (аналогична SportIcon)
class GenderIcon extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const GenderIcon({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandPrimary
              : AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: AppColors.twinchip,
                          width: 0.7,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.h14w4.copyWith(
              color: selected
                  ? AppColors.getSurfaceColor(context)
                  : AppColors.getTextPrimaryColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ИКОНКА ПРИМЕНИТЬ ДАТЫ
// ─────────────────────────────────────────────────────────────────────────────
/// Иконка галочки для применения выбранного периода (аналогична GenderIcon)
class ApplyDateIcon extends StatelessWidget {
  final VoidCallback onTap;
  final bool selected;
  final bool enabled;

  const ApplyDateIcon({
    super.key,
    required this.onTap,
    this.selected = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandPrimary
                : AppColors.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
            color: AppColors.twinchip,
                          width: 0.7,
          ),
          ),
          child: Icon(
            Icons.check,
            size: 20,
            color: selected
                ? AppColors.getSurfaceColor(context)
                : AppColors.getIconPrimaryColor(context),
          ),
        ),
      ),
    );
  }
}

