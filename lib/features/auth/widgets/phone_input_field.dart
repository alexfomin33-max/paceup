import 'package:flutter/material.dart';
import 'package:mask_input_formatter/mask_input_formatter.dart';
import '../../../../core/theme/app_theme.dart';

/// 🔹 Универсальное поле ввода телефона с валидацией
/// Используется на экранах входа и регистрации
class PhoneInputField extends StatefulWidget {
  /// 🔹 Контроллер для поля ввода
  final TextEditingController controller;

  /// 🔹 Callback при изменении валидности телефона
  final ValueChanged<bool>? onValidationChanged;

  const PhoneInputField({
    super.key,
    required this.controller,
    this.onValidationChanged,
  });

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  /// 🔹 Флаг валидности телефона
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    // 🔹 Подписываемся на изменения текста для валидации
    widget.controller.addListener(_validatePhone);
    // 🔹 Проверяем начальное состояние
    _validatePhone();
  }

  @override
  void dispose() {
    // 🔹 Отписываемся от контроллера
    widget.controller.removeListener(_validatePhone);
    super.dispose();
  }

  /// 🔹 Валидация номера телефона
  /// Проверяет, что номер содержит минимум 11 цифр и начинается с 7
  void _validatePhone() {
    // 🔹 Убираем все нецифровые символы для проверки
    final phone = widget.controller.text.replaceAll(RegExp(r'[^\d]'), '');
    // 🔹 Валидный номер: минимум 11 цифр и начинается с 7
    final isValid = phone.length >= 11 && phone.startsWith('7');

    if (_isValid != isValid) {
      setState(() => _isValid = isValid);
      // 🔹 Уведомляем родительский виджет об изменении валидности
      widget.onValidationChanged?.call(isValid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextFormField(
        controller: widget.controller,
        keyboardType: TextInputType.phone,
        textCapitalization: TextCapitalization.none,
        textInputAction: TextInputAction.done,
        style: const TextStyle(color: AppColors.surface),
        inputFormatters: [MaskInputFormatter(mask: '+# (###) ###-##-##')],
        decoration: InputDecoration(
          hintText: "+7 (999) 123-45-67",
          labelText: "Телефон",
          floatingLabelBehavior: FloatingLabelBehavior.always,
          hintStyle: const TextStyle(color: AppColors.textPlaceholder),
          labelStyle: const TextStyle(color: AppColors.surface, fontSize: 16),
          border: OutlineInputBorder(
            borderSide: const BorderSide(width: 1.0, color: AppColors.surface),
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(width: 1.0, color: AppColors.surface),
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(width: 1.0, color: AppColors.surface),
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ),
      ),
    );
  }
}

