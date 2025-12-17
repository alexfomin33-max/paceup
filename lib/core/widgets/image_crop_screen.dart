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
import 'primary_button.dart';

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

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PaceAppBar(title: widget.title),
      body: SafeArea(
        child: Column(
          children: [
            // ── рабочая область обрезки
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
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
            // ── кнопка подтверждения обрезки
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: PrimaryButton(
                text: 'Готово',
                onPressed: () => _onCropPressed(),
                expanded: true,
                isLoading: _cropping,
                enabled: !_cropping,
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

