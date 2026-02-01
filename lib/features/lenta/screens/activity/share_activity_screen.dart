// lib/features/lenta/screens/activity/share_activity_screen.dart
import 'dart:developer';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/activity_format.dart';
import '../../../../core/utils/static_map_url_builder.dart';
import '../../../../core/widgets/app_bar.dart';
import '../../../../domain/models/activity_lenta.dart';

/// ────────────────────────────────────────────────────────────────
/// 🔹 ЭКРАН ПОДГОТОВКИ РЕПОСТА ТРЕНИРОВКИ
/// ────────────────────────────────────────────────────────────────
/// Содержит:
/// 1) AppBar с заголовком "Настройка"
/// 2) Верхнюю картинку (как в карточке тренировки)
/// 3) Заголовок выбора фото
/// 4) Миниатюры фото с подсветкой первой
/// ────────────────────────────────────────────────────────────────
class ShareActivityScreen extends StatefulWidget {
  final Activity activity;

  const ShareActivityScreen({
    super.key,
    required this.activity,
  });

  @override
  State<ShareActivityScreen> createState() => _ShareActivityScreenState();
}

class _ShareActivityScreenState extends State<ShareActivityScreen> {
  // ────────────────────────────────────────────────────────────────
  // 🔹 ДАННЫЕ МЕДИА И ВЫБОР
  // ────────────────────────────────────────────────────────────────
  late final List<_ShareMediaItem> _mediaItems;
  late int _selectedIndex;
  int _displayModeIndex = 0;
  // ────────────────────────────────────────────────────────────────
  // 🔹 КЛЮЧ ДЛЯ ЗАХВАТА ВЕРХНЕГО ИЗОБРАЖЕНИЯ
  // ────────────────────────────────────────────────────────────────
  final GlobalKey _shareImageKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // ────────────────────────────────────────────────────────────────
    // 🔹 ФОРМИРУЕМ ЕДИНЫЙ СПИСОК МЕДИА
    // ────────────────────────────────────────────────────────────────
    _mediaItems = _buildMediaItems(widget.activity);
    _selectedIndex = _mediaItems.isNotEmpty ? 0 : -1;
  }

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────
    // 🔹 ОГРАНИЧИВАЕМ СПИСОК 3 ЭЛЕМЕНТАМИ
    // ────────────────────────────────────────────────────────────────
    final visibleItems = _mediaItems.take(3).toList(growable: false);
    final selectedItem = (_selectedIndex >= 0 &&
            _selectedIndex < visibleItems.length)
        ? visibleItems[_selectedIndex]
        : null;

    // ────────────────────────────────────────────────────────────────
    // 🔹 ОСНОВНОЙ КОНТЕЙНЕР ЭКРАНА
    // ────────────────────────────────────────────────────────────────
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PaceAppBar(
        title: 'Настройка',
        backgroundColor: AppColors.surface,
        showBottomDivider: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ────────────────────────────────────────────────────────
              // 🖼️ ВЕРХНЕЕ ИЗОБРАЖЕНИЕ (КАК В КАРТОЧКЕ)
              // ────────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: RepaintBoundary(
                  key: _shareImageKey,
                  child: _ShareTopImage(
                    activity: widget.activity,
                    selectedItem: selectedItem,
                    heightFactor: 1.0, // Чуть меньше по высоте
                    displayModeIndex: _displayModeIndex,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ────────────────────────────────────────────────────────
              // 🏷️ ЗАГОЛОВОК СЕКЦИИ ВЫБОРА
              // ────────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Фото для публикации',
                    style: AppTextStyles.h15w4.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ────────────────────────────────────────────────────────
              // 📸 МИНИАТЮРЫ МЕДИА: ВЫБРАННАЯ 100%, ОСТАЛЬНЫЕ 50%
              // ────────────────────────────────────────────────────────
              _SharePhotoSelector(
                activity: widget.activity,
                items: visibleItems,
                selectedIndex: _selectedIndex,
                onSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
              ),
              const SizedBox(height: 24),

              // ────────────────────────────────────────────────────────
              // 🧩 ВИД ОТОБРАЖЕНИЯ: ЗАГОЛОВОК
              // ────────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Вид отображения',
                    style: AppTextStyles.h15w4.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ────────────────────────────────────────────────────────
              // 🧩 ВИД ОТОБРАЖЕНИЯ: 4 ПЛЕЙСХОЛДЕРА
              // ────────────────────────────────────────────────────────
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 16),
                  itemCount: 4,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final opacity = index == _displayModeIndex ? 1.0 : 0.5;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _displayModeIndex = index;
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Opacity(
                        opacity: opacity,
                        child: Stack(
                          children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color.fromARGB(255, 135, 206, 250), // Светлый голубой
                                  const Color.fromARGB(255, 70, 130, 180), // Средний голубой
                                  const Color.fromARGB(255, 30, 90, 150), // Темный синий
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                          ),
                          // ────────────────────────────────────────────────────────
                          // 🔹 ОВАЛЫ ДЛЯ ПЕРВОЙ МИНИАТЮРЫ: 3 СНИЗУ СЛЕВА, 1 СВЕРХУ СПРАВА
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
                          // 🔹 ОВАЛЫ ДЛЯ ВТОРОЙ МИНИАТЮРЫ: 3 СВЕРХУ СЛЕВА, 1 СНИЗУ СПРАВА
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
                          // 🔹 ОВАЛЫ ДЛЯ ТРЕТЬЕЙ МИНИАТЮРЫ: 3 ВЕРТИКАЛЬНО СЛЕВА СНИЗУ, 1 СВЕРХУ СПРАВА
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
                          // 🔹 ОВАЛЫ ДЛЯ ЧЕТВЕРТОЙ МИНИАТЮРЫ: 3 ВЕРТИКАЛЬНО СПРАВА СНИЗУ, 1 СЛЕВА СВЕРХУ
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
                        ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),

              // ────────────────────────────────────────────────────────
              // 🔹 КНОПКА "ПОДЕЛИТЬСЯ"
              // ────────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: _buildShareButton(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Кнопка "Поделиться" в стиле кнопки "Добавить"
  Widget _buildShareButton(BuildContext context) {
    final textColor = AppColors.getSurfaceColor(context);

    return ElevatedButton(
      onPressed: _onSharePressed,
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

  // ────────────────────────────────────────────────────────────────
  // 🔹 НАЖАТИЕ "ПОДЕЛИТЬСЯ": ЗАХВАТ + СИСТЕМНЫЙ БОТТОМ-ШИТ
  // ────────────────────────────────────────────────────────────────
  Future<void> _onSharePressed() async {
    // ────────────────────────────────────────────────────────────────
    // 🔹 ЗАХВАТЫВАЕМ ИЗОБРАЖЕНИЕ С ТЕКУЩИМ РАСПОЛОЖЕНИЕМ ОВЕРЛЕЕВ
    // ────────────────────────────────────────────────────────────────
    final bytes = await _captureShareImageBytes();
    if (bytes == null || bytes.isEmpty) {
      log(
        'Не удалось сформировать изображение для шаринга',
      );
      return;
    }
    if (!mounted) return;

    // ────────────────────────────────────────────────────────────────
    // 🔹 ОТКРЫВАЕМ НАТИВНЫЙ БОТТОМ-ШИТ ПОДЕЛИТЬСЯ
    // ────────────────────────────────────────────────────────────────
    final box = context.findRenderObject() as RenderBox?;
    try {
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: 'paceup_share.png',
            mimeType: 'image/png',
          ),
        ],
        sharePositionOrigin: box == null
            ? Rect.zero
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e, stackTrace) {
      log(
        'Ошибка открытия шаринга изображения',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ЗАХВАТ ВЕРХНЕГО ИЗОБРАЖЕНИЯ В PNG-БАЙТЫ
  // ────────────────────────────────────────────────────────────────
  Future<Uint8List?> _captureShareImageBytes() async {
    // ────────────────────────────────────────────────────────────────
    // 🔹 ПОЛУЧАЕМ RepaintBoundary ДЛЯ СНИМКА
    // ────────────────────────────────────────────────────────────────
    final renderObject = _shareImageKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      log(
        'RenderRepaintBoundary не найден для захвата изображения',
      );
      return null;
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 РЕНДЕР В PNG С УЧЕТОМ PIXEL RATIO
    // ────────────────────────────────────────────────────────────────
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    return byteData?.buffer.asUint8List();
  }
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 ВЕРХНЕЕ ИЗОБРАЖЕНИЕ: ФОТО/КАРТА/ДЕФОЛТ
/// ────────────────────────────────────────────────────────────────
class _ShareTopImage extends StatelessWidget {
  final Activity activity;
  final _ShareMediaItem? selectedItem;
  final double heightFactor;
  final int displayModeIndex;

  const _ShareTopImage({
    required this.activity,
    required this.selectedItem,
    this.heightFactor = 1.1,
    required this.displayModeIndex,
  });

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────
    // 🔹 РАССЧЕТ ВЫСОТЫ ПО ПРОПОРЦИИ 1:1.1 (КАК В КАРТОЧКЕ)
    // ────────────────────────────────────────────────────────────────
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width * heightFactor;

        return SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                _buildTopImageContent(context, width, height),
                // ────────────────────────────────────────────────────────
                // 🌑 ТЕМНЫЙ ГРАДИЕНТ: позиция зависит от выбранного вида
                // ────────────────────────────────────────────────────────
                if (displayModeIndex != 2 && displayModeIndex != 3)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: displayModeIndex == 1 ? 0 : null,
                    bottom: displayModeIndex == 1 ? null : 0,
                    height: 140,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: displayModeIndex == 1
                                ? Alignment.bottomCenter
                                : Alignment.topCenter,
                            end: displayModeIndex == 1
                                ? Alignment.topCenter
                                : Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(
                              alpha: displayModeIndex == 0 ? 0.15 : 0.15,
                            ),
                          ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // ────────────────────────────────────────────────────────
                // 🌑 ЛЕГКИЙ ГРАДИЕНТ: позиция зависит от выбранного вида
                // ────────────────────────────────────────────────────────
                if (displayModeIndex != 2 && displayModeIndex != 3)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: displayModeIndex == 1 ? null : 0,
                    bottom: displayModeIndex == 1 ? 0 : null,
                    height: 80,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: displayModeIndex == 1
                                ? Alignment.bottomCenter
                                : Alignment.topCenter,
                            end: displayModeIndex == 1
                                ? Alignment.topCenter
                                : Alignment.bottomCenter,
                            colors: [
                            Colors.black.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // ────────────────────────────────────────────────────────
                // 🌑 ЛЕГКИЙ ГРАДИЕНТ СВЕРХУ: для 3-го и 4-го вида
                // ────────────────────────────────────────────────────────
                if (displayModeIndex == 2 || displayModeIndex == 3)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 80,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // ────────────────────────────────────────────────────────
                // 🌑 ЛЕГКИЙ ГРАДИЕНТ СЛЕВА: для читабельности на светлом фоне
                // ────────────────────────────────────────────────────────
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: width * 0.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // ────────────────────────────────────────────────────────
                // 🌑 ЛЕГКИЙ ГРАДИЕНТ СПРАВА: симметрично левому
                // ────────────────────────────────────────────────────────
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: width * 0.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // ────────────────────────────────────────────────────────
                // 🖼️ ОВЕРЛЕЙ ИЗ АССЕТОВ: позиция зависит от выбранного вида
                // ────────────────────────────────────────────────────────
                // ────────────────────────────────────────────────────────
                // 🧩 ПОЗИЦИЯ ЛОГОТИПА: 4-ЫЙ ВИД — СЛЕВА СВЕРХУ
                // ────────────────────────────────────────────────────────
                Positioned(
                  top: displayModeIndex == 1
                      ? null
                      : (displayModeIndex == 0 ||
                              displayModeIndex == 2 ||
                              displayModeIndex == 3)
                          ? 16
                          : 12,
                  bottom: displayModeIndex == 1 ? 12 : null,
                  left: displayModeIndex == 3 ? 16 : null,
                  right: displayModeIndex == 3 ? null : 20,
                  child: Image.asset(
                    'assets/gorizont.png',
                    width: 100,
                    fit: BoxFit.contain,
                  ),
                ),
                // ────────────────────────────────────────────────────────
                // 🧩 МЕТРИКИ: 4-ЫЙ ВИД — ВЕРТИКАЛЬНО СНИЗУ СПРАВА
                // ────────────────────────────────────────────────────────
                if (displayModeIndex == 2)
                  Positioned(
                    left: 16,
                    bottom: 12,
                    child: _buildOverlayMetricsColumn(context),
                  )
                else if (displayModeIndex == 3)
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: _buildOverlayMetricsColumn(
                      context,
                      isRightAligned: true,
                    ),
                  )
                else
                  Positioned(
                    left: 16,
                    right: 16,
                    top: displayModeIndex == 1 ? 12 : null,
                    bottom: displayModeIndex == 1 ? null : 12,
                    child: _buildOverlayMetricsRow(context),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 КОНТЕНТ ИЗОБРАЖЕНИЯ: ФОТО → КАРТА → ДЕФОЛТ
  // ────────────────────────────────────────────────────────────────
  Widget _buildTopImageContent(
    BuildContext context,
    double width,
    double height,
  ) {
    // ────────────────────────────────────────────────────────────────
    // 🔹 ЕСЛИ ВЫБРАН КОНКРЕТНЫЙ ЭЛЕМЕНТ — ПОКАЗЫВАЕМ ЕГО
    // ────────────────────────────────────────────────────────────────
    if (selectedItem != null) {
      if (selectedItem!.isMap && activity.points.isNotEmpty) {
        return _buildMapImage(context, width, height);
      }
      if (!selectedItem!.isMap && selectedItem!.imageUrl != null) {
        return _buildPhotoImage(
          context,
          width,
          height,
          selectedItem!.imageUrl!,
        );
      }
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 1. ЕСЛИ ЕСТЬ ФОТО — ПОКАЗЫВАЕМ ПЕРВОЕ
    // ────────────────────────────────────────────────────────────────
    if (activity.mediaImages.isNotEmpty) {
      return _buildPhotoImage(
        context,
        width,
        height,
        activity.mediaImages.first,
      );
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 2. ЕСЛИ ФОТО НЕТ, НО ЕСТЬ МАРШРУТ — ПОКАЗЫВАЕМ КАРТУ
    // ────────────────────────────────────────────────────────────────
    if (activity.points.isNotEmpty) {
      return _buildMapImage(context, width, height);
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 3. ЕСЛИ НЕТ ФОТО И МАРШРУТА — ДЕФОЛТНАЯ КАРТИНКА
    // ────────────────────────────────────────────────────────────────
    final defaultImagePath = getDefaultNoRouteImagePath(activity.type);

    return Image.asset(
      defaultImagePath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppColors.twinphoto,
        child: const Center(
          child: Icon(
            CupertinoIcons.photo,
            size: 40,
            color: AppColors.scrim20,
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ПОСТРОЕНИЕ ФОТО
  // ────────────────────────────────────────────────────────────────
  Widget _buildPhotoImage(
    BuildContext context,
    double width,
    double height,
    String imageUrl,
  ) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final w = (width * dpr).round();
    final h = (height * dpr).round();

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
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
            CupertinoIcons.photo,
            size: 40,
            color: AppColors.scrim20,
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ПОСТРОЕНИЕ КАРТЫ
  // ────────────────────────────────────────────────────────────────
  Widget _buildMapImage(
    BuildContext context,
    double width,
    double height,
  ) {
    final points = activity.points.map((c) => LatLng(c.lat, c.lng)).toList();

    final dpr = MediaQuery.of(context).devicePixelRatio;
    final optimizedDpr = (dpr > 1.5 ? 1.5 : dpr).clamp(1.0, 1.5);
    final w = (width * optimizedDpr).round();
    final h = (height * optimizedDpr).round();

    final mapUrl = StaticMapUrlBuilder.fromPoints(
      points: points,
      widthPx: w.toDouble(),
      heightPx: h.toDouble(),
      strokeWidth: 3.0,
      padding: 12.0,
      maxWidth: 1280.0,
      maxHeight: 1280.0,
    );

    return CachedNetworkImage(
      imageUrl: mapUrl,
      fit: BoxFit.cover,
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
            size: 40,
            color: AppColors.scrim20,
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 МЕТРИКИ ПОВЕРХ ФОТО: БЕЗ ТЕМНОГО ГРАДИЕНТА
  // ────────────────────────────────────────────────────────────────
  Widget _buildOverlayMetricsRow(BuildContext context) {
    final stats = activity.stats;
    final activityTypeLower = activity.type.toLowerCase();
    final isSwim =
        activityTypeLower == 'swim' || activityTypeLower == 'swimming';
    final isBike =
        activityTypeLower == 'bike' ||
        activityTypeLower == 'bicycle' ||
        activityTypeLower == 'cycling' ||
        activityTypeLower == 'indoor-cycling';

    String formatSwimDistance(double meters) {
      final value = meters.toStringAsFixed(0);
      final buffer = StringBuffer();
      for (int i = 0; i < value.length; i++) {
        if (i > 0 && (value.length - i) % 3 == 0) {
          buffer.write(' ');
        }
        buffer.write(value[i]);
      }
      return buffer.toString();
    }

    final distanceText = stats?.distance != null
        ? isSwim
            ? '${formatSwimDistance(stats!.distance)} м'
            : '${(stats!.distance / 1000.0).toStringAsFixed(2)} км'
        : '—';

    final durationText = stats?.effectiveDuration != null
        ? formatDuration(stats!.effectiveDuration)
        : '—';

    String paceText;
    double? speedKmh;

    if (isSwim) {
      if (stats?.avgPace != null && stats!.avgPace > 0) {
        paceText = formatPace(stats.avgPace / 10.0);
      } else if (stats?.distance != null &&
          stats?.effectiveDuration != null &&
          stats!.distance > 0 &&
          stats.effectiveDuration > 0) {
        final duration = stats.effectiveDuration.toDouble();
        final paceMinPer100m = (duration * 100) / (stats.distance * 60);
        paceText = formatPace(paceMinPer100m);
      } else {
        paceText = '—';
      }
    } else {
      paceText = stats?.avgPace != null ? formatPace(stats!.avgPace) : '—';
    }

    if (isBike) {
      if (activity.points.isEmpty &&
          stats?.distance != null &&
          stats?.effectiveDuration != null &&
          stats!.distance > 0 &&
          stats.effectiveDuration > 0) {
        final duration = stats.effectiveDuration.toDouble();
        speedKmh = (stats.distance / duration) * 3.6;
      } else if (stats?.avgSpeed != null && stats!.avgSpeed > 0) {
        speedKmh = stats.avgSpeed;
      } else if (stats?.distance != null &&
          stats?.effectiveDuration != null &&
          stats!.distance > 0 &&
          stats.effectiveDuration > 0) {
        final duration = stats.effectiveDuration.toDouble();
        speedKmh = (stats.distance / duration) * 3.6;
      }
    } else {
      if (stats?.distance != null &&
          stats?.effectiveDuration != null &&
          stats!.distance > 0 &&
          stats.effectiveDuration > 0) {
        final duration = stats.effectiveDuration.toDouble();
        speedKmh = (stats.distance / duration) * 3.6;
      }
    }

    final speedText = speedKmh != null
        ? '${speedKmh.toStringAsFixed(1)} км/ч'
        : '—';

    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Расстояние',
                style: AppTextStyles.h11w4Sec.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 1),
              distanceText == '—'
                  ? Text(
                      distanceText,
                      style: AppTextStyles.h17w6.copyWith(
                        color: Colors.white,
                      ),
                    )
                  : Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: distanceText
                                .replaceAll(' км', '')
                                .replaceAll(' м', ''),
                            style: AppTextStyles.h17w6.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          TextSpan(
                            text: distanceText.contains(' км') ? ' км' : ' м',
                            style: AppTextStyles.h17w6.copyWith(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        ),
        SizedBox(
          width: 110,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Время, мин',
                style: AppTextStyles.h11w4Sec.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 0),
              Text(
                durationText,
                style: AppTextStyles.h17w6.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isBike
                    ? 'Скорость'
                    : isSwim
                        ? 'Темп, /100м'
                        : 'Темп, /км',
                style: AppTextStyles.h11w4Sec.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 0),
              isBike
                  ? (speedText == '—'
                      ? Text(
                          speedText,
                          style: AppTextStyles.h17w6.copyWith(
                            color: Colors.white,
                          ),
                        )
                      : Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: speedText.replaceAll(' км/ч', ''),
                                style: AppTextStyles.h17w6.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: ' км/ч',
                                style: AppTextStyles.h17w6.copyWith(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ))
                  : Text(
                      paceText,
                      style: AppTextStyles.h17w6.copyWith(
                        color: Colors.white,
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 МЕТРИКИ В КОЛОНКУ: ДЛЯ ТРЕТЬЕГО ВИДА
  // ────────────────────────────────────────────────────────────────
  Widget _buildOverlayMetricsColumn(
    BuildContext context, {
    bool isRightAligned = false,
  }) {
    final textAlign = isRightAligned ? TextAlign.right : TextAlign.left;
    final itemCrossAxisAlignment = isRightAligned
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final itemAlignment = isRightAligned
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final stats = activity.stats;
    final activityTypeLower = activity.type.toLowerCase();
    final isSwim =
        activityTypeLower == 'swim' || activityTypeLower == 'swimming';
    final isBike =
        activityTypeLower == 'bike' ||
        activityTypeLower == 'bicycle' ||
        activityTypeLower == 'cycling' ||
        activityTypeLower == 'indoor-cycling';

    String formatSwimDistance(double meters) {
      final value = meters.toStringAsFixed(0);
      final buffer = StringBuffer();
      for (int i = 0; i < value.length; i++) {
        if (i > 0 && (value.length - i) % 3 == 0) {
          buffer.write(' ');
        }
        buffer.write(value[i]);
      }
      return buffer.toString();
    }

    final distanceText = stats?.distance != null
        ? isSwim
            ? '${formatSwimDistance(stats!.distance)} м'
            : '${(stats!.distance / 1000.0).toStringAsFixed(2)} км'
        : '—';

    final durationText = stats?.effectiveDuration != null
        ? formatDuration(stats!.effectiveDuration)
        : '—';

    String paceText;
    double? speedKmh;

    if (isSwim) {
      if (stats?.avgPace != null && stats!.avgPace > 0) {
        paceText = formatPace(stats.avgPace / 10.0);
      } else if (stats?.distance != null &&
          stats?.effectiveDuration != null &&
          stats!.distance > 0 &&
          stats.effectiveDuration > 0) {
        final duration = stats.effectiveDuration.toDouble();
        final paceMinPer100m = (duration * 100) / (stats.distance * 60);
        paceText = formatPace(paceMinPer100m);
      } else {
        paceText = '—';
      }
    } else {
      paceText = stats?.avgPace != null ? formatPace(stats!.avgPace) : '—';
    }

    if (isBike) {
      if (activity.points.isEmpty &&
          stats?.distance != null &&
          stats?.effectiveDuration != null &&
          stats!.distance > 0 &&
          stats.effectiveDuration > 0) {
        final duration = stats.effectiveDuration.toDouble();
        speedKmh = (stats.distance / duration) * 3.6;
      } else if (stats?.avgSpeed != null && stats!.avgSpeed > 0) {
        speedKmh = stats.avgSpeed;
      } else if (stats?.distance != null &&
          stats?.effectiveDuration != null &&
          stats!.distance > 0 &&
          stats.effectiveDuration > 0) {
        final duration = stats.effectiveDuration.toDouble();
        speedKmh = (stats.distance / duration) * 3.6;
      }
    } else {
      if (stats?.distance != null &&
          stats?.effectiveDuration != null &&
          stats!.distance > 0 &&
          stats.effectiveDuration > 0) {
        final duration = stats.effectiveDuration.toDouble();
        speedKmh = (stats.distance / duration) * 3.6;
      }
    }

    final speedText = speedKmh != null
        ? '${speedKmh.toStringAsFixed(1)} км/ч'
        : '—';

    Widget buildMetricItem(String label, Widget value) {
      return Column(
        crossAxisAlignment: itemCrossAxisAlignment,
        children: [
          Text(
            label,
            style: AppTextStyles.h11w4Sec.copyWith(
              color: Colors.white,
            ),
            textAlign: textAlign,
          ),
          const SizedBox(height: 1),
          Align(
            alignment: itemAlignment,
            child: value,
          ),
        ],
      );
    }

    final distanceValue = distanceText == '—'
        ? Text(
            distanceText,
            style: AppTextStyles.h17w6.copyWith(
              color: Colors.white,
            ),
            textAlign: textAlign,
          )
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: distanceText
                      .replaceAll(' км', '')
                      .replaceAll(' м', ''),
                  style: AppTextStyles.h17w6.copyWith(
                    color: Colors.white,
                  ),
                ),
                TextSpan(
                  text: distanceText.contains(' км') ? ' км' : ' м',
                  style: AppTextStyles.h17w6.copyWith(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            textAlign: textAlign,
          );

    final durationValue = Text(
      durationText,
      style: AppTextStyles.h17w6.copyWith(
        color: Colors.white,
      ),
      textAlign: textAlign,
    );

    final paceValue = isBike
        ? (speedText == '—'
            ? Text(
                speedText,
                style: AppTextStyles.h17w6.copyWith(
                  color: Colors.white,
                ),
                textAlign: textAlign,
              )
            : Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: speedText.replaceAll(' км/ч', ''),
                      style: AppTextStyles.h17w6.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    TextSpan(
                      text: ' км/ч',
                      style: AppTextStyles.h17w6.copyWith(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                textAlign: textAlign,
              ))
        : Text(
            paceText,
            style: AppTextStyles.h17w6.copyWith(
              color: Colors.white,
            ),
            textAlign: textAlign,
          );

    return Column(
      crossAxisAlignment: itemCrossAxisAlignment,
      children: [
        buildMetricItem('Расстояние', distanceValue),
        const SizedBox(height: 12),
        buildMetricItem('Время, мин', durationValue),
        const SizedBox(height: 12),
        buildMetricItem(
          isBike
              ? 'Скорость'
              : isSwim
                  ? 'Темп, /100м'
                  : 'Темп, /км',
          paceValue,
        ),
      ],
    );
  }
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 СЕКЦИЯ ВЫБОРА ФОТО
/// ────────────────────────────────────────────────────────────────
class _SharePhotoSelector extends StatelessWidget {
  final Activity activity;
  final List<_ShareMediaItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _SharePhotoSelector({
    required this.activity,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────
    // 🔹 ПУСТОЕ СОСТОЯНИЕ: НЕТ ФОТО И НЕТ МАРШРУТА
    // ────────────────────────────────────────────────────────────────
    if (items.isEmpty) {
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
        const separatorWidth = 12.0 * 2;
        final rawItemSize = (screenWidth - separatorWidth) / 3;
        final itemSize = (rawItemSize - 16).clamp(0.0, double.infinity);

        return SizedBox(
          height: itemSize,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final opacity = index == selectedIndex ? 1.0 : 0.5;

              return GestureDetector(
                onTap: () => onSelected(index),
                behavior: HitTestBehavior.opaque,
                child: Opacity(
                  opacity: opacity,
                  child: item.isMap
                      ? _ShareMapItem(
                          points: activity.points
                              .map((c) => LatLng(c.lat, c.lng))
                              .toList(),
                          size: itemSize,
                        )
                      : _SharePhotoItem(
                          imageUrl: item.imageUrl!,
                          size: itemSize,
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

  const _SharePhotoItem({
    required this.imageUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final w = (size * dpr).round();

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: CachedNetworkImage(
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
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final optimizedDpr = (dpr > 1.5 ? 1.5 : dpr).clamp(1.0, 1.5);
    final w = (size * optimizedDpr).round();
    final h = (size * optimizedDpr).round();

    final mapUrl = StaticMapUrlBuilder.fromPoints(
      points: points,
      widthPx: w.toDouble(),
      heightPx: h.toDouble(),
      strokeWidth: 3.0,
      padding: 10.0,
      maxWidth: 180.0,
      maxHeight: 180.0,
    );

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: CachedNetworkImage(
          imageUrl: mapUrl,
          fit: BoxFit.cover,
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
/// 🔹 МОДЕЛЬ ЭЛЕМЕНТА МЕДИА (ФОТО ИЛИ КАРТА)
/// ────────────────────────────────────────────────────────────────
class _ShareMediaItem {
  final String? imageUrl;
  final bool isMap;

  const _ShareMediaItem.photo(this.imageUrl) : isMap = false;
  const _ShareMediaItem.map()
      : imageUrl = null,
        isMap = true;
}

// ────────────────────────────────────────────────────────────────
// 🔹 ХЕЛПЕР: ФОРМИРУЕМ СПИСОК МЕДИА С УЧЕТОМ СОРТИРОВКИ КАРТЫ
// ────────────────────────────────────────────────────────────────
List<_ShareMediaItem> _buildMediaItems(Activity activity) {
  final items = <_ShareMediaItem>[];

  for (final imageUrl in activity.mediaImages) {
    items.add(_ShareMediaItem.photo(imageUrl));
  }

  if (activity.points.isNotEmpty) {
    final mapInsertIndex =
        (activity.mapSortOrder ?? items.length).clamp(0, items.length);
    items.insert(mapInsertIndex, const _ShareMediaItem.map());
  }

  return items;
}
