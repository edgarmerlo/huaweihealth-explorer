import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/models/track_point.dart';

class MapPreviewWidget extends StatelessWidget {
  final List<TrackPoint> trackPoints;
  final bool isInteractive;
  final double height;

  const MapPreviewWidget({
    super.key,
    required this.trackPoints,
    this.isInteractive = true,
    this.height = 280,
  });

  @override
  Widget build(BuildContext context) {
    if (trackPoints.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_outlined, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text('No GPS track recorded for this activity', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final points = trackPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final bounds = LatLngBounds.fromPoints(points);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(32),
            ),
            interactionOptions: InteractionOptions(
              flags: isInteractive ? InteractiveFlag.all : InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.huaweihealth.exporter',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 4.5,
                  color: Colors.deepOrangeAccent,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                // Start Marker
                Marker(
                  point: points.first,
                  width: 32,
                  height: 32,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                  ),
                ),
                // End Marker
                Marker(
                  point: points.last,
                  width: 32,
                  height: 32,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
