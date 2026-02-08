import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/static_map_url_builder.dart';
import '../../../../domain/models/activity_lenta.dart';

/// ────────────────────────────────────────────────────────────────
/// 🔹 МОДЕЛЬ ЭЛЕМЕНТА МЕДИА (ФОТО ИЛИ КАРТА)
/// ────────────────────────────────────────────────────────────────
class ShareMediaItem {
  final String? imageUrl;
  final bool isMap;
  final bool isAsset;

  const ShareMediaItem.photo(this.imageUrl)
      : isMap = false,
        isAsset = false;
  const ShareMediaItem.asset(this.imageUrl)
      : isMap = false,
        isAsset = true;
  const ShareMediaItem.map()
      : imageUrl = null,
        isMap = true,
        isAsset = false;
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 КОНТЕНТ НИЖНЕГО ЛИСТА (ПОВЕРХ ЭКРАНА, КАК В SEGMENT_DESCRIPTION)
/// ────────────────────────────────────────────────────────────────
/// Принимает scrollController и dragController от DraggableScrollableSheet.
class ShareActivityBottomSheetContent extends StatelessWidget {
  final ScrollController scrollController;
  final DraggableScrollableController dragController;
  final Activity activity;
  final List<ShareMediaItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueNotifier<Color> textColorNotifier;
  final ValueNotifier<Color> routeColorNotifier;
  final ValueNotifier<Color> iconColorNotifier;
  final ValueNotifier<double> routeLineWidthNotifier;
  final bool isMapSelected;
  final int displayModeIndex;
  final ValueChanged<int> onDisplayModeChanged;
  final bool isOpacitySelected;
  final ValueNotifier<double> darknessOpacityNotifier;
  final VoidCallback onSharePressed;
  // ────────────────────────────────────────────────────────────────
  // 🔹 ТИП ЗАГОЛОВКА МЕТРИК ДЛЯ ПЕРВОЙ МИНИАТЮРЫ: ТЕКСТ ИЛИ ИКОНКА
  // ────────────────────────────────────────────────────────────────
  final bool metricsHeaderAsIcon;
  final ValueChanged<bool> onMetricsHeaderTypeChanged;

  const ShareActivityBottomSheetContent({
    super.key,
    required this.scrollController,
    required this.dragController,
    required this.activity,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.textColorNotifier,
    required this.routeColorNotifier,
    required this.iconColorNotifier,
    required this.routeLineWidthNotifier,
    required this.isMapSelected,
    required this.displayModeIndex,
    required this.onDisplayModeChanged,
    required this.isOpacitySelected,
    required this.darknessOpacityNotifier,
    required this.onSharePressed,
    required this.metricsHeaderAsIcon,
    required this.onMetricsHeaderTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xll),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: AppSpacing.sm,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: CustomScrollView(
        controller: scrollController,
        physics: const BouncingScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: [
          // ────────────────────────────────────────────────────────
          // 🔹 ПЛАНКА-ХЭНДЛ ДЛЯ ПЕРЕТАСКИВАНИЯ
          // ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                dragController.animateTo(
                  0.5,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                ),
                child: Center(
                  child: Container(
                    width: AppSpacing.lg,
                    height: AppSpacing.xs,
                    decoration: BoxDecoration(
                      color: AppColors.getBorderColor(context),
                      borderRadius:
                          BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: _ShareSectionTitle(text: 'Фото для публикации'),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: _SharePhotoSelector(
              activity: activity,
              items: items,
              selectedIndex: selectedIndex,
              onSelected: onSelected,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
          SliverToBoxAdapter(
            child: _ShareColorSliderRow(
              title: 'Цвет текста',
              textColorNotifier: textColorNotifier,
            ),
          ),
          if (isOpacitySelected && displayModeIndex == 4) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverToBoxAdapter(
              child: _ShareColorSliderRow(
                title: 'Цвет иконки',
                textColorNotifier: iconColorNotifier,
              ),
            ),
          ],
          if (isMapSelected ||
              (isOpacitySelected && displayModeIndex == 5)) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverToBoxAdapter(
              child: _ShareColorSliderRow(
                title: 'Цвет маршрута',
                textColorNotifier: routeColorNotifier,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverToBoxAdapter(
              child: _ShareRouteLineWidthSlider(
                routeLineWidthNotifier: routeLineWidthNotifier,
                routeColorNotifier: routeColorNotifier,
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
          // ────────────────────────────────────────────────────────
          // 🔹 ТИП ЗАГОЛОВКА МЕТРИК: НАД «ВИД ОТОБРАЖЕНИЯ», ДЛЯ 1–4-Й И 6-Й
          // ────────────────────────────────────────────────────────
          if (displayModeIndex == 0 ||
              displayModeIndex == 1 ||
              displayModeIndex == 2 ||
              displayModeIndex == 3 ||
              displayModeIndex == 5) ...[
            SliverToBoxAdapter(
              child: _ShareMetricsHeaderTypeRow(
                useIcon: metricsHeaderAsIcon,
                onChanged: onMetricsHeaderTypeChanged,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
          SliverToBoxAdapter(
            child: _ShareSectionTitle(text: 'Вид отображения'),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: _ShareDisplayModeSelector(
              displayModeIndex: displayModeIndex,
              onSelected: onDisplayModeChanged,
              isOpacitySelected: isOpacitySelected,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          if (!isOpacitySelected) ...[
            SliverToBoxAdapter(
              child: _ShareDarknessSlider(
                darknessOpacityNotifier: darknessOpacityNotifier,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
          if (isOpacitySelected)
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: _ShareButton(onPressed: onSharePressed),
            ),
          ),
        ],
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 НИЖНИЙ БЛОК ЭКРАНА РЕПОСТА (СКРОЛЛИРУЕМЫЙ КОНТЕНТ, INLINE-ВАРИАНТ)
/// ────────────────────────────────────────────────────────────────
/// Используется только если экран не переведён на DraggableScrollableSheet.
class ShareActivityBottomSheet extends StatelessWidget {
  final Activity activity;
  final List<ShareMediaItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueNotifier<Color> textColorNotifier;
  final ValueNotifier<Color> routeColorNotifier;
  final ValueNotifier<Color> iconColorNotifier;
  final ValueNotifier<double> routeLineWidthNotifier;
  final bool isMapSelected;
  final int displayModeIndex;
  final ValueChanged<int> onDisplayModeChanged;
  final bool isOpacitySelected;
  final ValueNotifier<double> darknessOpacityNotifier;
  final VoidCallback onSharePressed;
  final bool metricsHeaderAsIcon;
  final ValueChanged<bool> onMetricsHeaderTypeChanged;

  const ShareActivityBottomSheet({
    super.key,
    required this.activity,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.textColorNotifier,
    required this.routeColorNotifier,
    required this.iconColorNotifier,
    required this.routeLineWidthNotifier,
    required this.isMapSelected,
    required this.displayModeIndex,
    required this.onDisplayModeChanged,
    required this.isOpacitySelected,
    required this.darknessOpacityNotifier,
    required this.onSharePressed,
    required this.metricsHeaderAsIcon,
    required this.onMetricsHeaderTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            const _ShareSectionTitle(text: 'Фото для публикации'),
            const SizedBox(height: 12),
            _SharePhotoSelector(
              activity: activity,
              items: items,
              selectedIndex: selectedIndex,
              onSelected: onSelected,
            ),
            const SizedBox(height: 28),
            _ShareColorSliderRow(
              title: 'Цвет текста',
              textColorNotifier: textColorNotifier,
            ),
            if (isOpacitySelected && displayModeIndex == 4) ...[
              const SizedBox(height: 28),
              _ShareColorSliderRow(
                title: 'Цвет иконки',
                textColorNotifier: iconColorNotifier,
              ),
            ],
            if (isMapSelected ||
                (isOpacitySelected && displayModeIndex == 5)) ...[
              const SizedBox(height: 28),
              _ShareColorSliderRow(
                title: 'Цвет маршрута',
                textColorNotifier: routeColorNotifier,
              ),
              const SizedBox(height: 28),
              _ShareRouteLineWidthSlider(
                routeLineWidthNotifier: routeLineWidthNotifier,
                routeColorNotifier: routeColorNotifier,
              ),
            ],
            const SizedBox(height: 28),
            if (displayModeIndex == 0 ||
                displayModeIndex == 1 ||
                displayModeIndex == 2 ||
                displayModeIndex == 3 ||
                displayModeIndex == 5) ...[
              _ShareMetricsHeaderTypeRow(
                useIcon: metricsHeaderAsIcon,
                onChanged: onMetricsHeaderTypeChanged,
              ),
              const SizedBox(height: 16),
            ],
            const _ShareSectionTitle(text: 'Вид отображения'),
            const SizedBox(height: 12),
            _ShareDisplayModeSelector(
              displayModeIndex: displayModeIndex,
              onSelected: onDisplayModeChanged,
              isOpacitySelected: isOpacitySelected,
            ),
            const SizedBox(height: 20),
            if (!isOpacitySelected) ...[
              _ShareDarknessSlider(
                darknessOpacityNotifier: darknessOpacityNotifier,
              ),
              const SizedBox(height: 28),
            ],
            if (isOpacitySelected) const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: _ShareButton(onPressed: onSharePressed),
            ),
          ],
        ),
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 ЗАГОЛОВОК СЕКЦИИ
/// ────────────────────────────────────────────────────────────────
class _ShareSectionTitle extends StatelessWidget {
  final String text;

  const _ShareSectionTitle({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: AppTextStyles.h15w4.copyWith(
            color: AppColors.getTextPrimaryColor(context),
          ),
        ),
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 ВЫБОР ЦВЕТА (ГРАДИЕНТНЫЙ ПОЛЗУНОК)
/// ────────────────────────────────────────────────────────────────
class _ShareColorSliderRow extends StatefulWidget {
  final String title;
  final ValueNotifier<Color> textColorNotifier;

  const _ShareColorSliderRow({
    required this.title,
    required this.textColorNotifier,
  });

  @override
  State<_ShareColorSliderRow> createState() => _ShareColorSliderRowState();
}

class _ShareColorSliderRowState extends State<_ShareColorSliderRow> {
  // ────────────────────────────────────────────────────────────────
  // 🔹 ПАЛИТРА ДЛЯ ГРАДИЕНТА (С БЕЛЫМ И ЧЕРНЫМ ПО КРАЯМ)
  // ────────────────────────────────────────────────────────────────
  static const List<Color> _gradientColors = [
    Colors.white,
    const Color(0xFFFF0000), // Чистый красный
    Colors.yellow,
    const Color(0xFF00FF00), // Ярко-зеленый
    Colors.cyan,
    const Color(0xFF0000FF), // Ярко-синий
    Colors.purple,
    Colors.black,
  ];

  // ────────────────────────────────────────────────────────────────
  // 🔹 ТЕКУЩЕЕ ПОЛОЖЕНИЕ ПОЛЗУНКА
  // ────────────────────────────────────────────────────────────────
  late double _sliderValue;
  bool _isInternalChange = false;

  @override
  void initState() {
    super.initState();
    _syncSliderWithNotifier();
    widget.textColorNotifier.addListener(_handleNotifierChange);
  }

  @override
  void didUpdateWidget(covariant _ShareColorSliderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textColorNotifier != widget.textColorNotifier) {
      oldWidget.textColorNotifier.removeListener(_handleNotifierChange);
      widget.textColorNotifier.addListener(_handleNotifierChange);
      _syncSliderWithNotifier();
    }
  }

  @override
  void dispose() {
    widget.textColorNotifier.removeListener(_handleNotifierChange);
    super.dispose();
  }

  void _handleNotifierChange() {
    if (!mounted || _isInternalChange) return;
    setState(() {
      _sliderValue =
          _closestValueForColor(widget.textColorNotifier.value);
    });
  }

  void _syncSliderWithNotifier() {
    _sliderValue = _closestValueForColor(widget.textColorNotifier.value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          Text(
            widget.title,
            style: AppTextStyles.h15w4.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // ────────────────────────────────────────────────────────
          // 🔹 ГРАДИЕНТНЫЙ ПОЛЗУНОК
          // ────────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: ValueListenableBuilder<Color>(
                valueListenable: widget.textColorNotifier,
                builder: (context, color, _) {
                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 8.0,
                    trackShape: _RainbowSliderTrackShape(
                        colors: _gradientColors,
                        borderColor: AppColors.getBorderColor(context),
                      ),
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10.0,
                    ),
                    thumbColor: color,
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 20.0,
                    ),
                    overlayColor: color.withValues(alpha: 0.12),
                    showValueIndicator: ShowValueIndicator.never,
                  ),
                  child: Slider(
                      value: _sliderValue,
                      min: 0,
                      max: 1,
                      divisions: 255,
                      onChanged: (value) {
                        setState(() {
                          _sliderValue = value;
                        });
                        _isInternalChange = true;
                        widget.textColorNotifier.value =
                            _colorFromValue(value);
                        _isInternalChange = false;
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ПОЛУЧАЕМ ЦВЕТ ИЗ ПОЛОЖЕНИЯ ПОЛЗУНКА
  // ────────────────────────────────────────────────────────────────
  Color _colorFromValue(double value) {
    final clampedValue = value.clamp(0.0, 1.0);
    final segment = 1.0 / (_gradientColors.length - 1);
    final index = (clampedValue / segment).floor().clamp(
          0,
          _gradientColors.length - 2,
        );
    final t = (clampedValue - (segment * index)) / segment;

    return Color.lerp(
          _gradientColors[index],
          _gradientColors[index + 1],
          t,
        ) ??
        _gradientColors.first;
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ПРИБЛИЗИТЕЛЬНОЕ СООТВЕТСТВИЕ ЦВЕТА ПОЛЗУНКУ
  // ────────────────────────────────────────────────────────────────
  double _closestValueForColor(Color color) {
    const samples = 60;
    var bestValue = 0.0;
    var bestDistance = double.infinity;

    for (var i = 0; i <= samples; i++) {
      final value = i / samples;
      final candidate = _colorFromValue(value);
      final distance = _colorDistance(candidate, color);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestValue = value;
      }
    }

    return bestValue;
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 МЕТРИКА РАССТОЯНИЯ В RGB
  // ────────────────────────────────────────────────────────────────
  double _colorDistance(Color a, Color b) {
    final dr = a.red - b.red;
    final dg = a.green - b.green;
    final db = a.blue - b.blue;

    return (dr * dr + dg * dg + db * db).toDouble();
  }
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 КАСТОМНАЯ ДОРОЖКА С ГРАДИЕНТОМ
/// ────────────────────────────────────────────────────────────────
class _RainbowSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  final List<Color> colors;
  final Color borderColor;

  const _RainbowSliderTrackShape({
    required this.colors,
    required this.borderColor,
  });

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    // ────────────────────────────────────────────────────────────────
    // 🔹 ЯВНО ИСПОЛЬЗУЕМ trackHeight ИЗ ТЕМЫ
    // ────────────────────────────────────────────────────────────────
    final trackHeight = sliderTheme.trackHeight ?? 8.0;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width;

    return Rect.fromLTWH(
      trackLeft,
      trackTop,
      trackWidth,
      trackHeight,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    // ────────────────────────────────────────────────────────────────
    // 🔹 ГЕОМЕТРИЯ ДОРОЖКИ
    // ────────────────────────────────────────────────────────────────
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    // ────────────────────────────────────────────────────────────────
    // 🔹 ГРАДИЕНТ ПО ВСЕЙ ДЛИНЕ
    // ────────────────────────────────────────────────────────────────
    final paint = Paint()
      ..shader = LinearGradient(
        colors: colors,
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(trackRect);

    final radius = Radius.circular(trackRect.height / 2);
    final rrect = RRect.fromRectAndRadius(trackRect, radius);
    context.canvas.drawRRect(rrect, paint);

    // ────────────────────────────────────────────────────────────────
    // 🔹 БОРДЕР ДЛЯ ЛУЧШЕЙ ВИДИМОСТИ ГРАДИЕНТА
    // ────────────────────────────────────────────────────────────────
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = borderColor;
    context.canvas.drawRRect(rrect, borderPaint);
  }
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 СЕКЦИЯ ВЫБОРА ВИДА ОТОБРАЖЕНИЯ
/// ────────────────────────────────────────────────────────────────
class _ShareDisplayModeSelector extends StatelessWidget {
  final int displayModeIndex;
  final ValueChanged<int> onSelected;
  final bool isOpacitySelected;

  const _ShareDisplayModeSelector({
    required this.displayModeIndex,
    required this.onSelected,
    this.isOpacitySelected = false,
  });

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────
    // 🔹 ПРОЗРАЧНЫЙ ФОН: 5-Я И 6-Я МИНИАТЮРЫ, ИНАЧЕ ТОЛЬКО 1-4
    // ────────────────────────────────────────────────────────────────
    final itemCount = isOpacitySelected ? 2 : 4;
    final startIndex = isOpacitySelected ? 4 : 0;

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final modeIndex = startIndex + index;
          final opacity = modeIndex == displayModeIndex ? 1.0 : 0.5;
          return GestureDetector(
            onTap: () => onSelected(modeIndex),
            behavior: HitTestBehavior.opaque,
            child: Opacity(
              opacity: opacity,
              child: _ShareDisplayModePreview(index: modeIndex),
            ),
          );
        },
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 ТИП ЗАГОЛОВКА МЕТРИК: ТЕКСТ ИЛИ ИКОНКА (ДЛЯ ПЕРВОЙ МИНИАТЮРЫ)
/// 🔹 Кастомный сегментированный контрол: контейнер и активный сегмент с xl
/// ────────────────────────────────────────────────────────────────
class _ShareMetricsHeaderTypeRow extends StatelessWidget {
  final bool useIcon;
  final ValueChanged<bool> onChanged;

  const _ShareMetricsHeaderTypeRow({
    required this.useIcon,
    required this.onChanged,
  });

  static const double _trackPadding = 3;

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.getTextPrimaryColor(context);
    final surfaceColor = AppColors.getSurfaceColor(context);
    final trackColor = AppColors.getBorderColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            'Тип заголовка',
            style: AppTextStyles.h15w4.copyWith(
              color: textColor,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                final w = constraints.maxWidth;
                final innerW = w - _trackPadding * 2;
                final halfW = innerW / 2;

                return Container(
                  padding: const EdgeInsets.all(_trackPadding),
                  decoration: BoxDecoration(
                    color: trackColor,
                    borderRadius:
                        BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(
                          milliseconds: 220,
                        ),
                        curve: Curves.easeInOut,
                        left: useIcon ? halfW : 0,
                        top: 0,
                        bottom: 0,
                        width: halfW,
                        child: Container(
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: useIcon
                                ? const BorderRadius.only(
                                    topRight:
                                        Radius.circular(
                                            AppRadius.xl),
                                    bottomRight:
                                        Radius.circular(
                                            AppRadius.xl),
                                  )
                                : const BorderRadius.only(
                                    topLeft:
                                        Radius.circular(
                                            AppRadius.xl),
                                    bottomLeft:
                                        Radius.circular(
                                            AppRadius.xl),
                                  ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  onChanged(false),
                              behavior:
                                  HitTestBehavior.opaque,
                              child: Padding(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Center(
                                  child: Text(
                                    'Текст',
                                    style: AppTextStyles
                                        .h13w4
                                        .copyWith(
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  onChanged(true),
                              behavior:
                                  HitTestBehavior.opaque,
                              child: Padding(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Center(
                                  child: Text(
                                    'Иконка',
                                    style: AppTextStyles
                                        .h13w4
                                        .copyWith(
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 МИНИАТЮРА ПРЕВЬЮ РЕЖИМА ОТОБРАЖЕНИЯ
/// ────────────────────────────────────────────────────────────────
class _ShareDisplayModePreview extends StatelessWidget {
  final int index;

  const _ShareDisplayModePreview({
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(255, 135, 206, 250),
                Color.fromARGB(255, 70, 130, 180),
                Color.fromARGB(255, 30, 90, 150),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
        // ────────────────────────────────────────────────────────
        // 🔹 ОВАЛЫ ДЛЯ ПЕРВОЙ МИНИАТЮРЫ
        // ────────────────────────────────────────────────────────
        if (index == 0) ...[
          Positioned(
            bottom: 12,
            left: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: List.generate(
                3,
                (_) => Container(
                  margin: const EdgeInsets.only(right: 4),
                  width: 20,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              width: 20,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
        // ────────────────────────────────────────────────────────
        // 🔹 ОВАЛЫ ДЛЯ ВТОРОЙ МИНИАТЮРЫ
        // ────────────────────────────────────────────────────────
        if (index == 1) ...[
          Positioned(
            top: 12,
            left: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: List.generate(
                3,
                (_) => Container(
                  margin: const EdgeInsets.only(right: 4),
                  width: 20,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              width: 20,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
        // ────────────────────────────────────────────────────────
        // 🔹 ОВАЛЫ ДЛЯ ТРЕТЬЕЙ МИНИАТЮРЫ
        // ────────────────────────────────────────────────────────
        if (index == 2) ...[
          Positioned(
            bottom: 12,
            left: 12,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: List.generate(
                3,
                (_) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  width: 20,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              width: 20,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
        // ────────────────────────────────────────────────────────
        // 🔹 ОВАЛЫ ДЛЯ ЧЕТВЕРТОЙ МИНИАТЮРЫ
        // ────────────────────────────────────────────────────────
        if (index == 3) ...[
          Positioned(
            bottom: 12,
            right: 12,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: List.generate(
                3,
                (_) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  width: 20,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              width: 20,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
        // ────────────────────────────────────────────────────────
        // 🔹 ОВАЛЫ ДЛЯ ПЯТОЙ МИНИАТЮРЫ (ВТОРОЙ — КРУЖОЧЕК)
        // ────────────────────────────────────────────────────────
        if (index == 4)
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    width: 20,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    width: 20,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    width: 20,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // ────────────────────────────────────────────────────────
        // 🔹 ШЕСТАЯ МИНИАТЮРА: КАК ПЯТАЯ, НО С МАРШРУТОМ ВМЕСТО ИКОНКИ
        // ────────────────────────────────────────────────────────
        if (index == 5)
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    width: 20,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  SizedBox(
                    width: 20,
                    height: 10,
                    child: CustomPaint(
                      painter: _RoutePreviewPainter(),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 20,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 20,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 ПРЕВЬЮ МАРШРУТА ДЛЯ МИНИАТЮРЫ
/// ────────────────────────────────────────────────────────────────
class _RoutePreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // ────────────────────────────────────────────────────────────────
    // 🔹 ПРОСТОЙ МАРШРУТ-ЭСКИЗ ДЛЯ ПРЕВЬЮ
    // ────────────────────────────────────────────────────────────────
    final path = ui.Path();
    path.moveTo(size.width * 0.1, size.height * 0.7);
    path.lineTo(size.width * 0.35, size.height * 0.35);
    path.lineTo(size.width * 0.6, size.height * 0.55);
    path.lineTo(size.width * 0.85, size.height * 0.25);

    // ────────────────────────────────────────────────────────────────
    // 🔹 РИСУЕМ ЛИНИЮ МАРШРУТА
    // ────────────────────────────────────────────────────────────────
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 СЛАЙДЕР ТОЛЩИНЫ ЛИНИИ МАРШРУТА
/// ────────────────────────────────────────────────────────────────
/// Цвет дорожки и ползунка синхронизирован с "Цвет маршрута"
class _ShareRouteLineWidthSlider extends StatelessWidget {
  final ValueNotifier<double> routeLineWidthNotifier;
  final ValueNotifier<Color> routeColorNotifier;

  const _ShareRouteLineWidthSlider({
    required this.routeLineWidthNotifier,
    required this.routeColorNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          Text(
            'Толщина линии',
            style: AppTextStyles.h15w4.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
          const SizedBox(width: 16),
          // ────────────────────────────────────────────────────────
          // 🔹 СМЕЩАЕМ СЛАЙДЕР К ПРАВОМУ КРАЮ СТРОКИ
          // ────────────────────────────────────────────────────────
          const Spacer(),
          Expanded(
            flex: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: ValueListenableBuilder<Color>(
                valueListenable: routeColorNotifier,
                builder: (context, routeColor, _) {
                  return SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 8.0,
                      trackShape: _VariableHeightSliderTrackShape(
                        borderColor: AppColors.getBorderColor(context),
                        trackColor: routeColor,
                      ),
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10.0,
                      ),
                      thumbColor: routeColor,
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 20.0,
                      ),
                      overlayColor: routeColor.withValues(alpha: 0.12),
                      showValueIndicator: ShowValueIndicator.never,
                    ),
                    child: ValueListenableBuilder<double>(
                      valueListenable: routeLineWidthNotifier,
                      builder: (context, lineWidth, child) {
                        return Slider(
                          value: lineWidth,
                          min: 1.0,
                          max: 5.0,
                          divisions: 40,
                          onChanged: (value) {
                            routeLineWidthNotifier.value = value;
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 СЛАЙДЕР ЗАТЕМНЕНИЯ ФОНА
/// ────────────────────────────────────────────────────────────────
class _ShareDarknessSlider extends StatelessWidget {
  final ValueNotifier<double> darknessOpacityNotifier;

  const _ShareDarknessSlider({
    required this.darknessOpacityNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          Text(
            'Затемнение фона',
            style: AppTextStyles.h15w4.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
          const SizedBox(width: 16),
          // ────────────────────────────────────────────────────────
          // 🔹 СМЕЩАЕМ СЛАЙДЕР К ПРАВОМУ КРАЮ СТРОКИ
          // ────────────────────────────────────────────────────────
          const Spacer(),
          Expanded(
            flex: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 8.0,
                  trackShape: _GradientSliderTrackShape(
                    borderColor: AppColors.getBorderColor(context),
                  ),
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10.0,
                  ),
                  thumbColor: AppColors.button,
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 20.0,
                  ),
                  overlayColor: AppColors.button.withValues(alpha: 0.12),
                  showValueIndicator: ShowValueIndicator.never,
                ),
                child: ValueListenableBuilder<double>(
                  valueListenable: darknessOpacityNotifier,
                  builder: (context, darknessOpacity, child) {
                    return Slider(
                      value: darknessOpacity,
                      min: 0.0,
                      max: 1.0,
                      divisions: 100,
                      onChanged: (value) {
                        darknessOpacityNotifier.value = value;
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 КНОПКА "ПОДЕЛИТЬСЯ"
/// ────────────────────────────────────────────────────────────────
class _ShareButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ShareButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.getSurfaceColor(context);

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.button,
        foregroundColor: textColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        shape: const StadiumBorder(),
        minimumSize: const Size(double.infinity, 50),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.center,
      ),
      child: Text(
        'Поделиться',
        style: AppTextStyles.h15w5.copyWith(
          color: textColor,
          height: 1.0,
        ),
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 СЕКЦИЯ ВЫБОРА ФОТО
/// ────────────────────────────────────────────────────────────────
class _SharePhotoSelector extends StatefulWidget {
  final Activity activity;
  final List<ShareMediaItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _SharePhotoSelector({
    required this.activity,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  State<_SharePhotoSelector> createState() => _SharePhotoSelectorState();
}

class _SharePhotoSelectorState extends State<_SharePhotoSelector> {
  double? _lastWidth;
  double _cachedItemSize = 0.0;

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────
    // 🔹 ПУСТОЕ СОСТОЯНИЕ: НЕТ ФОТО И НЕТ МАРШРУТА
    // ────────────────────────────────────────────────────────────────
    if (widget.items.isEmpty) {
      return Text(
        'Фотографий нет',
        style: AppTextStyles.h14w4.copyWith(
          color: AppColors.getTextSecondaryColor(context),
        ),
      );
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 ЛЕНТА МИНИАТЮР: КАК В ЭКРАНЕ РЕДАКТИРОВАНИЯ
    // ────────────────────────────────────────────────────────────────
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        if (_lastWidth != screenWidth) {
          _lastWidth = screenWidth;
          const separatorWidth = 12.0 * 2;
          final rawItemSize = (screenWidth - separatorWidth) / 3;
          _cachedItemSize =
              (rawItemSize - 16).clamp(0.0, double.infinity);
        }
        final itemSize = _cachedItemSize;

        return SizedBox(
          height: itemSize,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            itemCount: widget.items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final opacity = index == widget.selectedIndex ? 1.0 : 0.5;
              final isOpacityAsset = item.isAsset &&
                  item.imageUrl == 'assets/opacity.jpg';

              return GestureDetector(
                onTap: () => widget.onSelected(index),
                behavior: HitTestBehavior.opaque,
                child: Opacity(
                  opacity: opacity,
                  child: Stack(
                    children: [
                      item.isMap
                          ? _ShareMapItem(
                              points: widget.activity.points
                                  .map((c) => LatLng(c.lat, c.lng))
                                  .toList(),
                              size: itemSize,
                            )
                          : _SharePhotoItem(
                              imageUrl: item.imageUrl!,
                              size: itemSize,
                              isAsset: item.isAsset,
                            ),
                      // ────────────────────────────────────────────────
                      // 🔹 ТЕКСТ "ПРОЗРАЧНЫЙ ФОН" ДЛЯ opacity.jpg
                      // ────────────────────────────────────────────────
                      if (isOpacityAsset)
                        Positioned.fill(
                          child: Center(
                            child: Text(
                              'Прозрачный\nфон',
                              style: AppTextStyles.h12w4.copyWith(
                                color: AppColors.surface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 ЭЛЕМЕНТ ФОТО: МИНИАТЮРА
/// ────────────────────────────────────────────────────────────────
class _SharePhotoItem extends StatelessWidget {
  final String imageUrl;
  final double size;
  final bool isAsset;

  const _SharePhotoItem({
    required this.imageUrl,
    required this.size,
    this.isAsset = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: isAsset
            ? Image.asset(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.twinphoto,
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.photo,
                      size: 24,
                      color: AppColors.scrim20,
                    ),
                  ),
                ),
              )
            : Builder(
                builder: (context) {
                  final dpr = MediaQuery.of(context).devicePixelRatio;
                  final w = (size * dpr).round();

                  return CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: w,
                    maxWidthDiskCache: w,
                    placeholder: (context, url) => Container(
                      color: AppColors.twinphoto,
                      child: const Center(
                        child: CupertinoActivityIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.twinphoto,
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.photo,
                          size: 24,
                          color: AppColors.scrim20,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 ЭЛЕМЕНТ КАРТЫ: МИНИАТЮРА
/// ────────────────────────────────────────────────────────────────
class _ShareMapItem extends StatelessWidget {
  final List<LatLng> points;
  final double size;

  const _ShareMapItem({
    required this.points,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────
    // 🔹 ИСПОЛЬЗУЕМ ПОЛНЫЙ DPR ДЛЯ МАКСИМАЛЬНОГО КАЧЕСТВА
    // ────────────────────────────────────────────────────────────────
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final w = (size * dpr).round();
    final h = (size * dpr).round();

    // ────────────────────────────────────────────────────────────────
    // 🔹 УВЕЛИЧЕННЫЕ РАЗМЕРЫ ДЛЯ ЛУЧШЕГО КАЧЕСТВА НА RETINA-ДИСПЛЕЯХ
    // ────────────────────────────────────────────────────────────────
    final mapUrl = StaticMapUrlBuilder.fromPoints(
      points: points,
      widthPx: w.toDouble(),
      heightPx: h.toDouble(),
      strokeWidth: 4.0, // Увеличенная ширина линии для лучшей читаемости
      padding: 10.0,
      maxWidth: 800.0, // Увеличенный максимум для высокого качества
      maxHeight: 800.0, // Увеличенный максимум для высокого качества
    );

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: CachedNetworkImage(
          imageUrl: mapUrl,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high, // Высокое качество отображения
          memCacheWidth: w,
          memCacheHeight: h,
          maxWidthDiskCache: w,
          maxHeightDiskCache: h,
          placeholder: (context, url) => Container(
            color: AppColors.twinphoto,
            child: const Center(
              child: CupertinoActivityIndicator(),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: AppColors.twinphoto,
            child: const Center(
              child: Icon(
                CupertinoIcons.map,
                size: 24,
                color: AppColors.scrim20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 ДОРОЖКА СЛАЙДЕРА С ГРАДИЕНТОМ ОТ БЕЛОГО ДО ЧЕРНОГО
/// ────────────────────────────────────────────────────────────────
class _GradientSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  final Color borderColor;

  const _GradientSliderTrackShape({
    required this.borderColor,
  });

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 8.0;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    // ────────────────────────────────────────────────────────────────
    // 🔹 ГЕОМЕТРИЯ ДОРОЖКИ
    // ────────────────────────────────────────────────────────────────
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    // ────────────────────────────────────────────────────────────────
    // 🔹 РИСУЕМ ГРАДИЕНТ ОТ БЕЛОГО К ЧЕРНОМУ
    // ────────────────────────────────────────────────────────────────
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.white, Colors.black],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(trackRect);

    final radius = Radius.circular(trackRect.height / 2);
    final rrect = RRect.fromRectAndRadius(trackRect, radius);
    context.canvas.drawRRect(rrect, paint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = borderColor;
    context.canvas.drawRRect(rrect, borderPaint);
  }
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 ДОРОЖКА СЛАЙДЕРА С ПЕРЕМЕННОЙ ВЫСОТОЙ (3 ПИКСЕЛЯ СЛЕВА, 8 ПИКСЕЛЕЙ СПРАВА)
/// Цвет дорожки соответствует цвету маршрута (routeColor)
/// ────────────────────────────────────────────────────────────────
class _VariableHeightSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  final Color borderColor;
  final Color trackColor;

  const _VariableHeightSliderTrackShape({
    required this.borderColor,
    required this.trackColor,
  });

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    // ────────────────────────────────────────────────────────────────
    // 🔹 ИСПОЛЬЗУЕМ МАКСИМАЛЬНУЮ ВЫСОТУ ДЛЯ РАСЧЕТА ПРОСТРАНСТВА
    // ────────────────────────────────────────────────────────────────
    final maxHeight = 8.0;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - maxHeight) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, maxHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    // ────────────────────────────────────────────────────────────────
    // 🔹 ГЕОМЕТРИЯ ДОРОЖКИ
    // ────────────────────────────────────────────────────────────────
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    // ────────────────────────────────────────────────────────────────
    // 🔹 РИСУЕМ ДОРОЖКУ С ПЕРЕМЕННОЙ ВЫСОТОЙ: СЛЕВА 3 ПИКСЕЛЯ, СПРАВА 8 ПИКСЕЛЕЙ
    // ────────────────────────────────────────────────────────────────
    final minHeight = 3.0;
    final maxHeight = 8.0;
    final centerY = trackRect.top + trackRect.height / 2;

    // ────────────────────────────────────────────────────────────────
    // 🔹 СОЗДАЕМ PATH ДЛЯ ПЛАВНОЙ ДОРОЖКИ С ПЕРЕМЕННОЙ ВЫСОТОЙ
    // ────────────────────────────────────────────────────────────────
    final path = ui.Path();
    final leftX = trackRect.left;
    final rightX = trackRect.right;

    // ────────────────────────────────────────────────────────────────
    // 🔹 ВЕРХНЯЯ ЛИНИЯ: ЛИНЕЙНЫЙ ГРАДИЕНТ ОТ minHeight К maxHeight
    // ────────────────────────────────────────────────────────────────
    path.moveTo(leftX, centerY - minHeight / 2);
    path.lineTo(rightX, centerY - maxHeight / 2);

    // ────────────────────────────────────────────────────────────────
    // 🔹 ПРАВЫЙ КРАЙ: ПОЛУКРУГ С РАДИУСОМ maxHeight / 2
    // ────────────────────────────────────────────────────────────────
    path.arcToPoint(
      Offset(rightX, centerY + maxHeight / 2),
      radius: Radius.circular(maxHeight / 2),
      clockwise: true,
      largeArc: false,
    );

    // ────────────────────────────────────────────────────────────────
    // 🔹 НИЖНЯЯ ЛИНИЯ: ЛИНЕЙНЫЙ ГРАДИЕНТ ОТ maxHeight К minHeight
    // ────────────────────────────────────────────────────────────────
    path.lineTo(leftX, centerY + minHeight / 2);

    // ────────────────────────────────────────────────────────────────
    // 🔹 ЛЕВЫЙ КРАЙ: ПОЛУКРУГ С РАДИУСОМ minHeight / 2
    // ────────────────────────────────────────────────────────────────
    path.arcToPoint(
      Offset(leftX, centerY - minHeight / 2),
      radius: Radius.circular(minHeight / 2),
      clockwise: true,
      largeArc: false,
    );
    path.close();

    // ────────────────────────────────────────────────────────────────
    // 🔹 РИСУЕМ ЗАЛИВКУ ДОРОЖКИ (ЦВЕТ МАРШРУТА)
    // ────────────────────────────────────────────────────────────────
    final paint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.fill;
    context.canvas.drawPath(path, paint);

    // ────────────────────────────────────────────────────────────────
    // 🔹 РИСУЕМ БОРДЕР
    // ────────────────────────────────────────────────────────────────
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = borderColor;
    context.canvas.drawPath(path, borderPaint);
  }
}
