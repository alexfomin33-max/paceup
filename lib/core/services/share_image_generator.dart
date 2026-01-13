// lib/core/services/share_image_generator.dart
import 'dart:async';
import 'dart:io';

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../domain/models/activity_lenta.dart';
import '../config/app_config.dart';
import '../utils/activity_format.dart';
import '../utils/static_map_url_builder.dart';

/// Сервис для генерации изображения тренировки для шаринга в Instagram Stories
class ShareImageGenerator {
  /// Размеры для Instagram Stories
  static const int storyWidth = 1080;
  static const int storyHeight = 1920;

  /// Генерирует изображение для шаринга тренировки
  ///
  /// [selectedPhotoUrl] - URL выбранного фото (если null и есть фото, используется первое)
  /// [useMap] - использовать карту вместо фото (если true, игнорируется selectedPhotoUrl)
  /// [mapImageUrl] - URL уже загруженного изображения карты (если передан, используется вместо генерации нового)
  ///
  /// Возвращает путь к сохраненному файлу изображения
  static Future<String?> generateShareImage({
    required Activity activity,
    required BuildContext context,
    Uint8List? routeImageBytes,
    String? selectedPhotoUrl,
    bool useMap = false,
    String? mapImageUrl,
  }) async {
    try {
      // Создаем изображение для Instagram Stories
      // Сначала заливаем белым фоном, чтобы не было черного экрана
      final shareImage = img.Image(width: storyWidth, height: storyHeight);
      _fillRectWithColor(
        shareImage,
        x1: 0,
        y1: 0,
        x2: storyWidth,
        y2: storyHeight,
        color: img.ColorRgb8(255, 255, 255),
      );

      // Определяем, что использовать как фон
      bool shouldUseMap = useMap || activity.mediaImages.isEmpty;

      if (shouldUseMap) {
        // Используем карту с треком
        await _drawBackground(shareImage, activity, mapImageUrl: mapImageUrl);
      } else {
        // Используем выбранное фото или первое доступное
        final photoUrl = selectedPhotoUrl ?? activity.mediaImages.first;
        debugPrint('Загружаем фото для репоста: $photoUrl');
        final backgroundImage = await _loadNetworkImage(photoUrl);
        if (backgroundImage != null) {
          debugPrint(
            'Фото загружено: ${backgroundImage.width}x${backgroundImage.height}',
          );

          // Вычисляем масштаб для вписывания в экран (BoxFit.contain логика)
          // Берем минимальный масштаб, чтобы изображение полностью вписывалось в экран
          final scaleX = storyWidth / backgroundImage.width;
          final scaleY = storyHeight / backgroundImage.height;
          final scale = scaleX < scaleY
              ? scaleX
              : scaleY; // Минимальный масштаб для вписывания

          // Масштабируем изображение
          final newWidth = (backgroundImage.width * scale).round();
          final newHeight = (backgroundImage.height * scale).round();
          final resized = img.copyResize(
            backgroundImage,
            width: newWidth,
            height: newHeight,
            interpolation: img.Interpolation.linear,
          );

          debugPrint(
            'Масштабированное фото: ${resized.width}x${resized.height}, scale: $scale',
          );

          // Центрируем изображение (вписываем полностью, без обрезки)
          final offsetX = (storyWidth - resized.width) ~/ 2;
          final offsetY = (storyHeight - resized.height) ~/ 2;

          // Накладываем изображение на фон
          img.compositeImage(shareImage, resized, dstX: offsetX, dstY: offsetY);

          // Затемнение не нужно, так как текст черный
        } else {
          debugPrint(
            'Не удалось загрузить фото, используем карту или градиент',
          );
          // Если не удалось загрузить фото - используем карту или градиент
          await _drawBackground(shareImage, activity, mapImageUrl: mapImageUrl);
        }
      }

      // Добавляем логотип PaceUp сверху
      await _drawLogo(shareImage);

      // Рисуем параметры тренировки слева внизу (как на скриншотах)
      if (activity.stats != null) {
        await _drawStatsOnImage(shareImage, activity.stats!, context, activity);
      }

      // Сохраняем изображение
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/share_activity_${activity.id}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(img.encodePng(shareImage));

      return file.path;
    } catch (e) {
      debugPrint('Ошибка генерации изображения для шаринга: $e');
      return null;
    }
  }

  /// Рисует фон: карту с треком или градиент
  /// [mapImageUrl] - URL уже загруженного изображения карты (если передан, используется вместо генерации нового)
  static Future<void> _drawBackground(
    img.Image shareImage,
    Activity activity, {
    String? mapImageUrl,
  }) async {
    // Если передан URL уже загруженного изображения карты, используем его
    if (mapImageUrl != null) {
      debugPrint('Используем уже загруженное изображение карты: $mapImageUrl');
      final mapImage = await _loadNetworkImage(mapImageUrl);
      if (mapImage != null) {
        debugPrint(
          'Карта загружена из кэша, размер: ${mapImage.width}x${mapImage.height}',
        );

        // Масштабируем с сохранением пропорций (BoxFit.contain логика)
        // Вычисляем масштаб для вписывания в экран
        final scaleX = storyWidth / mapImage.width;
        final scaleY = storyHeight / mapImage.height;
        final scale = scaleX < scaleY
            ? scaleX
            : scaleY; // Минимальный масштаб для вписывания

        // Масштабируем изображение с сохранением пропорций
        final newWidth = (mapImage.width * scale).round();
        final newHeight = (mapImage.height * scale).round();
        final finalMapImage = img.copyResize(
          mapImage,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
        debugPrint(
          'Карта масштабирована до: ${finalMapImage.width}x${finalMapImage.height}, scale: $scale',
        );

        // Центрируем изображение (вписываем полностью, без обрезки)
        final offsetX = (storyWidth - finalMapImage.width) ~/ 2;
        final offsetY = (storyHeight - finalMapImage.height) ~/ 2;

        // Накладываем карту на фон (белые полосы остаются по краям)
        img.compositeImage(
          shareImage,
          finalMapImage,
          dstX: offsetX,
          dstY: offsetY,
        );
        debugPrint('Карта успешно наложена на фон');
        return;
      } else {
        debugPrint('Не удалось загрузить карту по URL, генерируем новую');
      }
    }

    // Генерируем карту с треком (если есть точки)
    if (activity.points.isNotEmpty) {
      debugPrint(
        'Генерируем карту для репоста, точек: ${activity.points.length}',
      );

      try {
        // Используем StaticMapUrlBuilder для генерации правильной карты (как на экране тренировки)
        final points = activity.points
            .map((c) => LatLng(c.lat, c.lng))
            .toList();
        final mapUrl = StaticMapUrlBuilder.fromPoints(
          points: points,
          widthPx: storyWidth.toDouble(),
          heightPx: storyHeight.toDouble(),
          strokeWidth: 3.0,
          padding: 12.0,
          maxWidth: 1280.0, // Ограничение Mapbox API
          maxHeight: 1280.0,
        );

        debugPrint('Загружаем карту: $mapUrl');
        final response = await http
            .get(Uri.parse(mapUrl))
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                debugPrint('Таймаут загрузки карты');
                return http.Response('Timeout', 408);
              },
            );

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          debugPrint(
            'Карта загружена, размер: ${response.bodyBytes.length} байт',
          );
          final mapImage = img.decodeImage(response.bodyBytes);
          if (mapImage != null) {
            debugPrint(
              'Карта декодирована: ${mapImage.width}x${mapImage.height}',
            );

            // Масштабируем с сохранением пропорций (BoxFit.contain логика)
            // Вычисляем масштаб для вписывания в экран
            final scaleX = storyWidth / mapImage.width;
            final scaleY = storyHeight / mapImage.height;
            final scale = scaleX < scaleY
                ? scaleX
                : scaleY; // Минимальный масштаб для вписывания

            // Масштабируем изображение с сохранением пропорций
            final newWidth = (mapImage.width * scale).round();
            final newHeight = (mapImage.height * scale).round();
            final finalMapImage = img.copyResize(
              mapImage,
              width: newWidth,
              height: newHeight,
              interpolation: img.Interpolation.linear,
            );
            debugPrint(
              'Карта масштабирована до: ${finalMapImage.width}x${finalMapImage.height}, scale: $scale',
            );

            // Центрируем изображение (вписываем полностью, без обрезки)
            final offsetX = (storyWidth - finalMapImage.width) ~/ 2;
            final offsetY = (storyHeight - finalMapImage.height) ~/ 2;

            // Накладываем карту на фон (белые полосы остаются по краям)
            img.compositeImage(
              shareImage,
              finalMapImage,
              dstX: offsetX,
              dstY: offsetY,
            );

            // Затемнение не нужно, так как текст черный
            debugPrint('Карта успешно наложена на фон');
            return;
          } else {
            debugPrint('Ошибка: карта не декодирована (mapImage == null)');
          }
        } else {
          debugPrint('Ошибка загрузки карты: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Ошибка генерации карты: $e');
      }
    } else {
      debugPrint('Нет точек маршрута для генерации карты');
    }

    // Если карту не удалось сгенерировать - градиентный фон
    debugPrint('Используем градиентный фон вместо карты');
    _drawGradientBackground(shareImage);
  }

  /// Генерирует статичную карту с треком через Mapbox Static Images API
  static Future<Uint8List?> _generateMapImage(List<Coord> points) async {
    if (points.isEmpty) return null;

    try {
      // Вычисляем границы маршрута
      double minLat = points.first.lat;
      double maxLat = points.first.lat;
      double minLng = points.first.lng;
      double maxLng = points.first.lng;

      for (final point in points) {
        if (point.lat < minLat) minLat = point.lat;
        if (point.lat > maxLat) maxLat = point.lat;
        if (point.lng < minLng) minLng = point.lng;
        if (point.lng > maxLng) maxLng = point.lng;
      }

      // Центр карты
      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;

      // Формируем полилинию для Mapbox Static Images API
      // Берем каждую 10-ю точку для оптимизации (иначе URL может быть слишком длинным)
      final sampledPoints = <Coord>[];
      for (
        int i = 0;
        i < points.length;
        i += (points.length > 100 ? (points.length / 100).ceil() : 1)
      ) {
        sampledPoints.add(points[i]);
      }
      if (sampledPoints.last != points.last) {
        sampledPoints.add(points.last);
      }

      final polyline = sampledPoints.map((p) => '${p.lng},${p.lat}').join(';');

      // Mapbox API ограничивает высоту до 1280 пикселей
      // Вычисляем размеры для запроса с учетом ограничений API
      // Сохраняем соотношение сторон Stories (9:16)
      const maxApiHeight = 1280;
      const maxApiWidth = 1280;

      // Вычисляем размеры для запроса, сохраняя соотношение сторон
      int requestWidth = storyWidth;
      int requestHeight = storyHeight;

      if (requestHeight > maxApiHeight) {
        // Масштабируем до максимальной высоты
        final scale = maxApiHeight / storyHeight;
        requestHeight = maxApiHeight;
        requestWidth = (storyWidth * scale).round();

        // Проверяем ширину (не должна превышать максимум)
        if (requestWidth > maxApiWidth) {
          final widthScale = maxApiWidth / requestWidth;
          requestWidth = maxApiWidth;
          requestHeight = (requestHeight * widthScale).round();
        }
      } else if (requestWidth > maxApiWidth) {
        // Масштабируем до максимальной ширины
        final scale = maxApiWidth / storyWidth;
        requestWidth = maxApiWidth;
        requestHeight = (storyHeight * scale).round();
      }

      // URL для Mapbox Static Images API
      // Не используем @2x, чтобы не превышать лимиты API
      final mapUrl =
          'https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/'
          'path-5+379AE6-0.8($polyline)/'
          '$centerLng,$centerLat,12,0/'
          '${requestWidth}x$requestHeight?'
          'access_token=${AppConfig.mapboxAccessToken}';

      debugPrint('Генерируем карту: $mapUrl');
      final response = await http
          .get(Uri.parse(mapUrl))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('Таймаут загрузки карты');
              return http.Response('Timeout', 408);
            },
          );

      if (response.statusCode == 200) {
        debugPrint(
          'Карта успешно загружена, размер: ${response.bodyBytes.length} байт',
        );
        final mapImageBytes = response.bodyBytes;

        if (mapImageBytes.isEmpty) {
          debugPrint('Ошибка: карта загружена, но пуста');
          return null;
        }

        // Декодируем изображение и масштабируем до нужного размера
        final mapImage = img.decodeImage(mapImageBytes);
        if (mapImage != null) {
          debugPrint(
            'Карта декодирована из ответа: ${mapImage.width}x${mapImage.height}',
          );
          // Масштабируем до размера Stories, если нужно
          if (mapImage.width != storyWidth || mapImage.height != storyHeight) {
            final scaledImage = img.copyResize(
              mapImage,
              width: storyWidth,
              height: storyHeight,
              interpolation: img.Interpolation.linear,
            );
            debugPrint(
              'Карта масштабирована до: ${scaledImage.width}x${scaledImage.height}',
            );
            final encoded = img.encodePng(scaledImage);
            debugPrint(
              'Карта закодирована в PNG, размер: ${encoded.length} байт',
            );
            return encoded;
          }
          debugPrint('Карта не требует масштабирования');
          return mapImageBytes;
        } else {
          debugPrint('Ошибка: не удалось декодировать карту из ответа');
          return null;
        }
      } else {
        debugPrint(
          'Ошибка загрузки карты: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Ошибка генерации карты: $e');
      return null;
    }
  }

  /// Загружает изображение по URL с использованием кэша CachedNetworkImage
  static Future<img.Image?> _loadNetworkImage(String url) async {
    try {
      // Используем DefaultCacheManager для доступа к кэшу CachedNetworkImage
      // Это позволяет использовать уже загруженные изображения без повторных запросов
      final cacheManager = DefaultCacheManager();
      final file = await cacheManager
          .getSingleFile(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('Таймаут загрузки изображения из кэша: $url');
              throw TimeoutException('Timeout loading image');
            },
          );

      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          debugPrint(
            'Изображение загружено из кэша: $url, размер: ${bytes.length} байт',
          );
          return img.decodeImage(bytes);
        }
      }
      return null;
    } on TimeoutException {
      debugPrint('Таймаут загрузки изображения: $url');
      return null;
    } catch (e) {
      debugPrint('Ошибка загрузки изображения: $e');
      return null;
    }
  }

  /// Рисует градиентный фон
  static void _drawGradientBackground(img.Image image) {
    // Градиент от темно-синего к черному
    for (int y = 0; y < storyHeight; y++) {
      final ratio = y / storyHeight;
      final r = (20 + (0 - 20) * ratio).round();
      final g = (30 + (0 - 30) * ratio).round();
      final b = (50 + (0 - 50) * ratio).round();
      _fillRectWithColor(
        image,
        x1: 0,
        y1: y,
        x2: storyWidth,
        y2: y + 1,
        color: img.ColorRgb8(r, g, b),
      );
    }
  }

  /// Вспомогательный метод для заливки прямоугольника цветом
  static void _fillRectWithColor(
    img.Image image, {
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    required img.Color color,
  }) {
    for (int y = y1; y < y2 && y < image.height; y++) {
      for (int x = x1; x < x2 && x < image.width; x++) {
        image.setPixel(x, y, color);
      }
    }
  }

  /// Добавляет логотип PaceUp в верхнюю часть изображения
  static Future<void> _drawLogo(img.Image shareImage) async {
    try {
      // Загружаем логотип из assets
      final ByteData logoData = await rootBundle.load('assets/logo.png');
      final Uint8List logoBytes = logoData.buffer.asUint8List();

      // Декодируем логотип
      final logoImage = img.decodeImage(logoBytes);
      if (logoImage == null) {
        debugPrint('Не удалось декодировать логотип');
        return;
      }

      // Масштабируем логотип до нужного размера (примерно 15% от ширины экрана)
      final logoWidth = (storyWidth * 0.15).round(); // 15% от ширины
      final logoHeight = (logoImage.height * logoWidth / logoImage.width)
          .round();

      final resizedLogo = img.copyResize(
        logoImage,
        width: logoWidth,
        height: logoHeight,
        interpolation: img.Interpolation.linear,
      );

      // Позиционируем логотип сверху по центру с отступом
      const topPadding = 60.0;
      final logoX =
          (storyWidth - resizedLogo.width) ~/ 2; // Центрируем по горизонтали
      final logoY = topPadding.round();

      // Накладываем логотип на изображение
      img.compositeImage(shareImage, resizedLogo, dstX: logoX, dstY: logoY);

      debugPrint(
        'Логотип добавлен: ${resizedLogo.width}x${resizedLogo.height} в позиции ($logoX, $logoY)',
      );
    } catch (e) {
      debugPrint('Ошибка добавления логотипа: $e');
      // Игнорируем ошибку, чтобы не ломать генерацию изображения
    }
  }

  /// Рисует параметры тренировки напрямую на изображении (слева внизу, как на скриншотах)
  static Future<void> _drawStatsOnImage(
    img.Image shareImage,
    ActivityStats stats,
    BuildContext context,
    Activity activity,
  ) async {
    try {
      const pixelRatio = 2.0;
      const labelFontSize = 64.0; // Увеличено в 2 раза (было 32.0)
      const valueFontSize = 96.0; // Увеличено в 2 раза (было 48.0)
      const titleFontSize = 80.0; // Увеличено в 2 раза (было 40.0)
      const leftPadding = 50.0;
      const bottomPadding = 60.0; // Отступ от нижнего края
      const lineSpacing = 120.0; // Увеличено в 2 раза (было 60.0)
      const labelValueSpacing = 12.0; // Увеличено в 2 раза (было 6.0)

      // Создаем Canvas для рисования текста и иконки
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, storyWidth.toDouble(), storyHeight.toDouble()),
      );

      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
      );

      const labelStyle = TextStyle(
        fontFamily: 'Inter',
        fontSize: labelFontSize,
        fontWeight: FontWeight.w500,
        color: Colors.black,
      );
      const valueStyle = TextStyle(
        fontFamily: 'Inter',
        fontSize: valueFontSize,
        fontWeight: FontWeight.w700,
        color: Colors.black,
      );
      const titleStyle = TextStyle(
        fontFamily: 'Inter',
        fontSize: titleFontSize,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      );

      // Начинаем рисовать снизу вверх: нижний край блока на высоте storyHeight - bottomPadding
      // textPainter.paint рисует текст от базовой линии вверх, так что базовая линия = нижний край текста
      double currentY = storyHeight - bottomPadding;

      // Сначала рисуем Темп (самый нижний элемент в списке)
      if (stats.avgPace > 0) {
        // avgPace в секундах на км, конвертируем в минуты на км
        double paceMinPerKm;
        if (stats.avgPace < 60) {
          if (stats.distance > 0 && stats.duration > 0) {
            final distanceKm = stats.distance / 1000.0;
            final timeMinutes = stats.duration / 60.0;
            paceMinPerKm = timeMinutes / distanceKm;
          } else {
            paceMinPerKm = stats.avgPace;
          }
        } else {
          paceMinPerKm = stats.avgPace / 60.0;
        }

        // Форматируем темп с секундами (мин:сек /км)
        final paceValue = '${formatPace(paceMinPerKm)} /км';

        // Значение - базовая линия на currentY (текст пойдет вверх)
        textPainter.text = TextSpan(text: paceValue, style: valueStyle);
        textPainter.layout();
        textPainter.paint(canvas, Offset(leftPadding, currentY));
        currentY -= textPainter.height;
        currentY -= labelValueSpacing;

        // Метка
        textPainter.text = const TextSpan(text: 'Темп', style: labelStyle);
        textPainter.layout();
        textPainter.paint(canvas, Offset(leftPadding, currentY));
        currentY -= textPainter.height;
        currentY -= lineSpacing;
      }

      // Время (формат: "23мин." или "1ч. 23мин." - без секунд)
      final timeValue = _formatDurationForShare(stats.duration);

      // Значение
      textPainter.text = TextSpan(text: timeValue, style: valueStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftPadding, currentY));
      currentY -= textPainter.height;
      currentY -= labelValueSpacing;

      // Метка
      textPainter.text = const TextSpan(text: 'Время', style: labelStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftPadding, currentY));
      currentY -= textPainter.height;
      currentY -= lineSpacing;

      // Расстояние (формат: "3,51 км" с запятой)
      final distanceKm = stats.distance / 1000.0;
      final distanceValue =
          '${distanceKm.toStringAsFixed(2).replaceAll('.', ',')} км';

      // Значение
      textPainter.text = TextSpan(text: distanceValue, style: valueStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftPadding, currentY));
      currentY -= textPainter.height;
      currentY -= labelValueSpacing;

      // Метка
      textPainter.text = const TextSpan(text: 'Расстояние', style: labelStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftPadding, currentY));
      currentY -= textPainter.height;
      currentY -= lineSpacing;

      // Тип тренировки - ПЕРВЫЙ в списке (рисуем последним, чтобы он был сверху)
      // БЕЗ ИКОНКИ - только текст
      String activityTypeTitle = _getActivityTypeTitle(activity.type);

      if (activityTypeTitle.isNotEmpty) {
        textPainter.text = TextSpan(text: activityTypeTitle, style: titleStyle);
        textPainter.layout();
        textPainter.paint(canvas, Offset(leftPadding, currentY));
      }

      // Конвертируем Canvas в изображение
      final picture = recorder.endRecording();
      final uiImage = await picture.toImage(
        (storyWidth * pixelRatio).toInt(),
        (storyHeight * pixelRatio).toInt(),
      );
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      uiImage.dispose();

      if (byteData != null) {
        // Композируем текст на основное изображение
        final textImage = img.decodeImage(byteData.buffer.asUint8List());
        if (textImage != null) {
          img.compositeImage(shareImage, textImage);
        }
      }
    } catch (e) {
      debugPrint('Ошибка рисования параметров: $e');
    }
  }

  /// Возвращает название типа активности на русском
  static String _getActivityTypeTitle(String type) {
    final typeLower = type.toLowerCase();
    switch (typeLower) {
      case 'running':
      case 'run':
        return 'Забег';
      case 'walking':
      case 'walk':
        return 'Прогулка';
      case 'cycling':
      case 'bike':
        return 'Велозаезд';
      case 'swimming':
      case 'swim':
        return 'Плавание';
      case 'skiing':
      case 'ski':
        return 'Лыжи';
      default:
        return 'Тренировка';
    }
  }

  /// Форматирует длительность для репоста (формат: "23мин." или "1ч. 0мин." - всегда с минутами, без секунд)
  static String _formatDurationForShare(num? seconds) {
    if (seconds == null || seconds <= 0) return '0мин.';

    final total = seconds.toInt();
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;

    final parts = <String>[];
    if (hours > 0) {
      parts.add('$hoursч.');
      // Всегда добавляем минуты, даже если 0
      parts.add('$minutesмин.');
    } else {
      // Если нет часов, просто минуты
      parts.add('$minutesмин.');
    }

    return parts.join(' ');
  }

  /// Захватывает виджет карты в изображение
  /// Использует GlobalKey для захвата существующего виджета карты
  static Future<Uint8List?> captureRouteWidget({
    required List<LatLng> points,
    required BuildContext context,
    GlobalKey? routeKey,
  }) async {
    if (points.isEmpty) return null;

    try {
      // Если передан GlobalKey, используем его для захвата виджета
      if (routeKey != null) {
        final renderObject = routeKey.currentContext?.findRenderObject();
        if (renderObject != null && renderObject is RenderRepaintBoundary) {
          await Future.delayed(
            const Duration(milliseconds: 500),
          ); // Даем время на загрузку карты
          final image = await renderObject.toImage(pixelRatio: 2.0);
          final byteData = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          image.dispose();
          return byteData?.buffer.asUint8List();
        }
      }

      // Если нет ключа, генерируем статичную карту через API
      final coords = points
          .map((p) => Coord(lat: p.latitude, lng: p.longitude))
          .toList();
      return await _generateMapImage(coords);
    } catch (e) {
      debugPrint('Ошибка захвата виджета карты: $e');
      return null;
    }
  }
}
