import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'more_menu_hub.dart';

/// Пункт всплывающего меню.
class MoreMenuItem {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final TextStyle? textStyle;

  const MoreMenuItem({
    required this.text,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.textStyle,
  });
}

/// Универсальное всплывающее меню на OverlayEntry, привязывается к anchorKey.
/// • Безопасно к перестройкам списка (не зависит от контекста карточки).
/// • С тенью, без разделителей между пунктами.
/// • Сам закрывается при тапе по фону/выборе пункта.
/// • Регистрируется в MoreMenuHub, чтобы можно было закрыть при скролле.
class MoreMenuOverlay {
  MoreMenuOverlay({
    required this.anchorKey,
    required this.items,
    this.width = 220,
    this.margin = 0,
    this.horizontalInset = 8,
    this.backgroundColor = AppColors.surface,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.md)),
    this.boxShadow = const [
      // тень по твоим спекам
      BoxShadow(color: AppColors.scrim20, blurRadius: 4, offset: Offset(0, 1)),
    ],
    this.innerPadding = const EdgeInsets.symmetric(vertical: 6),
  });

  final GlobalKey anchorKey;
  final List<MoreMenuItem> items;

  final double width;
  final double margin; // отступ от якоря
  final double horizontalInset; // защитные поля у краёв экрана
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final List<BoxShadow> boxShadow;
  final EdgeInsets innerPadding;

  OverlayEntry? _entry;

  bool get isShown => _entry != null;

  /// Закрыть меню (и отписаться из хаба).
  void hide() {
    if (_entry != null) {
      MoreMenuHub.unregister(hide);
      _entry!.remove();
      _entry = null;
    }
  }

  /// Показать меню.
  void show(BuildContext context) {
    if (_entry != null) return;

    final anchorCtx = anchorKey.currentContext;
    final overlay = Overlay.of(context, rootOverlay: true);
    if (anchorCtx == null) return;

    // ────────────────────────────────────────────────────────────────
    // 📏 ВЫЧИСЛЕНИЕ ШИРИНЫ ПО СОДЕРЖИМОМУ: находим самый длинный текст
    // ────────────────────────────────────────────────────────────────
    final textStyle = AppTextStyles.h14w4;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    double maxTextWidth = 0.0;
    for (final item in items) {
      textPainter.text = TextSpan(
        text: item.text,
        style: item.textStyle ?? textStyle,
      );
      textPainter.layout();
      if (textPainter.width > maxTextWidth) {
        maxTextWidth = textPainter.width;
      }
    }
    // Ширина = текст + padding horizontal (14*2) + иконка (18) + отступ (12)
    // + минимальные отступы для комфорта
    final computedWidth = maxTextWidth + 14 * 2 + 18 + 12 + 8;
    // Используем вычисленную ширину, но не меньше минимальной
    final menuWidth = computedWidth > width ? computedWidth : width;

    // Прямоугольник кнопки "…" в системе координат overlay.
    final anchorBox = anchorCtx.findRenderObject() as RenderBox;
    final overlayBox = overlay.context.findRenderObject() as RenderBox;

    final topLeft = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final bottomRight = anchorBox.localToGlobal(
      anchorBox.size.bottomRight(Offset.zero),
      ancestor: overlayBox,
    );
    final anchorRect = Rect.fromPoints(topLeft, bottomRight);
    final screenSize = overlayBox.size;

    // Высота меню = пункты (~48 на пункт) + паддинги.
    const itemHeight = 48.0;
    final double height =
        innerPadding.vertical +
        items.length * itemHeight +
        2;

    // Базовая позиция: под кнопкой, выравниваем по правому краю.
    double left = anchorRect.right - menuWidth;
    double top = anchorRect.bottom + margin;

    // Не вылезаем за края.
    if (left < horizontalInset) left = horizontalInset;
    if (left + menuWidth > screenSize.width - horizontalInset) {
      left = screenSize.width - horizontalInset - menuWidth;
    }

    // Если снизу не помещается — показываем над якорем.
    if (top + height > screenSize.height - horizontalInset) {
      top = anchorRect.top - margin - height;
      if (top < horizontalInset) top = horizontalInset;
    }

    // ── Получаем цвета в зависимости от темы
    final brightness = Theme.of(context).brightness;
    // ────────────────────────────────────────────────────────────────
    // 🌓 ТЕМНАЯ ТЕМА: фон меню такой же, как у попапа экипировки
    // ────────────────────────────────────────────────────────────────
    // Если backgroundColor равен дефолтному AppColors.surface,
    // используем адаптивный цвет (darkSurfaceMuted в темной теме)
    final bgColor = backgroundColor == AppColors.surface
        ? (brightness == Brightness.dark
              ? AppColors.darkSurfaceMuted
              : AppColors.getSurfaceColor(context))
        : backgroundColor;
    // Для темной темы используем более заметную тень
    final shadowColor = brightness == Brightness.dark
        ? AppColors.darkShadowSoft
        : AppColors.scrim20;
    final shadowList = [
      BoxShadow(color: shadowColor, blurRadius: 4, offset: const Offset(0, 1)),
    ];

    _entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // Тап по фону закрывает меню
          Positioned.fill(child: GestureDetector(onTap: hide)),
          // Сам попап
          Positioned(
            left: left,
            top: top,
            width: menuWidth,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: borderRadius,
                  boxShadow: shadowList,
                ),
                padding: innerPadding,
                child: _buildList(ctx),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_entry!);
    // Регистрируем себя в хабе, чтобы экран мог закрыть при скролле.
    MoreMenuHub.register(hide);
  }

  Widget _buildList(BuildContext ctx) {
    final children = <Widget>[];

    // ── Получаем цвета в зависимости от темы
    final textColor = AppColors.getTextPrimaryColor(ctx);
    final iconColor = AppColors.getIconPrimaryColor(ctx);

    for (int i = 0; i < items.length; i++) {
      final it = items[i];

      children.add(
        InkWell(
          onTap: () {
            hide(); // сперва закрываем меню
            it.onTap(); // потом действие
          },
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(it.icon, size: 18, color: it.iconColor ?? iconColor),
                const SizedBox(width: 12),
                Text(
                  it.text,
                  style:
                      it.textStyle ??
                      AppTextStyles.h14w4.copyWith(color: textColor),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }
}
