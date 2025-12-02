// ────────────────────────────────────────────────────────────────────────────
//  ERROR DISPLAY
//
//  Единый виджет для отображения ошибок в приложении
//  Используется во всех экранах для консистентного отображения ошибок
//
//  Возможности:
//  • Единый стиль отображения ошибок
//  • Поддержка кнопки "Повторить" для сетевых ошибок
//  • Адаптивный дизайн (центрирование, отступы)
//  • Поддержка SelectableText для копирования ошибок
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/error_handler.dart';
import 'primary_button.dart';

/// Виджет для отображения ошибок
///
/// Использование:
/// ```dart
/// if (error != null) {
///   return ErrorDisplay(
///     error: error,
///     onRetry: () => loadData(),
///   );
/// }
/// ```
class ErrorDisplay extends StatelessWidget {
  /// Ошибка для отображения (может быть Exception, String, или null)
  final dynamic error;

  /// Колбэк для повторной попытки (опционально)
  ///
  /// Если передан, показывается кнопка "Повторить"
  /// Обычно используется для сетевых ошибок
  final VoidCallback? onRetry;

  /// Текст кнопки повтора (по умолчанию "Повторить")
  final String retryButtonText;

  /// Показывать ли кнопку повтора для всех ошибок
  ///
  /// По умолчанию кнопка показывается только для сетевых ошибок
  /// Если true — кнопка показывается всегда
  final bool alwaysShowRetry;

  /// Кастомное сообщение об ошибке (имеет приоритет над error)
  final String? customMessage;

  /// Дополнительный контент под ошибкой (опционально)
  final Widget? additionalContent;

  /// Отступы вокруг виджета
  final EdgeInsets padding;

  /// Выравнивание контента
  final MainAxisAlignment mainAxisAlignment;

  /// Размер текста ошибки
  final double fontSize;

  const ErrorDisplay({
    super.key,
    this.error,
    this.onRetry,
    this.retryButtonText = 'Повторить',
    this.alwaysShowRetry = false,
    this.customMessage,
    this.additionalContent,
    this.padding = const EdgeInsets.all(16),
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.fontSize = 14,
  });

  /// Создает ErrorDisplay с центрированием (для полноэкранных ошибок)
  ///
  /// Используется когда ошибка занимает весь экран
  factory ErrorDisplay.centered({
    required dynamic error,
    VoidCallback? onRetry,
    String retryButtonText = 'Повторить',
    bool alwaysShowRetry = false,
    String? customMessage,
    Widget? additionalContent,
  }) {
    return ErrorDisplay(
      error: error,
      onRetry: onRetry,
      retryButtonText: retryButtonText,
      alwaysShowRetry: alwaysShowRetry,
      customMessage: customMessage,
      additionalContent: additionalContent,
      padding: const EdgeInsets.all(16),
      mainAxisAlignment: MainAxisAlignment.center,
    );
  }

  /// Создает ErrorDisplay для inline отображения (внутри формы)
  ///
  /// Используется для отображения ошибок под формами или в списках
  factory ErrorDisplay.inline({
    required dynamic error,
    VoidCallback? onRetry,
    String? customMessage,
  }) {
    return ErrorDisplay(
      error: error,
      onRetry: onRetry,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      mainAxisAlignment: MainAxisAlignment.start,
      fontSize: 13,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ────────── Получаем сообщение об ошибке ──────────
    final errorMessage = customMessage ?? ErrorHandler.format(error);

    // ────────── Определяем, показывать ли кнопку повтора ──────────
    final shouldShowRetry =
        alwaysShowRetry || (onRetry != null && ErrorHandler.canRetry(error));

    return Padding(
      padding: padding,
      child: Column(
        mainAxisAlignment: mainAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ────────── Текст ошибки ──────────
          SelectableText.rich(
            TextSpan(
              text: errorMessage,
              style: TextStyle(
                color: AppColors.error,
                fontSize: fontSize,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
              ),
            ),
            textAlign: TextAlign.center,
          ),

          // ────────── Дополнительный контент ──────────
          if (additionalContent != null) ...[
            const SizedBox(height: 16),
            additionalContent!,
          ],

          // ────────── Кнопка повтора ──────────
          if (shouldShowRetry && onRetry != null) ...[
            const SizedBox(height: 24),
            PrimaryButton(
              text: retryButtonText,
              onPressed: onRetry!,
              width: MediaQuery.of(context).size.width / 2,
            ),
          ],
        ],
      ),
    );
  }
}

/// Виджет для отображения ошибок в списках (Sliver)
///
/// Используется в CustomScrollView для отображения ошибок загрузки
///
/// Пример:
/// ```dart
/// if (error != null) {
///   return SliverToBoxAdapter(
///     child: ErrorDisplaySliver(
///       error: error,
///       onRetry: () => loadData(),
///     ),
///   );
/// }
/// ```
class ErrorDisplaySliver extends StatelessWidget {
  /// Ошибка для отображения
  final dynamic error;

  /// Колбэк для повторной попытки
  final VoidCallback? onRetry;

  /// Текст кнопки повтора
  final String retryButtonText;

  /// Кастомное сообщение
  final String? customMessage;

  const ErrorDisplaySliver({
    super.key,
    required this.error,
    this.onRetry,
    this.retryButtonText = 'Повторить',
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: ErrorDisplay.centered(
        error: error,
        onRetry: onRetry,
        retryButtonText: retryButtonText,
        customMessage: customMessage,
      ),
    );
  }
}

/// Виджет для отображения ошибок в формах (inline)
///
/// Используется под полями формы для отображения ошибок валидации
///
/// Пример:
/// ```dart
/// if (formState.error != null) {
///   return ErrorDisplayForm(
///     error: formState.error,
///   );
/// }
/// ```
class ErrorDisplayForm extends StatelessWidget {
  /// Ошибка для отображения
  final String? error;

  /// Отступы
  final EdgeInsets padding;

  const ErrorDisplayForm({
    super.key,
    this.error,
    this.padding = const EdgeInsets.only(top: 8, left: 16, right: 16),
  });

  @override
  Widget build(BuildContext context) {
    if (error == null || error!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: padding,
      child: SelectableText.rich(
        TextSpan(
          text: error,
          style: const TextStyle(
            color: AppColors.error,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}
