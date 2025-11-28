// ────────────────────────────────────────────────────────────────────────────
//  EDIT PROFILE PHYSICAL INFO SECTION
//
//  Секция физических параметров (рост, вес, максимальный пульс)
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import 'edit_profile_form_fields.dart';

/// ───────────────────────────── Секция физических параметров ─────────────────────────────

/// Секция формы с физическими параметрами пользователя
class EditProfilePhysicalInfoSection extends StatelessWidget {
  const EditProfilePhysicalInfoSection({
    super.key,
    required this.height,
    required this.weight,
    required this.hrMax,
  });

  final TextEditingController height;
  final TextEditingController weight;
  final TextEditingController hrMax;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Параметры',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextSecondaryColor(context),
          ),
        ),
        const SizedBox(height: 8),

        EditProfileGroupBlock(
          children: [
            EditProfileFieldRow.input(
              label: 'Рост, см',
              controller: height,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            EditProfileFieldRow.input(
              label: 'Вес, кг',
              controller: weight,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            EditProfileFieldRow.input(
              label: 'Максимальный пульс',
              controller: hrMax,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),

        const SizedBox(height: 12),
        Center(
          child: Text(
            'Данные необходимы для расчёта калорий, нагрузки, зон темпа и мощности.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.getTextPlaceholderColor(context),
            ),
          ),
        ),
      ],
    );
  }
}

