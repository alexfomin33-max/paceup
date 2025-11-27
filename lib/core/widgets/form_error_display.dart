// ────────────────────────────────────────────────────────────────────────────
//  FORM ERROR DISPLAY
//
//  Виджет для отображения ошибок формы
//  Единый стиль отображения ошибок во всех формах
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../providers/form_state.dart';

/// Виджет для отображения общей ошибки формы
///
/// Использование:
/// ```dart
/// FormErrorDisplay(formState: formState)
/// ```
class FormErrorDisplay extends StatelessWidget {
  /// Состояние формы
  final AppFormState formState;

  /// Отступ сверху
  final double? topPadding;

  /// Отступ снизу
  final double? bottomPadding;

  const FormErrorDisplay({
    super.key,
    required this.formState,
    this.topPadding,
    this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    // Показываем только если есть общая ошибка (не ошибки полей)
    if (formState.error == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(
        top: topPadding ?? 0,
        bottom: bottomPadding ?? 20,
      ),
      child: SelectableText.rich(
        TextSpan(
          text: formState.error!,
          style: const TextStyle(
            color: AppColors.error,
            fontSize: 14,
            fontFamily: 'Inter',
          ),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

