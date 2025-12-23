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
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:http/http.dart' as http;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/config/app_config.dart';

// ────────────────────────── Результат выбора места ──────────────────────────
/// Класс для передачи координат и адреса выбранного места
class LocationResult {
  final LatLng coordinates;
  final String? address; // может быть null, если геокодинг не удался

  const LocationResult({required this.coordinates, this.address});
}

class LocationPickerScreen extends ConsumerStatefulWidget {
  /// Начальная позиция на карте (если не указана — центр России)
  final LatLng? initialPosition;

  const LocationPickerScreen({super.key, this.initialPosition});

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  // ────────────────────────── Контроллер карты ──────────────────────────
  /// Контроллер для управления картой и отслеживания позиции
  MapboxMap? _mapboxMap;

  /// Контроллер flutter_map для macOS
  final flutter_map.MapController _flutterMapController =
      flutter_map.MapController();

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
    _addressController = TextEditingController();

    // Устанавливаем начальную позицию
    if (widget.initialPosition != null) {
      _selectedLocation = widget.initialPosition!;
    }
  }

  @override
  void dispose() {
    _geocodeTimer?.cancel();
    _forwardGeocodeTimer?.cancel();
    _addressController.dispose();
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
        if (kDebugMode) {
          debugPrint(
            '[LocationPicker] HTTP ошибка прямого геокодинга: ${response.statusCode}',
          );
        }
        return null;
      }

      final data = json.decode(response.body) as List<dynamic>;
      if (data.isEmpty) {
        if (kDebugMode) {
          debugPrint('[LocationPicker] Адрес не найден: $address');
        }
        return null;
      }

      final firstResult = data[0] as Map<String, dynamic>;
      final lat = double.tryParse(firstResult['lat']?.toString() ?? '');
      final lon = double.tryParse(firstResult['lon']?.toString() ?? '');

      if (lat == null || lon == null) {
        if (kDebugMode) {
          debugPrint('[LocationPicker] Некорректные координаты в ответе');
        }
        return null;
      }

      final result = LatLng(lat, lon);
      if (kDebugMode) {
        debugPrint(
          '[LocationPicker] Прямой геокодинг успешен: $address -> $lat, $lon',
        );
      }
      return result;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[LocationPicker] Ошибка прямого геокодинга: $e');
        debugPrint('[LocationPicker] Stack trace: $stackTrace');
      }
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
        if (kDebugMode) {
          debugPrint('[LocationPicker] HTTP ошибка: ${response.statusCode}');
        }
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;

      if (address == null) {
        if (kDebugMode) {
          debugPrint('[LocationPicker] Геокодинг: адрес не найден');
        }
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
      if (kDebugMode) {
        debugPrint('[LocationPicker] Геокодинг успешен: $result');
      }
      return result;
    } catch (e, stackTrace) {
      // ⚠️ В случае ошибки геокодинга логируем для отладки
      if (kDebugMode) {
        debugPrint('[LocationPicker] Ошибка геокодинга: $e');
        debugPrint('[LocationPicker] Stack trace: $stackTrace');
      }
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

      if (kDebugMode) {
        debugPrint(
          '[LocationPicker] Запуск геокодинга для: ${location.latitude}, ${location.longitude}',
        );
      }

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

      if (kDebugMode) {
        debugPrint('[LocationPicker] Поиск координат для адреса: $value');
      }

      final coordinates = await _forwardGeocode(value);

      if (!mounted) return;

      if (coordinates != null) {
        // Перемещаем карту к найденным координатам
        if (Platform.isMacOS) {
          _flutterMapController.move(coordinates, 14.0);
        } else {
          try {
            await _mapboxMap?.flyTo(
              CameraOptions(
                center: Point(
                  coordinates: Position(
                    coordinates.longitude,
                    coordinates.latitude,
                  ),
                ),
              ),
              MapAnimationOptions(duration: 500, startDelay: 0),
            );
          } catch (flyToError) {
            // Если канал еще не готов, логируем и продолжаем работу
            if (kDebugMode) {
              debugPrint(
                '⚠️ Не удалось переместить камеру карты: $flyToError',
              );
            }
          }
        }
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
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      body: Stack(
        children: [
          // ────────────────────────── Карта ──────────────────────────
          // Используем flutter_map для macOS
          if (Platform.isMacOS)
            flutter_map.FlutterMap(
              mapController: _flutterMapController,
              options: flutter_map.MapOptions(
                initialCenter: _selectedLocation,
                initialZoom: 14.0,
                minZoom: 3.0,
                maxZoom: 18.0,
                onMapEvent: (event) {
                  if (event is flutter_map.MapEventMoveEnd) {
                    final newLocation = _flutterMapController.camera.center;
                    setState(() {
                      _selectedLocation = newLocation;
                      _currentAddress = null;
                    });
                    _updateAddressDebounced(newLocation);
                  }
                },
              ),
              children: [
                flutter_map.TileLayer(
                  urlTemplate: AppConfig.mapTilesUrl.replaceAll(
                    '{apiKey}',
                    AppConfig.mapTilerApiKey,
                  ),
                  userAgentPackageName: 'com.example.paceup',
                ),
              ],
            )
          else
            MapWidget(
              onMapIdleListener: (MapIdleEventData data) async {
                if (!mounted || _mapboxMap == null) return;
                try {
                  final cameraState = await _mapboxMap!.getCameraState();
                  if (!mounted) return;
                  final center = cameraState.center;
                  final newLocation = LatLng(
                    center.coordinates.lat.toDouble(),
                    center.coordinates.lng.toDouble(),
                  );
                  setState(() {
                    _selectedLocation = newLocation;
                    _currentAddress = null;
                  });
                  _updateAddressDebounced(newLocation);
                } catch (cameraError) {
                  // Если канал еще не готов, логируем и продолжаем работу
                  if (kDebugMode) {
                    debugPrint(
                      '⚠️ Не удалось получить состояние камеры: $cameraError',
                    );
                  }
                }
              },
              onMapCreated: (MapboxMap mapboxMap) async {
                _mapboxMap = mapboxMap;

                // ────────────────────────── Отключаем масштабную линейку ──────────────────────────
                // Отключаем горизонтальную линию масштаба, которая отображается сверху слева
                try {
                  await mapboxMap.scaleBar.updateSettings(
                    ScaleBarSettings(enabled: false),
                  );
                } catch (e) {
                  // Если метод недоступен, игнорируем ошибку
                }

                // Устанавливаем начальную позицию с обработкой ошибок канала
                if (widget.initialPosition != null) {
                  try {
                    await mapboxMap.flyTo(
                      CameraOptions(
                        center: Point(
                          coordinates: Position(
                            widget.initialPosition!.longitude,
                            widget.initialPosition!.latitude,
                          ),
                        ),
                        zoom: 14.0,
                      ),
                      MapAnimationOptions(duration: 0, startDelay: 0),
                    );
                  } catch (flyToError) {
                    // Если канал еще не готов, логируем и продолжаем работу
                    if (kDebugMode) {
                      debugPrint(
                        '⚠️ Не удалось установить начальную позицию карты: $flyToError',
                      );
                    }
                  }
                  if (!mounted) return;
                  setState(() {
                    _selectedLocation = widget.initialPosition!;
                  });
                }

                // Загружаем адрес для текущей позиции
                _updateAddressDebounced(_selectedLocation);
              },
              cameraOptions: CameraOptions(
                center: Point(
                  coordinates: Position(
                    _selectedLocation.longitude,
                    _selectedLocation.latitude,
                  ),
                ),
                zoom: 14.0,
              ),
              styleUri: MapboxStyles.MAPBOX_STREETS,
            ),

          // ────────────────────────── Центральный пикер ──────────────────────────
          // Тонкая черная палочка с красным кружком сверху
          Center(
            child: SizedBox(
              width: 3,
              height: 32,
              child: CustomPaint(painter: _PinStickPainter()),
            ),
          ),

          // ────────────────────────── Поле ввода адреса сверху ──────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    );
  }
}

// ────────────────────────── Кастомный painter для булавки-палочки ──────────────────────────
/// Рисует тонкую черную палочку с маленьким красным кружком сверху
class _PinStickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, ui.Size size) {
    final centerX = size.width / 2;
    final stickTopY = 0.0;
    final stickBottomY = size.height;

    // Тонкая черная палочка (вертикальная линия)
    final stickPaint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(centerX, stickTopY + 8), // Начинаем чуть ниже красного кружка
      Offset(centerX, stickBottomY),
      stickPaint,
    );

    // Маленький красный кружок сверху
    final redCirclePaint = Paint()
      ..color = AppColors.red
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(centerX, stickTopY + 4), 4, redCirclePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
