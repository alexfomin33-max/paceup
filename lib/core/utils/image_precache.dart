// lib/utils/image_precache.dart
import 'package:flutter/widgets.dart';

/// Предзагружает картинку из ассетов ровно один раз за всё время работы приложения.
/// Второй и последующие вызовы с тем же путём просто ничего не делают.
class ImagePrecache {
  static final Set<String> _done = <String>{};

  static Future<void> precacheOnce(
    BuildContext context,
    String assetPath,
  ) async {
    if (_done.contains(assetPath)) return; // уже делали
    _done.add(assetPath);
    await precacheImage(AssetImage(assetPath), context);
  }
}
