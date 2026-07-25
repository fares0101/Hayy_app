import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/custom_button.dart';

class MapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String placeName;
  final String? address;

  const MapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.placeName,
    this.address,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  Position? _userPosition;
  bool _loadingLocation = false;
  bool _locationError = false;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fetchUserLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ─── Location ─────────────────────────────────────────────────────────────

  Future<void> _fetchUserLocation() async {
    if (_loadingLocation) return;
    setState(() {
      _loadingLocation = true;
      _locationError = false;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _loadingLocation = false;
          _locationError = true;
        });
        _showSnackBar('Please enable location services', isError: true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _loadingLocation = false;
            _locationError = true;
          });
          _showSnackBar('Location permission denied', isError: true);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _loadingLocation = false;
          _locationError = true;
        });
        _showSnackBar(
          'Location permission permanently denied. Enable it from settings.',
          isError: true,
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _userPosition = pos;
          _loadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
          _locationError = true;
        });
        _showSnackBar('Could not get your location', isError: true);
      }
    }
  }

  void _centerOnPlace() {
    _mapController.move(
      LatLng(widget.latitude, widget.longitude),
      15.0,
    );
  }

  void _centerOnUser() {
    if (_userPosition != null) {
      _mapController.move(
        LatLng(_userPosition!.latitude, _userPosition!.longitude),
        16.0,
      );
    } else {
      _fetchUserLocation();
    }
  }

  // ─── Directions ───────────────────────────────────────────────────────────

  Future<void> _openDirections() async {
    double? userLat = _userPosition?.latitude;
    double? userLng = _userPosition?.longitude;

    // Google Maps URL with optional origin (user location)
    String googleMapsUrl;
    if (userLat != null && userLng != null) {
      googleMapsUrl =
          'https://www.google.com/maps/dir/?api=1'
          '&origin=$userLat,$userLng'
          '&destination=${widget.latitude},${widget.longitude}'
          '&travelmode=driving';
    } else {
      googleMapsUrl =
          'https://www.google.com/maps/dir/?api=1'
          '&destination=${widget.latitude},${widget.longitude}'
          '&travelmode=driving';
    }

    final uri = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('Could not open Google Maps', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFFFE5D17),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final placePoint = LatLng(widget.latitude, widget.longitude);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: placePoint,
              initialZoom: 14.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.hayy.app',
                maxZoom: 19,
              ),

              // User location marker
              if (_userPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        _userPosition!.latitude,
                        _userPosition!.longitude,
                      ),
                      width: 60,
                      height: 60,
                      child: _UserLocationMarker(pulseAnim: _pulseAnim),
                    ),
                  ],
                ),

              // Place marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: placePoint,
                    width: 60,
                    height: 76,
                    alignment: Alignment.topCenter,
                    child: _PlaceMarker(placeName: widget.placeName),
                  ),
                ],
              ),
            ],
          ),

          // ── Top bar ──────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(
              placeName: widget.placeName,
              address: widget.address,
            ),
          ),

          // ── Right FAB column ──────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 140,
            child: Column(
              children: [
                _MapFab(
                  icon: Icons.my_location_rounded,
                  tooltip: 'My Location',
                  isLoading: _loadingLocation,
                  onTap: _centerOnUser,
                ),
                const SizedBox(height: 10),
                _MapFab(
                  icon: Icons.place_rounded,
                  tooltip: 'Go to Place',
                  onTap: _centerOnPlace,
                ),
              ],
            ),
          ),

          // ── Bottom card ───────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomCard(
              placeName: widget.placeName,
              address: widget.address,
              userPosition: _userPosition,
              placeLatLng: placePoint,
              loadingLocation: _loadingLocation,
              locationError: _locationError,
              onDirectionsTap: _openDirections,
              onRetryLocation: _fetchUserLocation,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String placeName;
  final String? address;

  const _TopBar({required this.placeName, this.address});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 8,
        left: 12,
        right: 12,
        bottom: 12,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xDD000000), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  placeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        color: Color(0x88000000),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (address != null && address!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    address!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      shadows: const [
                        Shadow(color: Color(0x88000000), blurRadius: 4),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomCard extends StatelessWidget {
  final String placeName;
  final String? address;
  final Position? userPosition;
  final LatLng placeLatLng;
  final bool loadingLocation;
  final bool locationError;
  final VoidCallback onDirectionsTap;
  final VoidCallback onRetryLocation;

  const _BottomCard({
    required this.placeName,
    this.address,
    required this.userPosition,
    required this.placeLatLng,
    required this.loadingLocation,
    required this.locationError,
    required this.onDirectionsTap,
    required this.onRetryLocation,
  });

  String _formatDistance() {
    if (userPosition == null) return '';
    final distanceCalc = const Distance();
    final meters = distanceCalc.as(
      LengthUnit.Meter,
      LatLng(userPosition!.latitude, userPosition!.longitude),
      placeLatLng,
    );
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m away';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km away';
    }
  }

  @override
  Widget build(BuildContext context) {
    final distanceText = _formatDistance();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Place info row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFE5D17).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.place_rounded,
                  color: Color(0xFFFE5D17),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      placeName,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (address != null && address!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        address!,
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Distance badge
              if (distanceText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFE5D17).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    distanceText,
                    style: const TextStyle(
                      color: Color(0xFFFE5D17),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Status row
          if (loadingLocation)
            _StatusRow(
              icon: Icons.my_location_rounded,
              text: 'Getting your location...',
              color: const Color(0xFF1565C0),
            )
          else if (locationError)
            GestureDetector(
              onTap: onRetryLocation,
              child: _StatusRow(
                icon: Icons.location_off_rounded,
                text: 'Tap to enable location',
                color: const Color(0xFFE53935),
                trailing: const Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: Color(0xFFE53935),
                ),
              ),
            )
          else if (userPosition != null)
            _StatusRow(
              icon: Icons.my_location_rounded,
              text: 'Your location is shown on the map',
              color: const Color(0xFF2E7D32),
            ),

          const SizedBox(height: 14),

          // Directions button
          CustomButton(
            text: 'Get Directions',
            onPressed: onDirectionsTap,
            icon: Icons.directions_rounded,
            height: 50,
            borderRadius: 14,
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Widget? trailing;

  const _StatusRow({
    required this.icon,
    required this.text,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _MapFab extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isLoading;

  const _MapFab({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x28000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFE5D17),
                  ),
                )
              : Icon(icon, color: const Color(0xFFFE5D17), size: 22),
        ),
      ),
    );
  }
}

// ─── Markers ─────────────────────────────────────────────────────────────────

class _PlaceMarker extends StatelessWidget {
  final String placeName;

  const _PlaceMarker({required this.placeName});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFE5D17),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55FE5D17),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            placeName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _PinTailPainter(color: const Color(0xFFFE5D17)),
        ),
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Color(0xFFFE5D17),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _UserLocationMarker extends StatelessWidget {
  final Animation<double> pulseAnim;

  const _UserLocationMarker({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulse ring
            Container(
              width: 50 * pulseAnim.value,
              height: 50 * pulseAnim.value,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
            ),
            // Inner dot
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x441976D2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;

  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
