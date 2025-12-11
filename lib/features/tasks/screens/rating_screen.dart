// lib/features/tasks/screens/rating_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Экран «Рейтинг» с PaceAppBar + трехсегментная пилюля
// Переключение вкладок через PageView со свайпом и синхронизированной пилюлей.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bar.dart';

// Константы для анимации
const _kTabAnim = Duration(milliseconds: 300);
const _kTabCurve = Curves.easeOutCubic;

class RatingScreen extends ConsumerStatefulWidget {
  const RatingScreen({super.key});

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  int _index = 0; // 0 — «Подписки», 1 — «Все пользователи», 2 — «Город»
  late final PageController _page = PageController(initialPage: _index);

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _onSegChanged(int v) {
    if (_index == v) return;
    setState(() => _index = v);
    _page.animateToPage(v, duration: _kTabAnim, curve: _kTabCurve);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),

      // ─── Верхняя панель: глобальный PaceAppBar ───
      appBar: const PaceAppBar(title: 'Рейтинг', showBack: true),

      // ─── Пилюля под AppBar + контент вкладок со свайпом ───
      body: SafeArea(
        top: true,
        bottom: false, // Не скрываем нижнее навигационное меню
        child: Column(
          children: [
            const SizedBox(height: 14),

            // Трехсегментная пилюля
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SegmentedPill(
                left: 'Подписки',
                center: 'Все пользователи',
                right: 'Город',
                value: _index,
                onChanged: _onSegChanged,
              ),
            ),

            const SizedBox(height: 16),

            // PageView с тремя вкладками
            Expanded(
              child: Padding(
                // Добавляем padding снизу, чтобы контент не перекрывал нижнее меню
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.of(context).padding.bottom +
                      60, // высота нижнего меню + системный отступ
                ),
                child: PageView(
                  controller: _page,
                  physics: const BouncingScrollPhysics(),
                  allowImplicitScrolling: true,
                  onPageChanged: (i) {
                    if (_index == i) return; // гард от лишних setState
                    setState(() => _index = i);
                  },
                  children: const [
                    // TODO: заменить на реальные виджеты контента
                    _PlaceholderContent(
                      key: PageStorageKey('rating_subscriptions'),
                      label: 'Подписки',
                    ),
                    _PlaceholderContent(
                      key: PageStorageKey('rating_users'),
                      label: 'Все пользователи',
                    ),
                    _PlaceholderContent(
                      key: PageStorageKey('rating_city'),
                      label: 'Город',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ТРЕХСЕГМЕНТНАЯ ПИЛЮЛЯ
// ─────────────────────────────────────────────────────────────────────────────
/// Переключатель-пилюля (3 сегмента) — стиль как в market_screen.dart
class _SegmentedPill extends StatelessWidget {
  final String left;
  final String center;
  final String right;
  final int value;
  final ValueChanged<int> onChanged;

  const _SegmentedPill({
    required this.left,
    required this.center,
    required this.right,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Получаем цвета из темы
    final Color track = AppColors.getSurfaceColor(context);
    final Color border = AppColors.getBorderColor(context);
    final Color thumb = AppColors.getTextPrimaryColor(context);
    final Color textActive = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkSurface
        : AppColors.surface;
    final Color textInactive = AppColors.getTextPrimaryColor(context);

    // Размеры сегментов: "Подписки" и "Город" уже, "Все пользователи" шире
    // Используем flex: 12 для узких, flex: 20 для широкого (умножили на 10 для целых чисел)
    const int leftFlex = 12; // Подписки
    const int centerFlex = 20; // Все пользователи
    const int rightFlex = 12; // Город
    const double totalFlex =
        44.0; // leftFlex + centerFlex + rightFlex = 12 + 20 + 12

    // Вычисляем позицию и ширину капсулы в зависимости от выбранного сегмента
    // Для flex 12:20:12 (пропорции ~1.2:2.0:1.2):
    // - Подписки: начинается с 0, занимает leftFlex/totalFlex ширины
    // - Все пользователи: начинается с leftFlex/totalFlex, занимает centerFlex/totalFlex ширины
    // - Город: начинается с (leftFlex+centerFlex)/totalFlex, занимает rightFlex/totalFlex ширины

    double thumbStartPosition; // Позиция начала капсулы (0.0 - 1.0)
    double thumbWidthFactor; // Ширина капсулы (0.0 - 1.0)

    if (value == 0) {
      // Подписки (слева)
      thumbStartPosition = 0.0;
      thumbWidthFactor = leftFlex / totalFlex;
    } else if (value == 1) {
      // Все пользователи (центр)
      thumbStartPosition = leftFlex / totalFlex;
      thumbWidthFactor = centerFlex / totalFlex;
    } else {
      // Город (справа)
      thumbStartPosition = (leftFlex + centerFlex) / totalFlex;
      thumbWidthFactor = rightFlex / totalFlex;
    }

    // Пилюля на всю доступную ширину (с учетом padding)
    return SizedBox(
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: border, width: 1),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double pillWidth = constraints.maxWidth;
            final double thumbWidth = pillWidth * thumbWidthFactor;
            final double thumbLeft = pillWidth * thumbStartPosition;

            return Stack(
              children: [
                // ── Скольжащая «капсула» (thumb) с динамической шириной и позицией
                AnimatedPositioned(
                  left: thumbLeft,
                  width: thumbWidth,
                  top: 0,
                  bottom: 0,
                  duration: _kTabAnim,
                  curve: _kTabCurve,
                  child: Container(
                    decoration: BoxDecoration(
                      color: thumb,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                  ),
                ),

                // ── Текстовые кнопки поверх капсулы с разными flex значениями
                Row(
                  children: [
                    Expanded(
                      flex: leftFlex,
                      child: _SegButton(
                        text: left,
                        selected: value == 0,
                        activeTextColor: textActive,
                        inactiveTextColor: textInactive,
                        onTap: () => onChanged(0),
                      ),
                    ),
                    Expanded(
                      flex: centerFlex,
                      child: _SegButton(
                        text: center,
                        selected: value == 1,
                        activeTextColor: textActive,
                        inactiveTextColor: textInactive,
                        onTap: () => onChanged(1),
                      ),
                    ),
                    Expanded(
                      flex: rightFlex,
                      child: _SegButton(
                        text: right,
                        selected: value == 2,
                        activeTextColor: textActive,
                        inactiveTextColor: textInactive,
                        onTap: () => onChanged(2),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ВНУТРЕННЯЯ КНОПКА С ТЕКСТОМ
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected ? activeTextColor : inactiveTextColor,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ЗАГЛУШКА ДЛЯ КОНТЕНТА ВКЛАДОК
// ─────────────────────────────────────────────────────────────────────────────
/// Временный виджет-заглушка, будет заменен на реальный контент
class _PlaceholderContent extends StatelessWidget {
  final String label;

  const _PlaceholderContent({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: AppTextStyles.h17w6.copyWith(
          color: AppColors.getTextSecondaryColor(context),
        ),
      ),
    );
  }
}
