// lib/features/leaderboard/widgets/date_range_picker.dart
// ─────────────────────────────────────────────────────────────────────────────
// Виджеты для выбора диапазона дат с маской формата "dd.MM.yyyy"
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//                     ПОЛЕ ДЛЯ ВВОДА ДАТЫ
// ─────────────────────────────────────────────────────────────────────────────
/// Поле для ввода даты с маской формата "dd.MM.yyyy" и клавиатурой с цифрами
class DateField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final VoidCallback? onComplete;

  const DateField({
    super.key,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      inputFormatters: [DateInputFormatter()],
      onChanged: (value) {
        // ── Если введены все 8 цифр (10 символов с точками: dd.MM.yyyy),
        // ── переключаем фокус на следующее поле
        final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
        if (digitsOnly.length == 8 && onComplete != null) {
          onComplete!();
        }
      },
      style: AppTextStyles.h14w4.copyWith(
        color: AppColors.getTextPrimaryColor(context),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.h14w4Place,
        filled: true,
        fillColor: AppColors.getSurfaceColor(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 17,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ФОРМАТТЕР ДЛЯ МАСКИ ДАТЫ
// ─────────────────────────────────────────────────────────────────────────────
/// Форматтер для автоматического форматирования даты в формате "dd.MM.yyyy"
class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // ── Удаляем все символы, кроме цифр
    final text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // ── Ограничиваем длину до 8 цифр (ddMMyyyy)
    String limitedText = text.length > 8 ? text.substring(0, 8) : text;

    // ── Валидация по позициям
    String validatedText = '';
    for (int i = 0; i < limitedText.length; i++) {
      final digit = limitedText[i];
      bool isValid = false;

      switch (i) {
        case 0: // ── Первая цифра дня: 0-3
          isValid =
              digit == '0' || digit == '1' || digit == '2' || digit == '3';
          break;
        case 1: // ── Вторая цифра дня: зависит от первой
          if (validatedText.isNotEmpty) {
            final firstDayDigit = validatedText[0];
            if (firstDayDigit == '0' ||
                firstDayDigit == '1' ||
                firstDayDigit == '2') {
              // ── Для 0x, 1x, 2x: вторая цифра 0-9
              isValid = true;
            } else if (firstDayDigit == '3') {
              // ── Для 3x: вторая цифра только 0-1 (30, 31)
              isValid = digit == '0' || digit == '1';
            }
          } else {
            isValid = true; // ── Если первая цифра еще не введена
          }
          break;
        case 2: // ── Первая цифра месяца: 0-1
          isValid = digit == '0' || digit == '1';
          break;
        case 3: // ── Вторая цифра месяца: зависит от первой
          if (validatedText.length >= 3) {
            final firstMonthDigit = validatedText[2];
            if (firstMonthDigit == '0') {
              // ── Для 0x: вторая цифра 0-9 (01-09)
              isValid = true;
            } else if (firstMonthDigit == '1') {
              // ── Для 1x: вторая цифра только 0-2 (10, 11, 12)
              isValid = digit == '0' || digit == '1' || digit == '2';
            }
          } else {
            isValid = true; // ── Если первая цифра месяца еще не введена
          }
          break;
        case 4: // ── Первая цифра года: только 2
          isValid = digit == '2';
          break;
        case 5: // ── Вторая цифра года: только 0
          isValid = digit == '0';
          break;
        case 6: // ── Третья цифра года: только 2
          isValid = digit == '2';
          break;
        case 7: // ── Четвертая цифра года: только 5-6
          isValid = digit == '5' || digit == '6';
          break;
        default:
          isValid = false;
      }

      if (isValid) {
        validatedText += digit;
      } else {
        // ── Если символ невалиден, останавливаем обработку
        break;
      }
    }

    // ── Форматируем с точками
    String formatted = '';
    for (int i = 0; i < validatedText.length; i++) {
      if (i == 2 || i == 4) {
        formatted += '.';
      }
      formatted += validatedText[i];
    }

    // ── Вычисляем новую позицию курсора
    // ── Если добавляем символ, курсор сдвигается вперед
    // ── Если удаляем, курсор остается на месте
    int cursorPosition = formatted.length;
    if (oldValue.text.length < formatted.length) {
      // ── Добавление символа: курсор после последнего символа
      cursorPosition = formatted.length;
    } else if (oldValue.text.length > formatted.length) {
      // ── Удаление символа: курсор на позиции удаления
      final oldDigits = oldValue.text.replaceAll(RegExp(r'[^\d]'), '');
      final newDigits = formatted.replaceAll(RegExp(r'[^\d]'), '');
      if (oldDigits.length > newDigits.length) {
        // ── Вычисляем позицию в отформатированной строке
        int digitIndex = 0;
        for (int i = 0; i < formatted.length; i++) {
          if (RegExp(r'\d').hasMatch(formatted[i])) {
            if (digitIndex == newDigits.length) {
              cursorPosition = i;
              break;
            }
            digitIndex++;
          }
        }
        if (cursorPosition == formatted.length) {
          cursorPosition = newValue.selection.baseOffset.clamp(
            0,
            formatted.length,
          );
        }
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: cursorPosition.clamp(0, formatted.length),
      ),
    );
  }
}

