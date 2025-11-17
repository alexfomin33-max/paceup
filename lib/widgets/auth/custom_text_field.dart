import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

/// 🔹 Универсальное текстовое поле для форм регистрации
/// Используется на экранах regstep1 и regstep2
class CustomTextField extends StatelessWidget {
  /// 🔹 Контроллер для поля ввода
  final TextEditingController controller;

  /// 🔹 Метка поля
  final String label;

  /// 🔹 Максимальная длина ввода (опционально)
  final int? maxLength;

  /// 🔹 Тип клавиатуры
  final TextInputType? keyboardType;

  /// 🔹 Форматтеры ввода (например, только цифры)
  final List<TextInputFormatter>? inputFormatters;

  /// 🔹 Показывать ли звёздочку обязательного поля
  final bool showRequiredStar;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.showRequiredStar = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType ?? TextInputType.text,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        label: RichText(
          text: TextSpan(
            text: showRequiredStar
                ? label.replaceAll('*', '')
                : label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            children: [
              if (showRequiredStar || label.contains('*'))
                const TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 16,
                  ),
                ),
            ],
          ),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

