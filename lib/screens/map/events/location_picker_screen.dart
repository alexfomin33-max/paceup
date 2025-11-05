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

  /// Контроллер для текстового поля адреса
  late final TextEditingController _addressController;

  /// Флаг ручного ввода адреса (чтобы не перезаписывать при движении карты)
  bool _isManualInput = false;

  /// Таймер для debounce прямого геокодинга (поиск координат по адресу)
  Timer? _forwardGeocodeTimer;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _addressController = TextEditingController();

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
    _forwardGeocodeTimer?.cancel();
    _addressController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ────────────────────────── Геокодинг ──────────────────────────
  /// Прямой геокодинг: поиск координат по адресу через OpenStreetMap Nominatim API
  /// ⚡️ Используем HTTP API для надёжности
  Future<LatLng?> _forwardGeocode(String address) async {
    try {
      if (address.trim().isEmpty) {
        return null;
      }

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'format=json&'
        'q=${Uri.encodeComponent(address)}&'
        'limit=1&'
        'addressdetails=1&'
        'accept-language=ru',
      );

      final response = await http
          .get(url, headers: {'User-Agent': 'PaceUp/1.0 (paceup.ru)'})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        debugPrint(
          '[LocationPicker] HTTP ошибка прямого геокодинга: ${response.statusCode}',
        );
        return null;
      }

      final data = json.decode(response.body) as List<dynamic>;
      if (data.isEmpty) {
        debugPrint('[LocationPicker] Адрес не найден: $address');
        return null;
      }

      final firstResult = data[0] as Map<String, dynamic>;
      final lat = double.tryParse(firstResult['lat']?.toString() ?? '');
      final lon = double.tryParse(firstResult['lon']?.toString() ?? '');

      if (lat == null || lon == null) {
        debugPrint('[LocationPicker] Некорректные координаты в ответе');
        return null;
      }

      final result = LatLng(lat, lon);
      debugPrint(
        '[LocationPicker] Прямой геокодинг успешен: $address -> $lat, $lon',
      );
      return result;
    } catch (e, stackTrace) {
      debugPrint('[LocationPicker] Ошибка прямого геокодинга: $e');
      debugPrint('[LocationPicker] Stack trace: $stackTrace');
      return null;
    }
  }

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

      // Формируем читаемый адрес из доступных частей (город -> улица -> регион)
      final parts = <String>[];

      // Населённый пункт (город, посёлок и т.д.) — ставим первым
      final city =
          address['city'] as String? ??
          address['town'] as String? ??
          address['village'] as String? ??
          address['municipality'] as String?;

      if (city != null && city.isNotEmpty) {
        parts.add(city);
      }

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

      // Регион/область (если ничего больше нет)
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
  /// ⚠️ Не обновляет поле ввода, если пользователь вводит адрес вручную
  void _updateAddressDebounced(LatLng location) {
    // Пропускаем обновление, если пользователь вводит адрес вручную
    if (_isManualInput) {
      return;
    }

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
      if (!mounted || _isManualInput) return;

      debugPrint(
        '[LocationPicker] Запуск геокодинга для: ${location.latitude}, ${location.longitude}',
      );

      final address = await _reverseGeocode(location);

      if (!mounted || _isManualInput) return;

      setState(() {
        _currentAddress = address;
        _isGeocoding = false;
        // Обновляем поле ввода только если пользователь не редактирует его
        if (!_isManualInput && address != null) {
          _addressController.text = address;
        }
      });
    });
  }

  /// Обработка ввода адреса в текстовое поле
  /// Выполняет прямой геокодинг (поиск координат по адресу) с задержкой
  void _onAddressChanged(String value) {
    if (value.isEmpty) {
      // Если поле пустое, сбрасываем флаг ручного ввода
      setState(() {
        _isManualInput = false;
      });
      return;
    }

    // Устанавливаем флаг ручного ввода
    if (!_isManualInput) {
      setState(() {
        _isManualInput = true;
      });
    }

    // Отменяем предыдущий таймер
    _forwardGeocodeTimer?.cancel();

    // Устанавливаем состояние загрузки
    if (!_isGeocoding) {
      setState(() {
        _isGeocoding = true;
      });
    }

    // ⚡️ Запускаем поиск координат с задержкой для оптимизации
    _forwardGeocodeTimer = Timer(const Duration(milliseconds: 1000), () async {
      if (!mounted) return;

      debugPrint('[LocationPicker] Поиск координат для адреса: $value');

      final coordinates = await _forwardGeocode(value);

      if (!mounted) return;

      if (coordinates != null) {
        // Перемещаем карту к найденным координатам
        _mapController.move(coordinates, _mapController.camera.zoom);
        setState(() {
          _selectedLocation = coordinates;
          _currentAddress = value;
          _isGeocoding = false;
        });
      } else {
        // Адрес не найден, но оставляем введённый текст
        setState(() {
          _isGeocoding = false;
          _currentAddress = value; // Сохраняем введённый адрес
        });
      }
    });
  }

  // ────────────────────────── Обработка выбора ──────────────────────────
  /// Подтверждение выбора места и возврат координат с адресом
  Future<void> _confirmSelection() async {
    // Если пользователь ввёл адрес вручную, используем его
    String? finalAddress = _addressController.text.trim().isNotEmpty
        ? _addressController.text.trim()
        : _currentAddress;

    // Если адрес ещё не загружен и не введён вручную, выполняем геокодинг перед возвратом
    if (finalAddress == null || finalAddress.isEmpty) {
      if (!_isGeocoding) {
        finalAddress = await _reverseGeocode(_selectedLocation);
      }
    }

    if (!mounted) return;

    Navigator.of(context).pop(
      LocationResult(
        coordinates: _selectedLocation,
        address: finalAddress?.isEmpty == true ? null : finalAddress,
      ),
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

            // ────────────────────────── Поле ввода адреса сверху ──────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
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
                      child: TextField(
                        controller: _addressController,
                        onChanged: _onAddressChanged,
                        onTap: () {
                          // При фокусе на поле устанавливаем флаг ручного ввода
                          if (!_isManualInput) {
                            setState(() {
                              _isManualInput = true;
                            });
                          }
                        },
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: _isGeocoding
                              ? 'Поиск адреса...'
                              : 'Введите адрес или перемещайте карту',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontFamily: 'Inter',
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) {
                          // При нажатии Enter/Поиск завершаем редактирование
                          setState(() {
                            _isManualInput = false;
                          });
                          // Скрываем клавиатуру
                          FocusScope.of(context).unfocus();
                        },
                        onEditingComplete: () {
                          // При завершении редактирования сбрасываем флаг
                          setState(() {
                            _isManualInput = false;
                          });
                        },
                      ),
                    ),
                    // Индикатор загрузки при геокодинге
                    if (_isGeocoding)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CupertinoActivityIndicator(radius: 7),
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
