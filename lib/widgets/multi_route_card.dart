// lib/widgets/multi_route_card.dart
// ─────────────────────────────────────────────────────────────────────────────
// Static map card with one or multiple routes.
//  • Background: MapTiler Streets v2 (same as RouteCard) + attribution.
//  • Camera fits bounds in onMapReady.
//  • Fully non-interactive (InteractionOptions.none + IgnorePointer).
//  • Safe with empty data.
// Requires: flutter_map, latlong2.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';

class MultiRouteCard extends StatefulWidget {
  const MultiRouteCard({super.key, required this.polylines, this.height = 200});

  /// Set of routes. Each route is an ordered list of LatLng points.
  final List<List<LatLng>> polylines;

  /// Map height.
  final double height;

  @override
  State<MultiRouteCard> createState() => _MultiRouteCardState();
}

class _MultiRouteCardState extends State<MultiRouteCard> {
  final MapController _mapController = MapController();

  bool _mapReady = false;
  LatLngBounds? _lastBounds;

  // Toggle to quickly switch to OSM if MapTiler key/quota misbehaves.
  static const bool kUseMapTiler = false;

  @override
  void didUpdateWidget(covariant MultiRouteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapReady && !_routesDeepEqual(oldWidget.polylines, widget.polylines)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToRoutes());
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPoints = _collectAllPoints(widget.polylines);
    final initialCenter = allPoints.isNotEmpty
        ? _centerFromPoints(allPoints)
        : const LatLng(55.751244, 37.618423); // Moscow fallback

    if (allPoints.length < 2) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: const Center(
          child: Text('Нет точек маршрута', style: AppTextStyles.h12w4Ter),
        ),
      );
    }

    final tileLayers = <Widget>[
      if (kUseMapTiler) ...[
        TileLayer(
          urlTemplate:
              'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={apiKey}',
          additionalOptions: const {
            // TODO: move to secrets/config in production.
            'apiKey': '5Ssg96Nz79IHOCKB0MLL',
          },
          keepBuffer: 1,
          retinaMode: true,
          maxZoom: 18,
          minZoom: 3,
          userAgentPackageName: 'paceup.ru',
        ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('MapTiler © OpenStreetMap')],
        ),
      ] else ...[
        // Fallback: OSM tiles
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'paceup.ru',
        ),
      ],
    ];

    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: IgnorePointer(
        ignoring: true, // make it a "picture"
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 12,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
            backgroundColor: Colors.transparent,
            onMapReady: () {
              _mapReady = true;
              _fitToRoutes();
            },
          ),
          children: [
            ...tileLayers,
            PolylineLayer(
              polylines: widget.polylines.map((points) {
                return Polyline(
                  points: points,
                  strokeWidth: 3.0, // match RouteCard
                  color: AppColors.brandPrimary,
                  strokeCap: StrokeCap.round,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────── Helpers ────────────────────────────

  void _fitToRoutes() {
    final allPoints = _collectAllPoints(widget.polylines);
    if (allPoints.length < 2) return;

    final bounds = _computeBounds(allPoints);
    if (bounds == null) return;

    if (_boundsEqual(bounds, _lastBounds)) return;
    _lastBounds = bounds;

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(12)),
    );
  }

  List<LatLng> _collectAllPoints(List<List<LatLng>> routes) {
    final out = <LatLng>[];
    for (final r in routes) {
      if (r.length >= 2) out.addAll(r);
    }
    return out;
  }

  LatLng _centerFromPoints(List<LatLng> pts) {
    double lat = 0, lng = 0;
    for (final p in pts) {
      lat += p.latitude;
      lng += p.longitude;
    }
    final n = pts.length.toDouble();
    return LatLng(lat / n, lng / n);
  }

  LatLngBounds? _computeBounds(List<LatLng> pts) {
    if (pts.length < 2) return null;
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  bool _boundsEqual(LatLngBounds? a, LatLngBounds? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.southWest.latitude == b.southWest.latitude &&
        a.southWest.longitude == b.southWest.longitude &&
        a.northEast.latitude == b.northEast.latitude &&
        a.northEast.longitude == b.northEast.longitude;
  }

  bool _routesDeepEqual(List<List<LatLng>> a, List<List<LatLng>> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final r1 = a[i], r2 = b[i];
      if (r1.length != r2.length) return false;
      for (var j = 0; j < r1.length; j++) {
        final p1 = r1[j], p2 = r2[j];
        if (p1.latitude != p2.latitude || p1.longitude != p2.longitude) {
          return false;
        }
      }
    }
    return true;
  }
}
