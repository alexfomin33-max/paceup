// lib/screens/lenta/widgets/activity/equipment/equipment_popup.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';

/// Попап экипировки, якорящийся к кнопке справа от чипа.
/// Поведение и размеры совпадают с исходным вариантом:
/// - 288×112, 2 строки по 56, тонкий разделитель 1px (#ECECEC)
/// - Появление с анимацией Fade + Scale(0.8→1.0, easeOutBack ~250мс)
/// - Позиция: стараемся показать НАД кнопкой; если не влезает — ПОД кнопкой.
/// - Горизонталь: прижимаем правым краем к кнопке; не выходим за границы экрана.
class EquipmentPopup {
  /// Показать попап, привязанный к виджету с [anchorKey].
  static void showAnchored(
    BuildContext context, {
    required GlobalKey anchorKey,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;
    final anchorContext = anchorKey.currentContext;
    if (anchorContext == null) return;

    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null) return;

    final size = box.size;
    final offset = box.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    const double popupW = 288;
    const double popupH = 114;

    // Горизонталь: выравниваем правым краем по кнопке, но в пределах экрана.
    double left = offset.dx + size.width - popupW;
    left = left.clamp(8.0, screenSize.width - popupW - 8.0);

    // Вертикаль: если над кнопкой хватает места — ставим над; иначе — под.
    final topWouldBe = offset.dy - popupH;
    final double top = (topWouldBe < 20)
        ? (offset.dy + size.height)
        : topWouldBe;

    late OverlayEntry entry;

    void close() {
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (_) => _AnimatedPopup(
        left: left,
        top: top,
        width: popupW,
        height: popupH,
        onDismiss: close,
      ),
    );

    overlay.insert(entry);
  }
}

class _AnimatedPopup extends StatefulWidget {
  final double left;
  final double top;
  final double width;
  final double height;
  final VoidCallback onDismiss;

  const _AnimatedPopup({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.onDismiss,
  });

  @override
  State<_AnimatedPopup> createState() => _AnimatedPopupState();
}

class _AnimatedPopupState extends State<_AnimatedPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    _scale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Тап по полупрозрачному фону — закрыть
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: FadeTransition(
              opacity: _fade.drive(Tween(begin: 0.0, end: 1.0)),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        Positioned(
          left: widget.left,
          top: widget.top,
          width: widget.width,
          height: widget.height,
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: widget.width,
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.textTertiary,
                        blurRadius: 8,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: const _PopupContent(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Контент попапа: 2 строки обуви по 56px и разделитель 1px.
class _PopupContent extends StatelessWidget {
  const _PopupContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _ShoeRow(
          imageAsset: 'assets/Hoka.png',
          name: 'Hoka One One Bondi 8',
          mileageKm: 836,
        ),
        Divider(height: 1, thickness: 1, color: AppColors.divider),
        _ShoeRow(
          imageAsset: 'assets/Anta.png',
          name: 'Anta M C202',
          mileageKm: 1204,
        ),
      ],
    );
  }
}

/// Одна строка 56px: слева 80px под картинку, справа — текстовый блок.
class _ShoeRow extends StatelessWidget {
  final String imageAsset;
  final String name;
  final int mileageKm;

  const _ShoeRow({
    required this.imageAsset,
    required this.name,
    required this.mileageKm,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Row(
        children: [
          // Слева 80×56
          Container(
            width: 80,
            height: 56,
            color: AppColors.surface,
            padding: const EdgeInsets.all(8),
            child: Image.asset(imageAsset, fit: BoxFit.fill),
          ),
          // Справа 208×56
          Expanded(
            child: Container(
              height: 56,
              color: AppColors.surface,
              padding: const EdgeInsets.only(left: 5, top: 8, right: 8),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$name\n',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.67,
                      ),
                    ),
                    const TextSpan(
                      text: 'Пробег: ',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        height: 2,
                      ),
                    ),
                    TextSpan(
                      text: '$mileageKm',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 2,
                      ),
                    ),
                    const TextSpan(
                      text: ' км',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        height: 1.64,
                      ),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
