import 'dart:developer';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ────────────────────────── СЖАТИЕ ИЗОБРАЖЕНИЙ ──────────────────────────

// ────────────────────────── ПРЕСЕТЫ ДЛЯ РАЗНЫХ ТИПОВ ИЗОБРАЖЕНИЙ ──────────────────────────

/// Пресеты сжатия изображений для оптимизации размера файлов.
/// Расчет основан на правиле: размер изображения = размер отображения × devicePixelRatio (3x).
/// Это обеспечивает четкое отображение на Retina-дисплеях без избыточного размера файлов.
class ImageCompressionPreset {
  /// Аватар пользователя (40-100px на экране)
  /// Расчет: 100px × 3x DPR = 300px
  /// Используется для: редактирование профиля
  static const avatar = (maxSide: 300, quality: 85);

  /// Логотип события/клуба (55-100px на экране)
  /// Расчет: 100px × 3x DPR = 300px
  /// Используется для: логотипы событий и клубов
  static const logo = (maxSide: 300, quality: 85);

  /// Фоновое фото события/клуба (полная ширина ~428px)
  /// Расчет: 428px × 3x DPR = 1284px → округляем до 1300px
  /// Используется для: фоновые изображения событий и клубов
  static const background = (maxSide: 1300, quality: 80);

  /// Фото события с возможностью зума (полный экран с зумом 4x)
  /// Расчет: 480px × 4x zoom = 1920px
  /// Используется для: фото событий в галерее с поддержкой зума
  static const eventPhoto = (maxSide: 1920, quality: 80);

  /// Пост в ленте (полная ширина ~428px)
  /// Расчет: 428px × 3x DPR = 1284px → округляем до 1300px
  /// Используется для: посты в ленте
  static const post = (maxSide: 1300, quality: 80);

  /// Фото активности (полная ширина ~428px)
  /// Расчет: 428px × 3x DPR = 1284px → округляем до 1300px
  /// Используется для: фото в активностях
  static const activity = (maxSide: 1300, quality: 80);

  /// Оборудование в списке (63px на экране)
  /// Расчет: 63px × 3x DPR = 189px → округляем до 190px
  /// Используется для: превью кроссовок и велосипедов в списке
  static const equipmentList = (maxSide: 190, quality: 80);

  /// Оборудование в просмотре (220px на экране)
  /// Расчет: 220px × 3x DPR = 660px
  /// Используется для: просмотр кроссовок и велосипедов
  static const equipmentView = (maxSide: 660, quality: 80);

  /// Изображение в чате (~90% ширины экрана ~385px)
  /// Расчет: 385px × 3x DPR × 0.9 ≈ 1040px → округляем до 1200px
  /// Используется для: изображения в личных чатах
  static const chat = (maxSide: 1200, quality: 80);
}

/// Сжимает локальный файл изображения с сохранением пропорций.
/// Возвращает новый файл в системной временной директории.
/// Использует нативные API для более эффективного сжатия.
Future<File> compressLocalImage({
  required File sourceFile,
  int maxSide = 1600,
  int jpegQuality = 80,
}) async {
  // ── оборачиваем логику в try, чтобы не уронить экран при ошибке кодека
  try {
    // ── определяем формат по расширению файла: PNG сохраняет альфу, JPEG легче
    final sourcePath = sourceFile.path.toLowerCase();
    final isPng = sourcePath.endsWith('.png');
    final format = isPng ? CompressFormat.png : CompressFormat.jpeg;

    // ── сжимаем изображение с использованием нативных API
    // minWidth и minHeight работают как ограничения максимального размера:
    // если изображение больше этих значений, оно будет уменьшено с сохранением пропорций
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      sourceFile.absolute.path,
      minWidth: maxSide,
      minHeight: maxSide,
      quality: jpegQuality,
      format: format,
      keepExif: false,
    );

    if (compressedBytes == null) {
      // ── если сжатие не удалось, используем оригинал без модификаций
      return sourceFile;
    }

    // ── сохраняем сжатое изображение во временный файл
    final tempDir = await getTemporaryDirectory();
    final ext = isPng ? '.png' : '.jpg';
    final fileName = 'cmp_${DateTime.now().millisecondsSinceEpoch}$ext';
    final outputPath = p.join(tempDir.path, fileName);

    final compressedFile = await File(outputPath).writeAsBytes(
      compressedBytes,
      flush: true,
    );

    return compressedFile;
  } catch (error, stackTrace) {
    log(
      'compressLocalImage: ошибка сжатия — $error',
      stackTrace: stackTrace,
    );
    return sourceFile;
  }
}

