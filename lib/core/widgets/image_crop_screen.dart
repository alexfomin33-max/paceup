// lib/widgets/image_crop_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
//              ГЛОБАЛЬНЫЙ ВИДЖЕТ: ЭКРАН ОБРЕЗКИ ИЗОБРАЖЕНИЯ
//  • Переиспользуемый экран для обрезки изображений с фиксированными пропорциями
//  • Использует crop_your_image для интерактивной обрезки
//  • Адаптируется к теме приложения (светлая/темная)
//  • Возвращает обрезанное изображение в виде Uint8List через Navigator.pop
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import '../theme/app_theme.dart';
import 'app_bar.dart';

class ImageCropScreen extends StatefulWidget {
  /// Байты исходного изображения для обрезки
  final Uint8List imageBytes;

  /// Пропорции обрезки (например, 1.0 для квадрата, 16/9 для широкоформатного)
  final double aspectRatio;

  /// Заголовок экрана обрезки
  final String title;

  /// Если true, обрезка будет круглой (UI и результат)
  final bool isCircular;

  const ImageCropScreen({
    super.key,
    required this.imageBytes,
    required this.aspectRatio,
    required this.title,
    this.isCircular = false,
  });

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final CropController _controller = CropController();

  bool _cropping = false;

  @override
  Widget build(BuildContext context) {
    // ── общие цвета экрана обрезки
    final backgroundColor = AppColors.getBackgroundColor(context);
    final surfaceColor = AppColors.getSurfaceColor(context);
    final borderColor = AppColors.getBorderColor(context);

    // ── основной каркас экрана с унифицированным AppBar как в NewPostScreen
    return Scaffold(
      backgroundColor: AppColors.twinBg,
      appBar: PaceAppBar(
        title: widget.title,
        backgroundColor: AppColors.twinBg,
        showBottomDivider: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── рабочая область обрезки
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: borderColor),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Crop(
                      controller: _controller,
                      image: widget.imageBytes,
                      aspectRatio: widget.aspectRatio,
                      withCircleUi: widget.isCircular,
                      onCropped: _handleCroppedResult,
                      progressIndicator: const Center(
                        child: CupertinoActivityIndicator(radius: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ── кнопка подтверждения обрезки в стиле "Опубликовать" на экране нового поста
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: Builder(
                  builder: (context) {
                    final textColor = AppColors.getSurfaceColor(context);
                    final button = ElevatedButton(
                      onPressed: _onCropPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        foregroundColor: textColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        shape: const StadiumBorder(),
                        minimumSize: const Size(double.infinity, 50),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.center,
                      ),
                      child: _cropping
                          ? CupertinoActivityIndicator(
                              radius: 9,
                              color: textColor,
                            )
                          : Text(
                              'Готово',
                              style: AppTextStyles.h15w5.copyWith(
                                color: textColor,
                                height: 1.0,
                              ),
                            ),
                    );

                    if (_cropping) {
                      return IgnorePointer(child: button);
                    }

                    return button;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── инициируем обрезку и показываем индикатор загрузки
  void _onCropPressed() {
    setState(() => _cropping = true);
    try {
      // ── если нужна круглая обрезка, используем cropCircle вместо crop
      if (widget.isCircular) {
        _controller.cropCircle();
      } else {
        _controller.crop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _cropping = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка обрезки: $error')));
    }
  }

  // ── обрабатываем результат: возвращаем байты наверх или показываем ошибку
  void _handleCroppedResult(CropResult result) {
    if (result is CropSuccess) {
      if (!mounted) return;
      setState(() => _cropping = false);
      Navigator.of(context).pop(result.croppedImage);
      return;
    }

    if (result is CropFailure) {
      if (!mounted) return;
      setState(() => _cropping = false);
      final cause = result.cause;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка обрезки: $cause')));
    }
  }
}
