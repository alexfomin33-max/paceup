import 'dart:developer';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ────────────────────────── СЖАТИЕ ИЗОБРАЖЕНИЙ ──────────────────────────

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

