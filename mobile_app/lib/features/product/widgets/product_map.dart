import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:product_traceability_mobile/core/theme/app_theme.dart';

class ProductMap extends StatefulWidget {
  final List<String> locations; // "lat,long" strings

  const ProductMap({super.key, required this.locations});

  @override
  State<ProductMap> createState() => _ProductMapState();
}

class _ProductMapState extends State<ProductMap> {
  List<LatLng> _points = [];

  @override
  void initState() {
    super.initState();
    _parseLocations();
  }

  void _parseLocations() {
    _points = [];
    for (var loc in widget.locations) {
      try {
        final parts = loc.split(',');
        if (parts.length == 2) {
          final lat = double.tryParse(parts[0].trim());
          final lng = double.tryParse(parts[1].trim());
          if (lat != null && lng != null) {
            _points.add(LatLng(lat, lng));
          }
        }
      } catch (e) {
        // Ignore invalid locations
      }
    }
  }

  @override
  void didUpdateWidget(covariant ProductMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locations != widget.locations) {
      _parseLocations();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_points.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text("No location data available")),
      );
    }

    // Determine bounds
    final bounds = LatLngBounds.fromPoints(_points);
    // Add some padding to bounds so points aren't on edge
    // Simple way: just center on the first point or average
    final center = _points.isNotEmpty ? _points.last : const LatLng(0, 0);

    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 10,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate, // Disable rotation
          ),
          onMapReady: () {
             // Could fit bounds here if controller was available
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.product_traceability_mobile',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: _points,
                color: AppTheme.primaryColor,
                strokeWidth: 4,
              ),
            ],
          ),
          MarkerLayer(
            markers: _points.asMap().entries.map((entry) {
              final index = entry.key;
              final point = entry.value;
              final isStart = index == 0;
              final isCurrent = index == _points.length - 1;

              return Marker(
                point: point,
                width: 40,
                height: 40,
                child: Icon(
                  isStart ? Icons.factory : Icons.store,
                  color: isCurrent ? Colors.red : AppTheme.primaryColor,
                  size: 32,
                  shadows: const [
                    Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
