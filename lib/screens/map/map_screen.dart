import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../config/app_config.dart';

// контент вкладок
import 'events/events_screen.dart' as ev;
import 'clubs/clubs_screen.dart' as clb;
import 'slots/slots_screen.dart' as slt;
import 'travelers/travelers_screen.dart' as trv;

// нижние выезжающие окна
import 'events/events_bottom_sheet.dart' as ebs;
import 'clubs/widgets/clubs_bottom_sheet.dart' as cbs;
import 'slots/slots_bottom_sheet.dart' as sbs;
import 'travelers/travelers_bottom_sheet.dart' as tbs;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _selectedIndex = 0;

  final tabs = const ["События", "Клубы", "Слоты", "Попутчики"];

  /// Цвета маркеров по вкладкам
  final markerColors = const {
    0: AppColors.accentBlue, // события
    1: AppColors.error, // клубы
    2: AppColors.success, // слоты
    3: AppColors.accentPurple, // попутчики
  };

  // Состояние для маркеров событий (загружаются через API)
  List<Map<String, dynamic>> _eventsMarkers = [];
  bool _eventsLoading = false;

  @override
  void initState() {
    super.initState();
    // Загружаем маркеры событий при инициализации
    _loadEventsMarkers();
  }

  /// Загрузка маркеров событий через API
  Future<void> _loadEventsMarkers() async {
    if (_selectedIndex != 0) return; // Загружаем только для вкладки событий

    setState(() => _eventsLoading = true);
    try {
      final markers = await ev.eventsMarkersAsync();
      if (mounted) {
        setState(() {
          _eventsMarkers = markers;
          _eventsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _eventsMarkers = [];
          _eventsLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _markersForTab(BuildContext context) {
    switch (_selectedIndex) {
      case 0:
        return _eventsMarkers; // Используем загруженные через API маркеры
      case 1:
        return clb.clubsMarkers(context);
      case 2:
        return slt.slotsMarkers(context);
      case 3:
      default:
        return trv.travelersMarkers(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = _markersForTab(context);
    final markerColor = markerColors[_selectedIndex] ?? AppColors.brandPrimary;

    return Scaffold(
      body: Stack(
        children: [
          /// ───────── Карта
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(56.129057, 40.406635),
              initialZoom: 6.0,
            ),
            children: [
              TileLayer(
                urlTemplate: AppConfig.mapTilesUrl,
                additionalOptions: {'apiKey': AppConfig.mapTilerApiKey},
                userAgentPackageName: 'paceup.ru',
                maxZoom: 19,
                minZoom: 3,
                keepBuffer: 1,
                retinaMode: false,
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'MapTiler © OpenStreetMap',
                    // onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
                  ),
                ],
                // (необязательно) место и отступы подписи
                // popupInitialDisplayDuration: const Duration(seconds: 0),
              ),
              MarkerLayer(
                markers: markers.map((m) {
                  final LatLng point = m['point'] as LatLng;
                  final String title = m['title'] as String;
                  final int count = m['count'] as int;

                  return Marker(
                    point: point,
                    width: 28,
                    height: 28,
                    child: GestureDetector(
                      onTap: () {
                        final Widget sheet = () {
                          switch (_selectedIndex) {
                            case 0:
                              // Получаем список событий из маркера
                              final events = m['events'] as List? ?? [];
                              return ebs.EventsBottomSheet(
                                title: title,
                                latitude: m['latitude'] as double?,
                                longitude: m['longitude'] as double?,
                                events: events,
                              );
                            case 1:
                              return cbs.ClubsBottomSheet(
                                title: title,
                                child:
                                    content ??
                                    const cbs.ClubsSheetPlaceholder(),
                              );
                            case 2:
                              return sbs.SlotsBottomSheet(
                                title: title,
                                child:
                                    content ??
                                    const sbs.SlotsSheetPlaceholder(),
                              );
                            case 3:
                            default:
                              return tbs.TravelersBottomSheet(
                                title: title,
                                child:
                                    content ??
                                    const tbs.TravelersSheetPlaceholder(),
                              );
                          }
                        }();

                        showModalBottomSheet(
                          context: context,
                          useRootNavigator: true,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => sheet,
                        );
                      },

                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: markerColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: AppColors.surface,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          /// ───────── Верхняя панель вкладок (та же эстетика, что была)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 10,
            right: 10,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
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
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(tabs.length, (index) {
                    final isSelected = _selectedIndex == index;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedIndex = index);
                        // Перезагружаем маркеры при переключении на вкладку событий
                        if (index == 0) {
                          _loadEventsMarkers();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.textPrimary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        child: Text(
                          tabs[index],
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: isSelected
                                ? AppColors.surface
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          if (_selectedIndex == 0) const ev.EventsFloatingButtons(),
          if (_selectedIndex == 1) const clb.ClubsFloatingButtons(),
          if (_selectedIndex == 2) const slt.SlotsFloatingButtons(),
          if (_selectedIndex == 3) const trv.TravelersFloatingButtons(),
        ],
      ),
    );
  }
}
