import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart' as latlong;

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';

/// ──────────── Виджет flutter_map для macOS ────────────
/// Содержит только отрисовку и простую подстройку камеры.
class MapViewMac extends StatelessWidget {
  const MapViewMac({
    super.key,
    required this.markers,
    required this.markerColor,
    required this.mapController,
    required this.mapInitialized,
    required this.onMarkerTap,
    required this.selectedIndex,
  });

  final List<Map<String, dynamic>> markers;
  final Color markerColor;
  final flutter_map.MapController mapController;
  final bool mapInitialized;
  final ValueChanged<Map<String, dynamic>> onMarkerTap;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    latlong.LatLng center = const latlong.LatLng(56.129057, 40.406635);
    double zoom = 6.0;

    final points = markers
        .map((m) => m['point'] as latlong.LatLng?)
        .whereType<latlong.LatLng>()
        .toList();

    if (points.isNotEmpty) {
      if (points.length == 1) {
        center = points.first;
        zoom = 12.0;
      } else {
        double sumLat = 0, sumLng = 0;
        for (final point in points) {
          sumLat += point.latitude;
          sumLng += point.longitude;
        }
        center = latlong.LatLng(sumLat / points.length, sumLng / points.length);
        zoom = 10.0;
      }
    }

    if (!mapInitialized && points.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (points.length > 1) {
          double minLat = points.first.latitude;
          double maxLat = points.first.latitude;
          double minLng = points.first.longitude;
          double maxLng = points.first.longitude;
          for (final point in points) {
            minLat = minLat < point.latitude ? minLat : point.latitude;
            maxLat = maxLat > point.latitude ? maxLat : point.latitude;
            minLng = minLng < point.longitude ? minLng : point.longitude;
            maxLng = maxLng > point.longitude ? maxLng : point.longitude;
          }
          mapController.fitCamera(
            flutter_map.CameraFit.bounds(
              bounds: flutter_map.LatLngBounds(
                latlong.LatLng(minLat, minLng),
                latlong.LatLng(maxLat, maxLng),
              ),
              padding: const EdgeInsets.all(30),
            ),
          );
        } else if (points.length == 1) {
          mapController.move(points.first, 12.0);
        }
      });
    }

    final mapKey = ValueKey('flutter_map_$selectedIndex');

    return SizedBox.expand(
      child: flutter_map.FlutterMap(
        key: mapKey,
        mapController: mapController,
        options: flutter_map.MapOptions(
          initialCenter: center,
          initialZoom: zoom,
          minZoom: 3.0,
          maxZoom: 18.0,
        ),
        children: [
          flutter_map.TileLayer(
            urlTemplate: AppConfig.mapTilesUrl.replaceAll(
              '{apiKey}',
              AppConfig.mapTilerApiKey,
            ),
            userAgentPackageName: 'com.example.paceup',
          ),
          flutter_map.MarkerLayer(
            markers: markers.map((marker) {
              final point = marker['point'] as latlong.LatLng?;
              if (point == null) {
                return const flutter_map.Marker(
                  point: latlong.LatLng(0, 0),
                  width: 0,
                  height: 0,
                  child: SizedBox.shrink(),
                );
              }

              final count = marker['count'] as int? ?? 0;
              final isOfficial = marker['is_official'] as bool? ?? false;
              final color = isOfficial ? AppColors.error : markerColor;

              return flutter_map.Marker(
                point: point,
                width: 64,
                height: 64,
                child: GestureDetector(
                  onTap: () => onMarkerTap(marker),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: AppColors.surface,
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

