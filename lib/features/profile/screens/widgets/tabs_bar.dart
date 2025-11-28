import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Горизонтальные вкладки без индикатора (ползунка).
/// Синхронизируется с PageView через [value]; для будущей совместимости
/// параметр [page] оставлен, но здесь не используется.
/// Автопрокрутка гарантирует, что активная вкладка попадает в центр.
class TabsBar extends StatefulWidget {
  final int value;
  final double? page; // не используется, оставлено для совместимости
  final List<String> items;
  final ValueChanged<int> onChanged;

  const TabsBar({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.page,
  });

  @override
  State<TabsBar> createState() => _TabsBarState();
}

class _TabsBarState extends State<TabsBar> {
  final _scrollCtrl = ScrollController();

  // Предрасчёт ширин и позиций элементов для автопрокрутки
  late List<double> _itemWidths;
  late List<double> _cumLeft;

  static const _hPad = 12.0; // внутренний горизонтальный паддинг элемента
  static const _sep = 8.0; // расстояние между элементами
  static const _listPad = 2.0; // внешний паддинг ListView

  @override
  void initState() {
    super.initState();
    _recalculateMetrics();
    // После первой отрисовки прокрутим к активной вкладке
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _ensureVisible(widget.value, animate: false),
    );
  }

  @override
  void didUpdateWidget(covariant TabsBar old) {
    super.didUpdateWidget(old);
    if (old.items != widget.items) {
      _recalculateMetrics();
    }
    if (old.value != widget.value) {
      _ensureVisible(widget.value);
    }
  }

  void _recalculateMetrics() {
    final style = const TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );

    _itemWidths = widget.items
        .map((text) {
          final tp = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          return tp.size.width + _hPad * 2;
        })
        .toList(growable: false);

    _cumLeft = List<double>.filled(widget.items.length, 0);
    double x = _listPad;
    for (int i = 0; i < widget.items.length; i++) {
      _cumLeft[i] = x;
      x += _itemWidths[i] + _sep;
    }
  }

  void _ensureVisible(int index, {bool animate = true}) {
    if (!_scrollCtrl.hasClients || index < 0 || index >= widget.items.length) {
      return;
    }
    final viewport = _scrollCtrl.position;
    final left = _cumLeft[index];
    final right = left + _itemWidths[index];
    final center = (left + right) / 2;
    final target = (center - viewport.viewportDimension / 2).clamp(
      0.0,
      viewport.maxScrollExtent,
    );
    if (animate) {
      _scrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _scrollCtrl.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.getSurfaceColor(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 40,
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: _listPad),
              child: Row(
                children:
                    List.generate(widget.items.length, (i) {
                        final selected = i == widget.value;
                        return GestureDetector(
                          onTap: () => widget.onChanged(i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _hPad,
                            ),
                            child: Text(
                              widget.items[i],
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: selected
                                    ? AppColors.brandPrimary
                                    : AppColors.getTextPrimaryColor(context),
                              ),
                            ),
                          ),
                        );
                      }).expand((w) sync* {
                        yield w;
                        yield const SizedBox(width: _sep);
                      }).toList()
                      ..removeLast(),
              ),
            ),
          ),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: AppColors.getDividerColor(context),
          ),
        ],
      ),
    );
  }
}
