// lib/widgets/segmented_pill.dart
// ─────────────────────────────────────────────────────────────────────────────
//                ГЛОБАЛЬНЫЙ ВИДЖЕТ: ДВУХСЕГМЕНТНАЯ «ПИЛЮЛЯ» ДЛЯ ТАБОВ
//  • Внешний вид адаптируется к теме: цвета автоматически меняются для светлой/темной темы
//  • Анимация "капсулы" (thumb) через AnimatedAlign (+ плавная кривая)
//  • API совместим с вашим локальным _SegmentedPill: left/right, value, onChanged
//  • Параметры настраиваются: размеры, цвета, длительность, кривая, haptics
//  • Важно: пока реализовано для 2 сегментов (левая/правая половины)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // для HapticFeedback
import '../theme/app_theme.dart'; // AppColors, AppRadius, AppTextStyles (ваши токены)

class SegmentedPill extends StatelessWidget {
  /// Текст левой вкладки.
  final String left;

  /// Текст правой вкладки.
  final String right;

  /// Текущий выбранный индекс (0 — левая, 1 — правая).
  final int value;

  /// Колбэк при смене вкладки.
  final ValueChanged<int> onChanged;

  /// Явная ширина виджета (если null — займёт доступную).
  final double? width;

  /// Высота «пилюли».
  final double height;

  /// Длительность анимации скольжения «капсулы».
  final Duration duration;

  /// Кривая анимации.
  final Curve curve;

  /// Цвет фона трека (по умолчанию — AppColors.surface).
  final Color? trackColor;

  /// Цвет рамки трека (по умолчанию — AppColors.border).
  final Color? borderColor;

  /// Цвет «капсулы» (по умолчанию — AppColors.textPrimary).
  final Color? thumbColor;

  /// Цвет текста у активной вкладки (по умолчанию — AppColors.surface).
  final Color? activeTextColor;

  /// Цвет текста у неактивной вкладки (по умолчанию — AppColors.textPrimary).
  final Color? inactiveTextColor;

  /// Тактильная отдача при переключении.
  final bool haptics;

  const SegmentedPill({
    super.key,
    required this.left,
    required this.right,
    required this.value,
    required this.onChanged,
    this.width = 280,
    this.height = 40,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
    this.trackColor,
    this.borderColor,
    this.thumbColor,
    this.activeTextColor,
    this.inactiveTextColor,
    this.haptics = false,
  }) : assert(value == 0 || value == 1, 'value должен быть 0 или 1');

  @override
  Widget build(BuildContext context) {
    // ── Значения по умолчанию из ваших дизайн-токенов (адаптируются к теме)
    final Color track = trackColor ?? AppColors.getSurfaceColor(context);
    final Color border = borderColor ?? AppColors.getBorderColor(context);
    final Color thumb = thumbColor ?? AppColors.getTextPrimaryColor(context);
    // Активный текст: контрастный к капсуле (в светлой теме белый, в темной — темный)
    final Color textActive = activeTextColor ?? 
        (Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.surface);
    // Неактивный текст: основной цвет текста темы
    final Color textInactive = inactiveTextColor ?? 
        AppColors.getTextPrimaryColor(context);

    // ── Корпус виджета
    final pill = SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          // ── Фон и рамка «пилюли»
          Container(
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: border, width: 1),
            ),
          ),

          // ── Скольжащая «капсула» (thumb), занимает половину ширины
          AnimatedAlign(
            alignment: value == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            duration: duration,
            curve: curve,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: thumb,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
              ),
            ),
          ),

          // ── Текстовые кнопки поверх капсулы
          Row(
            children: [
              Expanded(
                child: _SegButton(
                  text: left,
                  selected: value == 0,
                  activeTextColor: textActive,
                  inactiveTextColor: textInactive,
                  onTap: () {
                    if (value != 0) {
                      if (haptics) HapticFeedback.lightImpact();
                      onChanged(0);
                    }
                  },
                ),
              ),
              Expanded(
                child: _SegButton(
                  text: right,
                  selected: value == 1,
                  activeTextColor: textActive,
                  inactiveTextColor: textInactive,
                  onTap: () {
                    if (value != 1) {
                      if (haptics) HapticFeedback.lightImpact();
                      onChanged(1);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Semantics(
      // semantically: двухпозиционный переключатель
      toggled: value == 1,
      child: pill,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ВНУТРЕННЯЯ КНОПКА С ТЕКСТОМ (ЛЕВАЯ/ПРАВАЯ)
// ─────────────────────────────────────────────────────────────────────────────
class _SegButton extends StatelessWidget {
  final String text;
  final bool selected;
  final Color activeTextColor;
  final Color inactiveTextColor;
  final VoidCallback onTap;

  const _SegButton({
    required this.text,
    required this.selected,
    required this.activeTextColor,
    required this.inactiveTextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: text,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque, // вся половина кликабельна
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            // Активный/неактивный — через цвет и лёгкую смену веса
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected ? activeTextColor : inactiveTextColor,
            ),
          ),
        ),
      ),
    );
  }
}
