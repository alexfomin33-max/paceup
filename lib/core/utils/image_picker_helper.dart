// lib/utils/image_picker_helper.dart
// ─────────────────────────────────────────────────────────────────────────────
//              УТИЛИТА: ВЫБОР, ОБРЕЗКА И СЖАТИЕ ИЗОБРАЖЕНИЙ
//  • Переиспользуемые методы для работы с изображениями из галереи
//  • Поддерживает обрезку с фиксированными пропорциями
//  • Автоматически сжимает изображения для оптимизации размера
//  • Удаляет временные файлы после обработки
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../widgets/image_crop_screen.dart';
import 'local_image_compressor.dart';

/// Вспомогательная функция для чтения файла в isolate
/// Используется с compute() для чтения больших изображений без блокировки UI
Future<Uint8List> _readFileBytes(String filePath) async {
  final file = File(filePath);
  return file.readAsBytes();
}

class ImagePickerHelper {
  /// Максимальный размер стороны, который мы разрешаем возвращать из галереи.
  /// 4096px достаточно, чтобы сохранить детализацию, но не уложить устройство.
  static const double maxPickerDimension = 4096.0;

  /// Качество JPEG при даунскейле средствами ImagePicker (0-100).
  /// 95 — почти без потери качества, но уменьшает вес файла.
  static const int pickerImageQuality = 95;

  static final ImagePicker _picker = ImagePicker();

  /// Выбирает изображение из галереи, обрезает его и сжимает
  ///
  /// [aspectRatio] - пропорции обрезки (например, 1.0 для квадрата, 16/9 для широкоформатного)
  /// [maxSide] - максимальный размер стороны после сжатия
  /// [jpegQuality] - качество JPEG (0-100)
  /// [cropTitle] - заголовок экрана обрезки
  /// [isCircular] - если true, обрезка будет круглой (UI и результат)
  ///
  /// Возвращает [File] с обработанным изображением или null, если пользователь отменил
  static Future<File?> pickAndProcessImage({
    required BuildContext context,
    required double aspectRatio,
    required int maxSide,
    required int jpegQuality,
    required String cropTitle,
    bool isCircular = false,
  }) async {
    // ── выбираем файл из галереи
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    if (!context.mounted) return null;

    // ── открываем экран обрезки с нужными пропорциями
    final cropped = await cropPickedImage(
      context: context,
      source: picked,
      aspectRatio: aspectRatio,
      title: cropTitle,
      isCircular: isCircular,
    );
    if (cropped == null) return null;

    // ── сжимаем результат, чтобы не перегружать сеть при загрузке
    final compressed = await compressLocalImage(
      sourceFile: cropped,
      maxSide: maxSide,
      jpegQuality: jpegQuality,
    );

    // ── удаляем временный файл обрезки, если компрессор создал другой файл
    if (cropped.path != compressed.path) {
      try {
        await cropped.delete();
      } catch (_) {
        // ── подавляем ошибку удаления, чтобы не мешать сценарию пользователя
      }
    }

    return compressed;
  }

  /// Открывает экран обрезки изображения и сохраняет результат во временный файл
  ///
  /// [source] - выбранный файл из галереи
  /// [aspectRatio] - пропорции обрезки
  /// [title] - заголовок экрана обрезки
  /// [isCircular] - если true, обрезка будет круглой (UI и результат)
  ///
  /// Возвращает [File] с обрезанным изображением или null, если пользователь отменил
  static Future<File?> cropPickedImage({
    required BuildContext context,
    required XFile source,
    required double aspectRatio,
    required String title,
    bool isCircular = false,
  }) async {
    // ── показываем индикатор загрузки перед чтением байтов
    // Это предотвращает ANR при чтении больших изображений
    if (!context.mounted) return null;
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        content: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(),
              SizedBox(height: 12),
              Text('Загрузка изображения...'),
            ],
          ),
        ),
      ),
    );

    // ── читаем байты выбранного изображения в отдельном isolate
    // Это предотвращает блокировку UI при чтении больших файлов
    Uint8List imageBytes;
    try {
      imageBytes = await compute(_readFileBytes, source.path);
    } finally {
      // ── закрываем диалог загрузки
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    if (!context.mounted) return null;

    // ── запускаем экран обрезки и ждём результат от пользователя
    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ImageCropScreen(
          imageBytes: imageBytes,
          aspectRatio: aspectRatio,
          title: title,
          isCircular: isCircular,
        ),
      ),
    );
    if (croppedBytes == null) return null;

    // ── сохраняем результат во временный файл, чтобы прокинуть в компрессор
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final baseName = p.basename(source.path);
    final fileName = 'crop_${timestamp}_$baseName';
    final outputPath = p.join(tempDir.path, fileName);
    final croppedFile = await File(
      outputPath,
    ).writeAsBytes(croppedBytes, flush: true);

    return croppedFile;
  }

  /// Выбирает изображение из галереи без обрезки (только сжатие)
  ///
  /// [maxSide] - максимальный размер стороны после сжатия
  /// [jpegQuality] - качество JPEG (0-100)
  ///
  /// Возвращает [File] с обработанным изображением или null, если пользователь отменил
  static Future<File?> pickImageWithoutCrop({
    required int maxSide,
    required int jpegQuality,
  }) async {
    // ── выбираем файл из галереи
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    // ── сжимаем результат без обрезки
    final compressed = await compressLocalImage(
      sourceFile: File(picked.path),
      maxSide: maxSide,
      jpegQuality: jpegQuality,
    );

    return compressed;
  }
}
