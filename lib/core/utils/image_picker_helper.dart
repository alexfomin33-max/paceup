// lib/utils/image_picker_helper.dart
// ─────────────────────────────────────────────────────────────────────────────
//              УТИЛИТА: ВЫБОР, ОБРЕЗКА И СЖАТИЕ ИЗОБРАЖЕНИЙ
//  • Переиспользуемые методы для работы с изображениями из галереи
//  • Поддерживает обрезку с фиксированными пропорциями
//  • Автоматически сжимает изображения для оптимизации размера
//  • Удаляет временные файлы после обработки
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../widgets/image_crop_screen.dart';
import 'local_image_compressor.dart';

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Выбирает изображение из галереи, обрезает его и сжимает
  ///
  /// [aspectRatio] - пропорции обрезки (например, 1.0 для квадрата, 16/9 для широкоформатного)
  /// [maxSide] - максимальный размер стороны после сжатия
  /// [jpegQuality] - качество JPEG (0-100)
  /// [cropTitle] - заголовок экрана обрезки
  ///
  /// Возвращает [File] с обработанным изображением или null, если пользователь отменил
  static Future<File?> pickAndProcessImage({
    required BuildContext context,
    required double aspectRatio,
    required int maxSide,
    required int jpegQuality,
    required String cropTitle,
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
  ///
  /// Возвращает [File] с обрезанным изображением или null, если пользователь отменил
  static Future<File?> cropPickedImage({
    required BuildContext context,
    required XFile source,
    required double aspectRatio,
    required String title,
  }) async {
    // ── читаем байты выбранного изображения
    final imageBytes = await source.readAsBytes();
    if (!context.mounted) return null;

    // ── запускаем экран обрезки и ждём результат от пользователя
    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ImageCropScreen(
          imageBytes: imageBytes,
          aspectRatio: aspectRatio,
          title: title,
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

