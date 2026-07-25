import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../presentation/user_app/map/map_screen.dart';

class PlaceMapWidget extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String placeName;
  final String? address;

  const PlaceMapWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.placeName,
    this.address,
  });

  @override
  State<PlaceMapWidget> createState() => _PlaceMapWidgetState();
}

class _PlaceMapWidgetState extends State<PlaceMapWidget> {
  static const double _defaultZoom = 15.0;

  void _openMapScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapScreen(
          latitude: widget.latitude,
          longitude: widget.longitude,
          placeName: widget.placeName,
          address: widget.address,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hide if coordinates are default/missing
    if (widget.latitude == 0.0 && widget.longitude == 0.0) {
      return const SizedBox.shrink();
    }

    final point = LatLng(widget.latitude, widget.longitude);

    return GestureDetector(
      onTap: () => _openMapScreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 220,
          child: Stack(
            children: [
              // ── Interactive-disabled map (preview) ─────────────────────
              FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: _defaultZoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.hayy.app',
                    maxZoom: 19,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 56,
                        height: 66,
                        alignment: Alignment.topCenter,
                        child: _BrandedMarker(placeName: widget.placeName),
                      ),
                    ],
                  ),
                ],
              ),

              // ── Tap hint overlay ────────────────────────────────────────
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_full_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Tap to open map & get directions',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandedMarker extends StatelessWidget {
  final String placeName;

  const _BrandedMarker({required this.placeName});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pin head
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFE5D17),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55FE5D17),
                blurRadius: 10,
                spreadRadius: 2,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.location_on,
            color: Colors.white,
            size: 26,
          ),
        ),
        // Pin tail triangle
        CustomPaint(
          size: const Size(14, 10),
          painter: _PinTailPainter(),
        ),
      ],
    );
  }
}

/// Draws a small downward triangle (pin tail) in the brand orange color.
class _PinTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFE5D17)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2 - 6, 0)
      ..lineTo(size.width / 2 + 6, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
