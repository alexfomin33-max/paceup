import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// ──────────── Сервис для генерации и кэширования изображений маркеров ────────────
/// Используется в Mapbox fallback и может быть переиспользован в других экранах.
class MarkerAssets {
  MarkerAssets._();

  /// Создает PNG байты для круглого маркера с числом.
  static Future<Uint8List> createMarkerImage(
    Color color,
    String text,
  ) async {
    const size = 64.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 0.5, paint);
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 0.5,
      borderPaint,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.surface,
          fontWeight: FontWeight.w600,
          fontSize: 36,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Создаёт PNG стрелки (треугольник остриём вверх) для отображения
  /// направления движения по маршруту. Поворот задаётся через iconRotate.
  static Future<Uint8List> createArrowImage() async {
    const size = 32.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = AppColors.brandPrimary
      ..style = PaintingStyle.fill;

    // Треугольник остриём вверх (середина верха, левый низ, правый низ)
    final path = Path()
      ..moveTo(size / 2, 2)
      ..lineTo(size - 2, size - 2)
      ..lineTo(2, size - 2)
      ..close();
    canvas.drawPath(path, paint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}

