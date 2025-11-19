// lib/screens/lenta/widgets/activity/equipment/equipment_popup.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../models/activity_lenta.dart' as al;

/// Попап экипировки, якорящийся к кнопке справа от чипа.
/// Поведение и размеры совпадают с исходным вариантом:
/// - 288×112, 2 строки по 56, тонкий разделитель 1px (#ECECEC)
/// - Появление с анимацией Fade + Scale(0.8→1.0, easeOutBack ~250мс)
/// - Позиция: стараемся показать НАД кнопкой; если не влезает — ПОД кнопкой.
/// - Горизонталь: прижимаем правым краем к кнопке; не выходим за границы экрана.
class EquipmentPopup {
  /// Показать попап, привязанный к виджету с [anchorKey].
  /// Использует реальные данные из [items] вместо жестко вбитых значений.
  static void showAnchored(
    BuildContext context, {
    required GlobalKey anchorKey,
    required List<al.Equipment> items,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final anchorContext = anchorKey.currentContext;
    if (anchorContext == null) return;

    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null) return;

    final size = box.size;
    final offset = box.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    const double popupW = 288;
    // ────────────────────────────────────────────────────────────────
    // 📏 ДИНАМИЧЕСКАЯ ВЫСОТА: вычисляем на основе количества элементов
    // ────────────────────────────────────────────────────────────────
    // Каждый элемент: 56px, разделители: 1px между элементами
    // Минимум 1 элемент (56px), максимум ограничиваем разумным значением
    final itemCount = items.length.clamp(1, 5); // максимум 5 элементов
    final double popupH = (itemCount * 56.0) + ((itemCount - 1) * 1.0);

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
        items: items,
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
  final List<al.Equipment> items;

  const _AnimatedPopup({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.onDismiss,
    required this.items,
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
                  child: _PopupContent(items: widget.items),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Контент попапа: строки экипировки по 56px и разделители 1px.
/// ────────────────────────────────────────────────────────────────
/// 📦 ИСПОЛЬЗОВАНИЕ ДАННЫХ ИЗ БД: используем реальные данные из items
/// ────────────────────────────────────────────────────────────────
class _PopupContent extends StatelessWidget {
  final List<al.Equipment> items;

  const _PopupContent({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    // ────────────────────────────────────────────────────────────────
    // 📏 ОГРАНИЧЕНИЕ КОЛИЧЕСТВА: показываем максимум 5 элементов
    // ────────────────────────────────────────────────────────────────
    final displayItems = items.take(5).toList();
    final List<Widget> children = [];
    for (int i = 0; i < displayItems.length; i++) {
      if (i > 0) {
        children.add(
          const Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.divider,
            indent: 8,
            endIndent: 8,
          ),
        );
      }
      final item = displayItems[i];
      children.add(
        _ShoeRow(
          imageUrl: item.img,
          name: item.name,
          mileageKm: item.mileage,
        ),
      );
    }

    return Column(children: children);
  }
}

/// Одна строка 56px: слева 80px под картинку, справа — текстовый блок.
/// ────────────────────────────────────────────────────────────────
/// 📦 ИСПОЛЬЗОВАНИЕ ДАННЫХ ИЗ БД: используем imageUrl из API
/// ────────────────────────────────────────────────────────────────
class _ShoeRow extends StatelessWidget {
  final String imageUrl;
  final String name;
  final int mileageKm;

  const _ShoeRow({
    required this.imageUrl,
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
          // Слева 80×56 - изображение из БД или заглушка
          Container(
            width: 80,
            height: 56,
            color: AppColors.surface,
            padding: const EdgeInsets.all(8),
            child: imageUrl.isNotEmpty
                ? Builder(
                    builder: (context) {
                      final dpr = MediaQuery.of(context).devicePixelRatio;
                      final w = (64 * dpr).round();
                      return CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        memCacheWidth: w,
                        maxWidthDiskCache: w,
                        placeholder: (context, url) => Container(
                          color: AppColors.background,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.background,
                          child: const Icon(
                            Icons.sports_soccer,
                            size: 32,
                            color: AppColors.iconSecondary,
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    color: AppColors.background,
                    child: const Icon(
                      Icons.sports_soccer,
                      size: 32,
                      color: AppColors.iconSecondary,
                    ),
                  ),
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
                      text: "$name\n",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.7,
                      ),
                    ),
                    const TextSpan(
                      text: "Пробег: ",
                      style: AppTextStyles.h11w4Sec,
                    ),
                    TextSpan(text: "$mileageKm", style: AppTextStyles.h12w5),
                    const TextSpan(text: " км", style: AppTextStyles.h11w4Sec),
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
