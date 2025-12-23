import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// ──────────── Виджет Mapbox карты (общий) ────────────
/// Инкапсулирует MapWidget и позволяет переиспользовать на разных экранах.
class MapView extends StatelessWidget {
  const MapView({
    super.key,
    required this.mapKey,
    required this.onMapCreated,
    required this.onTapListener,
    required this.cameraOptions,
    this.styleUri = MapboxStyles.MAPBOX_STREETS,
  });

  final Key mapKey;
  final void Function(MapboxMap) onMapCreated;
  final OnMapTapListener onTapListener;
  final CameraOptions cameraOptions;
  final String styleUri;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: MapWidget(
        key: mapKey,
        onTapListener: onTapListener,
        onMapCreated: onMapCreated,
        cameraOptions: cameraOptions,
        styleUri: styleUri,
      ),
    );
  }
}

