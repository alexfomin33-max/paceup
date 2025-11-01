// lib/widgets/primary_button.dart
// ─────────────────────────────────────────────────────────────────────────────
//                   ГЛОБАЛЬНАЯ КНОПКА PRIMARY (брендовая)
//  • Используется по всему приложению с единым стилем
//  • Поддерживает фиксированную ширину или "растянуться" на всю строку
//  • Есть состояние загрузки (isLoading) - блокирует нажатие во время загрузки
//  • Кнопка всегда активна, валидация полей выполняется при нажатии
//  • ВАЖНО: везде применяем ваши токены и Inter
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart'; // AppColors, AppRadius, AppTextStyles

class PrimaryButton extends StatelessWidget {
  /// Текст на кнопке
  final String text;

  /// Обработчик нажатия (обязателен)
  final VoidCallback onPressed;

  /// Растянуть кнопку на всю доступную ширину
  final bool expanded;

  /// Фиксированная ширина. Если задано — имеет приоритет над [expanded].
  final double? width;

  /// Высота кнопки
  final double height;

  /// Показать индикатор загрузки и запретить нажатие
  final bool isLoading;

  /// Иконка слева (опционально)
  final Widget? leading;

  /// Иконка справа (опционально)
  final Widget? trailing;

  /// Пользовательский текстовый стиль (по умолчанию — 15 / w500 / Inter)
  final TextStyle? textStyle;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.expanded = false,
    this.width,
    this.height = 44,
    this.isLoading = false,
    this.leading,
    this.trailing,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    // ── итоговая ширина
    final double? finalWidth = width ?? (expanded ? double.infinity : null);

    // ── если идёт загрузка — блокируем нажатие
    final bool canPress = !isLoading;

    // ── единый контент кнопки: ведущая иконка + текст + хвостовая иконка
    final Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: CupertinoActivityIndicator(radius: 9),
          ),
        if (!isLoading && leading != null)
          Padding(padding: const EdgeInsets.only(right: 10), child: leading!),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                textStyle ??
                const TextStyle(
                  // Интер по умолчанию уже задан темой, но дублируем на всякий
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.surface, // всегда белый текст
                ),
          ),
        ),
        if (!isLoading && trailing != null)
          Padding(padding: const EdgeInsets.only(left: 10), child: trailing!),
      ],
    );

    // ── динамический padding: для маленьких кнопок уменьшаем вертикальный отступ
    final double verticalPadding = height <= 40 ? 0 : 12;

    // ── сама кнопка (всегда активна, только isLoading может блокировать)
    final Widget button = ElevatedButton(
      onPressed: canPress ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: AppColors.surface,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: 28,
          vertical: verticalPadding,
        ),
        shape: const StadiumBorder(), // «капсула» как у вас в дизайне
        minimumSize: Size(0, height), // фиксируем высоту
        tapTargetSize:
            MaterialTapTargetSize.shrinkWrap, // убираем лишний тап-таргет
      ),
      child: content,
    );

    // ── задаём ширину контейнером-обёрткой
    return SizedBox(width: finalWidth, height: height, child: button);
  }
}
