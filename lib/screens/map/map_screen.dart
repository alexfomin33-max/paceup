import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// контент вкладок
import 'events/events_screen.dart' as ev;
import 'clubs/clubs_screen.dart' as clb;
import 'slots/slots_screen.dart' as slt;
import 'travelers/travelers_screen.dart' as trv;

// нижние выезжающие окна
import 'events/events_bottom_sheet.dart' as ebs;
import 'clubs/clubs_bottom_sheet.dart' as cbs;
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
    0: Colors.blue, // события
    1: Colors.red, // клубы
    2: Colors.orange, // слоты
    3: Colors.purple, // попутчики
  };

  List<Map<String, dynamic>> _markersForTab(BuildContext context) {
    switch (_selectedIndex) {
      case 0:
        return ev.eventsMarkers(context);
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
    final markerColor = markerColors[_selectedIndex] ?? Colors.blue;

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
                // без поддоменов, корректный User-Agent
                //urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                urlTemplate: 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={apiKey}',
                additionalOptions: {'apiKey': '5Ssg96Nz79IHOCKB0MLL'},
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
                  final Widget? content = m['content'] as Widget?;

                  return Marker(
                    point: point,
                    width: 28,
                    height: 28,
                    child: GestureDetector(
                      onTap: () {
                        final Widget sheet = () {
                          switch (_selectedIndex) {
                            case 0:
                              return ebs.EventsBottomSheet(
                                title: title,
                                child:
                                    content ??
                                    const ebs.EventsSheetPlaceholder(),
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
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
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
                      onTap: () => setState(() => _selectedIndex = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.black87
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tabs[index],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.black87,
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
