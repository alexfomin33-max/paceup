import 'dart:developer';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ────────────────────────── СЖАТИЕ ИЗОБРАЖЕНИЙ ──────────────────────────

/// Сжимает локальный файл изображения с сохранением пропорций.
/// Возвращает новый файл в системной временной директории.
Future<File> compressLocalImage({
  required File sourceFile,
  int maxSide = 1600,
  int jpegQuality = 80,
}) async {
  // ── оборачиваем логику в try, чтобы не уронить экран при ошибке кодека
  try {
    final originalBytes = await sourceFile.readAsBytes();
    final decoded = img.decodeImage(originalBytes);

    if (decoded == null) {
      // ── если декодер не справился, используем оригинал без модификаций
      return sourceFile;
    }

    // ── вычисляем новые размеры с учётом ограничения по большей стороне
    var targetWidth = decoded.width;
    var targetHeight = decoded.height;
    if (targetWidth > targetHeight && targetWidth > maxSide) {
      targetWidth = maxSide;
      targetHeight = (decoded.height * maxSide / decoded.width).round();
    } else if (targetHeight >= targetWidth && targetHeight > maxSide) {
      targetHeight = maxSide;
      targetWidth = (decoded.width * maxSide / decoded.height).round();
    }

    final resized = (targetWidth != decoded.width ||
            targetHeight != decoded.height)
        ? img.copyResize(
            decoded,
            width: targetWidth,
            height: targetHeight,
            interpolation: img.Interpolation.linear,
          )
        : decoded;

    // ── определяем формат: PNG сохраняет альфу, JPEG легче для непрозрачных
    final hasAlpha = resized.hasAlpha;
    final encodedBytes = hasAlpha
        ? img.encodePng(resized, level: 6)
        : img.encodeJpg(resized, quality: jpegQuality);

    final tempDir = await getTemporaryDirectory();
    final ext = hasAlpha ? '.png' : '.jpg';
    final fileName = 'cmp_${DateTime.now().millisecondsSinceEpoch}$ext';
    final outputPath = p.join(tempDir.path, fileName);

    final compressedFile = await File(outputPath).writeAsBytes(
      encodedBytes,
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

