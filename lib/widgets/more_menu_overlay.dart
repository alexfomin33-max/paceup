import 'package:flutter/cupertino.dart';
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
/// • С тенью и тонким разделителем между пунктами.
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
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.boxShadow = const [
      // тень по твоим спекам
      BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
    ],
    this.innerPadding = const EdgeInsets.symmetric(vertical: 6),
    this.dividerColor = AppColors.divider,
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
  final Color dividerColor;

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
    if (anchorCtx == null || overlay == null) return;

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

    // Высота меню = пункты (~48 на пункт) + паддинги + разделители (0.5).
    const itemHeight = 48.0;
    final double height =
        innerPadding.vertical +
        items.length * itemHeight +
        (items.length - 1) * 0.5 +
        2;

    // Базовая позиция: под кнопкой, выравниваем по правому краю.
    double left = anchorRect.right - width;
    double top = anchorRect.bottom + margin;

    // Не вылезаем за края.
    if (left < horizontalInset) left = horizontalInset;
    if (left + width > screenSize.width - horizontalInset) {
      left = screenSize.width - horizontalInset - width;
    }

    // Если снизу не помещается — показываем над якорем.
    if (top + height > screenSize.height - horizontalInset) {
      top = anchorRect.top - margin - height;
      if (top < horizontalInset) top = horizontalInset;
    }

    _entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // Тап по фону закрывает меню
          Positioned.fill(child: GestureDetector(onTap: hide)),
          // Сам попап
          Positioned(
            left: left,
            top: top,
            width: width,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: borderRadius,
                  boxShadow: boxShadow,
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

    for (int i = 0; i < items.length; i++) {
      final it = items[i];

      children.add(
        InkWell(
          onTap: () {
            hide(); // сперва закрываем меню
            it.onTap(); // потом действие
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    it.text,
                    style: it.textStyle ?? AppTextStyles.normaltext,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  it.icon,
                  size: 18,
                  color: it.iconColor ?? AppColors.iconPrimary,
                ),
              ],
            ),
          ),
        ),
      );

      // Тонкий разделитель между пунктами
      if (i != items.length - 1) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Divider(height: 8, thickness: 0.5, color: dividerColor),
          ),
        );
      }
    }

    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }
}
