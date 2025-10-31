// lib/screens/map/events/location_picker_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
//                  ЭКРАН ВЫБОРА МЕСТА НА КАРТЕ
//
// Использование:
//   final result = await Navigator.of(context).push<LocationResult?>(
//     MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
//   );
//
// Возвращает:
//   • LocationResult? — координаты и адрес выбранного места или null при отмене
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../../../theme/app_theme.dart';
import '../../../config/app_config.dart';
import '../../../widgets/interactive_back_swipe.dart';
import '../../../widgets/primary_button.dart';

// ────────────────────────── Результат выбора места ──────────────────────────
/// Класс для передачи координат и адреса выбранного места
class LocationResult {
  final LatLng coordinates;
  final String? address; // может быть null, если геокодинг не удался

  const LocationResult({required this.coordinates, this.address});
}

class LocationPickerScreen extends StatefulWidget {
  /// Начальная позиция на карте (если не указана — центр России)
  final LatLng? initialPosition;

  const LocationPickerScreen({super.key, this.initialPosition});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  // ────────────────────────── Контроллер карты ──────────────────────────
  /// Контроллер для управления картой и отслеживания позиции
  late final MapController _mapController;

  /// Текущие выбранные координаты (обновляются при движении карты)
  LatLng _selectedLocation = const LatLng(56.129057, 40.406635);

  /// Текущий адрес (обновляется при геокодинге)
  String? _currentAddress;

  /// Флаг загрузки геокодинга
  bool _isGeocoding = false;

  /// Таймер для debounce геокодинга
  Timer? _geocodeTimer;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Устанавливаем начальную позицию
    if (widget.initialPosition != null) {
      _selectedLocation = widget.initialPosition!;
    }

    // Инициализируем позицию карты после первой отрисовки
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (widget.initialPosition != null) {
          _mapController.move(
            widget.initialPosition!,
            _mapController.camera.zoom,
          );
          setState(() {
            _selectedLocation = widget.initialPosition!;
          });
        }
        // Загружаем адрес для текущей позиции (начальной или заданной)
        _updateAddressDebounced(_selectedLocation);
      }
    });
  }

  @override
  void dispose() {
    _geocodeTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ────────────────────────── Геокодинг ──────────────────────────
  /// Получение адреса по координатам через OpenStreetMap Nominatim API
  /// ⚡️ Используем HTTP API вместо плагина для надёжности
  Future<String?> _reverseGeocode(LatLng location) async {
    try {
      // OpenStreetMap Nominatim API (бесплатно, без ключей)
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'format=json&'
        'lat=${location.latitude}&'
        'lon=${location.longitude}&'
        'zoom=18&'
        'addressdetails=1&'
        'accept-language=ru',
      );

      final response = await http
          .get(
            url,
            headers: {
              'User-Agent':
                  'PaceUp/1.0 (paceup.ru)', // Обязательно для Nominatim
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        debugPrint('[LocationPicker] HTTP ошибка: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;

      if (address == null) {
        debugPrint('[LocationPicker] Геокодинг: адрес не найден');
        return null;
      }

      // Формируем читаемый адрес из доступных частей
      final parts = <String>[];

      // Улица и номер дома
      if (address['road'] != null && (address['road'] as String).isNotEmpty) {
        final road = address['road'] as String;
        final houseNumber = address['house_number'] as String?;
        if (houseNumber != null && houseNumber.isNotEmpty) {
          parts.add('$road, $houseNumber');
        } else {
          parts.add(road);
        }
      }

      // Населённый пункт (город, посёлок и т.д.)
      final city =
          address['city'] as String? ??
          address['town'] as String? ??
          address['village'] as String? ??
          address['municipality'] as String?;

      if (city != null && city.isNotEmpty) {
        parts.add(city);
      }

      // Регион/область
      if (parts.isEmpty) {
        final region =
            address['state'] as String? ??
            address['county'] as String? ??
            address['region'] as String?;
        if (region != null && region.isNotEmpty) {
          parts.add(region);
        }
      }

      final result = parts.isEmpty ? null : parts.join(', ');
      debugPrint('[LocationPicker] Геокодинг успешен: $result');
      return result;
    } catch (e, stackTrace) {
      // ⚠️ В случае ошибки геокодинга логируем для отладки
      debugPrint('[LocationPicker] Ошибка геокодинга: $e');
      debugPrint('[LocationPicker] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Обновление адреса при изменении координат (с задержкой для оптимизации)
  void _updateAddressDebounced(LatLng location) {
    // Отменяем предыдущий таймер, если он был
    _geocodeTimer?.cancel();

    // Устанавливаем состояние загрузки
    if (!_isGeocoding) {
      setState(() {
        _isGeocoding = true;
        _currentAddress = null; // Очищаем предыдущий адрес
      });
    }

    // ⚡️ Запускаем новый таймер для debounce
    _geocodeTimer = Timer(const Duration(milliseconds: 800), () async {
      if (!mounted) return;

      debugPrint(
        '[LocationPicker] Запуск геокодинга для: ${location.latitude}, ${location.longitude}',
      );

      final address = await _reverseGeocode(location);

      if (!mounted) return;

      setState(() {
        _currentAddress = address;
        _isGeocoding = false;
      });
    });
  }

  // ────────────────────────── Обработка выбора ──────────────────────────
  /// Подтверждение выбора места и возврат координат с адресом
  Future<void> _confirmSelection() async {
    // Если адрес ещё не загружен, выполняем геокодинг перед возвратом
    String? finalAddress = _currentAddress;
    if (finalAddress == null && !_isGeocoding) {
      finalAddress = await _reverseGeocode(_selectedLocation);
    }

    if (!mounted) return;

    Navigator.of(context).pop(
      LocationResult(coordinates: _selectedLocation, address: finalAddress),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Stack(
          children: [
            // ────────────────────────── Карта ──────────────────────────
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedLocation,
                initialZoom: 14.0, // Ближе для удобного выбора места
                minZoom: 3.0,
                maxZoom: 19.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                // ⚡️ Обновляем координаты при движении карты в реальном времени
                onPositionChanged: (MapCamera position, bool hasGesture) {
                  if (hasGesture && mounted) {
                    setState(() {
                      _selectedLocation = position.center;
                      // Сбрасываем адрес при движении (будет обновлён через debounce)
                      _currentAddress = null;
                    });
                    // Обновляем адрес с задержкой для оптимизации
                    _updateAddressDebounced(position.center);
                  }
                },
              ),
              children: [
                // Тайлы карты MapTiler
                TileLayer(
                  urlTemplate: AppConfig.mapTilesUrl,
                  additionalOptions: {'apiKey': AppConfig.mapTilerApiKey},
                  userAgentPackageName: 'paceup.ru',
                  maxZoom: 19,
                  minZoom: 3,
                  keepBuffer: 1,
                  retinaMode: false,
                ),

                // Атрибуция
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('MapTiler © OpenStreetMap'),
                  ],
                ),

                // 📌 Центральный маркер (показывается в текущей позиции)
                // ⚠️ Важно: маркер привязан к координатам, но всегда будет виден,
                // так как при движении карты мы обновляем _selectedLocation
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation,
                      width: 32,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Иконка маркера
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.brandPrimary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 3,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.shadowMedium,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.placemark_fill,
                              size: 18,
                              color: AppColors.surface,
                            ),
                          ),
                          // Треугольник под маркером
                          CustomPaint(
                            size: const Size(16, 10),
                            painter: _MarkerTrianglePainter(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ────────────────────────── Подсказка с адресом сверху ──────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadowMedium,
                      blurRadius: 1,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _currentAddress != null
                            ? Text(
                                _currentAddress!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : _isGeocoding
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CupertinoActivityIndicator(
                                      radius: 7,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Определение адреса...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'Перемещайте карту, чтобы выбрать место',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Inter',
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ────────────────────────── Кнопка "Выбрать" внизу ──────────────────────────
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: PrimaryButton(
                    text: 'Выбрать место',
                    onPressed: _confirmSelection,
                    expanded: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── Кастомный painter для треугольника маркера ──────────────────────────
class _MarkerTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brandPrimary
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(size.width / 2, size.height) // нижняя точка (центр)
      ..lineTo(0, 0) // левая верхняя точка
      ..lineTo(size.width, 0) // правая верхняя точка
      ..close();

    canvas.drawPath(path, paint);

    // Обводка треугольника
    final strokePaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
