import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../core/helpers/profile_image_helper.dart';
import '../../../core/widgets/themed_top_header.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/place_map_widget.dart';
import '../../../core/widgets/app_theme.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../data/user_app/datasources/places_remote_data_source.dart';
import '../../../data/user_app/datasources/favorites_remote_data_source.dart';
import '../../../data/user_app/datasources/business_posts_remote_data_source.dart';
import '../../../injection_container.dart';
import '../reviews/reviews_bloc.dart';
import '../reviews/reviews_event.dart';
import '../reviews/reviews_state.dart';
import '../reviews/reviews_screen.dart';
import '../post_details/post_details_page.dart';
import 'place_details_bloc.dart';
import 'place_details_state.dart';
import 'package:intl/intl.dart';

class PlaceDetailsPage extends StatelessWidget {
  final String? placeId;

  const PlaceDetailsPage({super.key, this.placeId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          PlaceDetailsBloc()..add(LoadPlaceDetailsEvent(placeId ?? '')),
      child: const PlaceDetailsView(),
    );
  }
}

class PlaceDetailsView extends StatelessWidget {
  const PlaceDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      body: Column(
        children: [
          ThemedTopHeader(
            title: 'Place Details',
            showBackButton: true,
            onBackPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: BlocBuilder<PlaceDetailsBloc, PlaceDetailsState>(
              builder: (context, state) {
                if (state is PlaceDetailsLoading ||
                    state is PlaceDetailsInitial) {
                  return ShimmerLoading.buildDetailsScreen();
                }

                if (state is PlaceDetailsError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 14),
                          CustomButton(
                            onPressed: () => Navigator.maybePop(context),
                            text: 'Back',
                            width: 150,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final data = (state as PlaceDetailsLoaded).data;
                return _PlaceDetailsContent(data: data);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceDetailsContent extends StatelessWidget {
  final Map<String, dynamic> data;

  const _PlaceDetailsContent({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = ImageUrlFormatter.extractFromMap(data);
    final title = _firstString(
      const ['name', 'title', 'placeName'],
      fallback: 'Place',
    );
    final subtitle = _firstString(
      const ['categoryName', 'type', 'placeType'],
      fallback: 'Destination',
    );
    final description = _firstString(
      const ['description', 'about', 'details'],
      fallback: 'No description available.',
    );
    final location = _firstString(
      const ['address', 'location', 'city', 'district'],
      fallback: 'Location will appear here',
    );
    final hours = _firstString(
      const ['workingHours', 'openHours'],
      fallback: 'Open now',
    );
    final rating = _firstDouble(
      const ['rating', 'averageRating', 'rate', 'avgRating', 'reviewsRating', 'score'],
    );
    final lat = _extractCoord(['latitude', 'lat'], isLat: true) ?? 0.0;
    final lng =
        _extractCoord(['longitude', 'lng', 'lon', 'long'], isLat: false) ?? 0.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 220,
                      cacheWidth: 800,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 220,
                        color: const Color(0xFFE6E6E6),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: Color(0xFF909090),
                          size: 34,
                        ),
                      ),
                    )
                  : Container(
                      height: 220,
                      color: const Color(0xFFE6E6E6),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Color(0xFF909090),
                        size: 34,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF222222),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _FollowButton(
                        placeId: data['id']?.toString() ??
                            data['placeId']?.toString() ??
                            '',
                        placeName: title,
                        placeData: data,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5E1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFB800),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (rating ?? 0.0).toStringAsFixed(1),
                              style: const TextStyle(
                                color: Color(0xFF5C4A00),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: location,
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.access_time_rounded,
                    label: hours,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'About',
                    style: TextStyle(
                      color: Color(0xFF252525),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  // ─── Location Section ────────────────────────────────
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFF0F0F0), thickness: 1),
                  const SizedBox(height: 14),
                  const Text(
                    'Location',
                    style: TextStyle(
                      color: Color(0xFF252525),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (lat != 0.0 || lng != 0.0)
                    PlaceMapWidget(
                      latitude: lat,
                      longitude: lng,
                      placeName: title,
                      address: location != 'Location will appear here'
                          ? location
                          : null,
                    )
                  else
                    _MapPlaceholder(placeName: title, address: location),
                  const SizedBox(height: 24),

                  // ─── Reviews & Posts Section ────────────────────────────────
                  const Divider(color: Color(0xFFF0F0F0), thickness: 1),
                  const SizedBox(height: 14),
                  _PlaceReviewsAndPostsSection(
                    placeId: data['id']?.toString() ?? '',
                    placeName: title,
                  ),
                  const SizedBox(height: 24),

                  // ─── Similar Places ────────────────────────────────
                  const Divider(color: Color(0xFFF0F0F0), thickness: 1),
                  const SizedBox(height: 14),
                  _SimilarPlacesSection(
                    currentPlaceId: data['id']?.toString() ?? '',
                    categoryName: _firstString(
                        const ['categoryName', 'type', 'placeType']),
                    categoryId:
                        _firstString(const ['categoryId', 'category_id']),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  dynamic _firstValue(List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null) {
        return value;
      }
    }

    for (final nestedKey in ['data', 'result', 'place', 'item', 'payload']) {
      final candidate = data[nestedKey];
      if (candidate is Map) {
        final nested = Map<String, dynamic>.from(candidate);
        for (final key in keys) {
          final value = nested[key];
          if (value != null) {
            return value;
          }
        }
      }
    }

    return null;
  }

  String _firstString(List<String> keys, {String fallback = ''}) {
    final value = _firstValue(keys);
    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  double? _firstDouble(List<String> keys) {
    final value = _firstValue(keys);
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString().trim());
  }

  /// Extracts a coordinate value (lat or lng) from the API response.
  /// Handles:
  /// - Direct fields: `latitude`, `lat`, `longitude`, `lng`, etc.
  /// - Nested objects: `location.lat`, `coordinates.lat`, `geo.latitude`, etc.
  /// - String values returned from API: "30.0444"
  double? _extractCoord(List<String> directKeys, {required bool isLat}) {
    // 1. Try direct fields first (already handled by _firstDouble)
    final direct = _firstDouble(directKeys);
    if (direct != null) return direct;

    // 2. Try nested location-like objects
    final nestedObjectKeys = [
      'location',
      'coordinates',
      'geo',
      'geoLocation',
      'position',
      'point',
    ];

    for (final objKey in nestedObjectKeys) {
      final obj = data[objKey];
      if (obj is Map) {
        final nested = Map<String, dynamic>.from(obj);
        for (final key in directKeys) {
          final val = nested[key];
          if (val != null) {
            if (val is num) return val.toDouble();
            final parsed = double.tryParse(val.toString().trim());
            if (parsed != null) return parsed;
          }
        }
        // Also try x/y convention (x=lng, y=lat)
        final xy = isLat ? nested['y'] : nested['x'];
        if (xy != null) {
          if (xy is num) return xy.toDouble();
          final parsed = double.tryParse(xy.toString().trim());
          if (parsed != null) return parsed;
        }
      }
    }

    // 3. Try GeoJSON-style: { "type": "Point", "coordinates": [lng, lat] }
    final geoJson = data['geometry'] ?? data['geoJson'] ?? data['coordinates'];
    if (geoJson is Map) {
      final coords = geoJson['coordinates'];
      if (coords is List && coords.length >= 2) {
        final val = isLat ? coords[1] : coords[0];
        if (val is num) return val.toDouble();
      }
    }
    if (geoJson is List && geoJson.length >= 2) {
      final val = isLat ? geoJson[1] : geoJson[0];
      if (val is num) return val.toDouble();
    }

    return null;
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: const Color(0xFFFE5D17),
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5F5F5F),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown when the backend doesn't yet provide lat/lng coordinates.
/// Interactive Map Location Card
class _MapPlaceholder extends StatelessWidget {
  final String placeName;
  final String address;

  const _MapPlaceholder({
    required this.placeName,
    required this.address,
  });

  void _openMapOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.map_rounded, color: Color(0xFFFE5D17)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      placeName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF222222),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                address,
                style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF0E8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.navigation_rounded,
                      color: Color(0xFFFE5D17)),
                ),
                title: const Text(
                  'Get Directions (Google Maps)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle:
                    const Text('Open coordinates in external map navigation'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Opening Google Maps navigation to $placeName...'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              const Divider(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFECE7F4),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.copy_rounded, color: Color(0xFF6B3FA0)),
                ),
                title: const Text(
                  'Copy Address',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text('Copy location text to clipboard'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Address copied to clipboard!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openMapOptions(context),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE0E0E6),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              // Subtle grid pattern (decorative)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: CustomPaint(
                    painter: _GridPainter(),
                  ),
                ),
              ),
              // Content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFE5D17).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFFFE5D17),
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      placeName,
                      style: const TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (address != 'Location will appear here') ...[
                      const SizedBox(height: 4),
                      Text(
                        address,
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFE5D17),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33FE5D17),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_rounded,
                              color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text(
                            'Tap to Open Map',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws a subtle dot-grid pattern for the map placeholder background.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 20.0;
    final paint = Paint()
      ..color = const Color(0xFFE0E0E8)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Reviews & Posts Section (Segmented Tab Bar: Left = Reviews, Right = Posts)
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceReviewsAndPostsSection extends StatefulWidget {
  final String placeId;
  final String placeName;

  const _PlaceReviewsAndPostsSection({
    required this.placeId,
    required this.placeName,
  });

  @override
  State<_PlaceReviewsAndPostsSection> createState() =>
      _PlaceReviewsAndPostsSectionState();
}

class _PlaceReviewsAndPostsSectionState
    extends State<_PlaceReviewsAndPostsSection> {
  int _activeTab = 0; // 0: Reviews (Left / Default), 1: Posts (Right)

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab Selector Container
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F5),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              // Left Tab: Reviews (Default)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeTab = 0),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: _activeTab == 0 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _activeTab == 0
                          ? const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: _activeTab == 0
                              ? const Color(0xFFFE5D17)
                              : const Color(0xFF888888),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Reviews',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _activeTab == 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _activeTab == 0
                                ? const Color(0xFF222222)
                                : const Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Right Tab: Posts
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeTab = 1),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: _activeTab == 1 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _activeTab == 1
                          ? const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.article_rounded,
                          size: 18,
                          color: _activeTab == 1
                              ? const Color(0xFFFE5D17)
                              : const Color(0xFF888888),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Posts',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _activeTab == 1
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _activeTab == 1
                                ? const Color(0xFF222222)
                                : const Color(0xFF666666),
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
        const SizedBox(height: 16),
        // Active Content View
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _activeTab == 0
              ? _PlaceReviewsSection(
                  key: const ValueKey('reviews_tab'),
                  placeId: widget.placeId,
                )
              : _PlacePostsSection(
                  key: const ValueKey('posts_tab'),
                  placeId: widget.placeId,
                  placeName: widget.placeName,
                ),
        ),
      ],
    );
  }
}

class _PlacePostsSection extends StatefulWidget {
  final String placeId;
  final String placeName;

  const _PlacePostsSection({
    super.key,
    required this.placeId,
    required this.placeName,
  });

  @override
  State<_PlacePostsSection> createState() => _PlacePostsSectionState();
}

class _PlacePostsSectionState extends State<_PlacePostsSection> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    if (widget.placeId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final dataSource = sl<BusinessPostsRemoteDataSource>();
      final results = await dataSource.getPostsByPlaceId(
        widget.placeId,
        pageNumber: 1,
        pageSize: 20,
      );

      if (mounted) {
        setState(() {
          _posts = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _posts = [];
          _isLoading = false;
        });
      }
    }
  }

  void _showAllPostsBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: const BoxDecoration(
            color: Color(0xFFF6F6F8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.article_rounded, color: Color(0xFFFE5D17), size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Posts from ${widget.placeName}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF222222),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF777777)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _posts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (ctx, index) {
                    final post = _posts[index];
                    return _SinglePostCard(post: post, placeName: widget.placeName);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ShimmerLoading.buildVerticalList(itemCount: 1),
      );
    }

    if (_posts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9FB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEF2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFE5D17).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.article_outlined,
                color: Color(0xFFFE5D17),
                size: 28,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'No posts available yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF444444),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Check back later for updates and announcements.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF888888),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final topPost = _posts.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Place Posts',
                  style: TextStyle(
                    color: Color(0xFF252525),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '(${_posts.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFE5D17),
                    ),
                  ),
                ),
              ],
            ),
            if (_posts.length > 1)
              TextButton(
                onPressed: () => _showAllPostsBottomSheet(context),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _SinglePostCard(post: topPost, placeName: widget.placeName),
        const SizedBox(height: 16),
        if (_posts.length > 1)
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                side: const BorderSide(color: AppTheme.primary),
              ),
              onPressed: () => _showAllPostsBottomSheet(context),
              child: Text(
                'View All Posts (${_posts.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SinglePostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final String placeName;

  const _SinglePostCard({
    required this.post,
    required this.placeName,
  });

  String _firstString(Map<String, dynamic> map, List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final val = map[key];
      if (val != null && val.toString().trim().isNotEmpty) {
        return val.toString().trim();
      }
    }
    return fallback;
  }

  int _firstInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final val = map[key];
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) {
        final parsed = int.tryParse(val.trim());
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final postId = _firstString(post, const ['id', 'postId', 'businessPostId']);
    final title = _firstString(post, const ['title', 'name', 'heading']);
    final content = _firstString(post, const ['content', 'description', 'text', 'caption', 'body']);
    final imageUrl = ImageUrlFormatter.extractFromMap(post);
    final likesCount = _firstInt(post, const ['likesCount', 'likes', 'likeCount', 'totalLikes']);
    final commentsCount = _firstInt(post, const ['commentsCount', 'comments', 'commentCount', 'totalComments']);
    final createdAt = _firstString(post, const ['createdAt', 'createdOn', 'date', 'postedAt']);

    return Depth3DCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: () {
          if (postId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PostDetailsPage(
                  postId: postId,
                  initialPostData: post,
                ),
              ),
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFE5D17).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Color(0xFFFE5D17),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isNotEmpty ? title : placeName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (createdAt.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          createdAt.contains('T') ? createdAt.split('T')[0] : createdAt,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFFB0B0B0),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 160,
                  cacheWidth: 600,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (content.isNotEmpty) ...[
              Text(
                content,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFFE5D17),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$likesCount',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Color(0xFF777777),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$commentsCount',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceReviewsSection extends StatelessWidget {
  final String placeId;

  const _PlaceReviewsSection({super.key, required this.placeId});

  @override
  Widget build(BuildContext context) {
    if (placeId.isEmpty) return const SizedBox();

    return BlocProvider(
      create: (_) => sl<ReviewsBloc>()
        ..add(LoadReviewsEvent(placeId: placeId, refresh: true)),
      child: BlocBuilder<ReviewsBloc, ReviewsState>(
        builder: (context, state) {
          if (state is ReviewsInitial ||
              (state is ReviewsLoaded &&
                  state.isLoading &&
                  state.reviews.isEmpty)) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: ShimmerLoading.buildVerticalList(itemCount: 2),
            );
          }

          if (state is ReviewsError && state.reviews.isEmpty) {
            return const SizedBox(); // Hide reviews section on error for now
          }

          final reviews = state.reviews;
          final topReview = reviews.isNotEmpty ? reviews.first : null;

          double calculatedAvg = 0;
          if (reviews.isNotEmpty) {
            double sum = 0;
            for (var r in reviews) {
              sum += r.rating;
            }
            calculatedAvg = sum / reviews.length;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Reviews',
                        style: TextStyle(
                          color: Color(0xFF252525),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (reviews.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF5E1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFFFB800), size: 14),
                              const SizedBox(width: 3),
                              Text(
                                calculatedAvg.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF5C4A00)),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${reviews.length})',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF888888)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (reviews.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    ReviewsScreen(placeId: placeId)));
                      },
                      child: const Text('See all',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (topReview != null) ...[
                Depth3DCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFE0E0E0),
                            backgroundImage: ProfileImageHelper.imageProvider(topReview.userImage),
                            child: ProfileImageHelper.imageProvider(topReview.userImage) == null
                                ? const Icon(Icons.person,
                                    color: Colors.white, size: 20)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(topReview.userName,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary)),
                                Row(
                                  children: List.generate(
                                      5,
                                      (index) => Icon(
                                            index < topReview.rating.round()
                                                ? Icons.star_rounded
                                                : Icons.star_border_rounded,
                                            color: const Color(0xFFFF6A1C),
                                            size: 12,
                                          )),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatDate(topReview.createdAt),
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        topReview.comment,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.4),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // ── Review image (if present) ─────────────────────────
                      if (topReview.reviewImages.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 260),
                            child: Image.network(
                              topReview.reviewImages,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  height: 120,
                                  color: const Color(0xFFF5F5F5),
                                  alignment: Alignment.center,
                                  child: const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _HelpfulVoteWidget(reviewId: topReview.id),
                const SizedBox(height: 16),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                      'No reviews yet. Be the first to share your experience!',
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                ),
              ],
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    side: const BorderSide(color: AppTheme.primary),
                  ),
                  onPressed: () {
                    // Navigate to ReviewsScreen which has the add review bottom sheet
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ReviewsScreen(placeId: placeId)));
                  },
                  child: const Text('Add Review',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays < 1) return 'Today';
    if (diff.inDays < 30) return '${diff.inDays} days ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    return DateFormat.yMMMd().format(date);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Similar Places Section
// ─────────────────────────────────────────────────────────────────────────────

class _SimilarPlacesSection extends StatefulWidget {
  final String currentPlaceId;
  final String categoryName;
  final String categoryId;

  const _SimilarPlacesSection({
    required this.currentPlaceId,
    required this.categoryName,
    required this.categoryId,
  });

  @override
  State<_SimilarPlacesSection> createState() => _SimilarPlacesSectionState();
}

class _SimilarPlacesSectionState extends State<_SimilarPlacesSection> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<PlacesRemoteDataSource>().getSimilarPlaces(
      currentPlaceId: widget.currentPlaceId,
      categoryName: widget.categoryName.isNotEmpty ? widget.categoryName : null,
      categoryId: widget.categoryId.isNotEmpty ? widget.categoryId : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton();
        }

        final places = snapshot.data ?? [];
        if (places.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Similar Places',
                  style: TextStyle(
                    color: Color(0xFF252525),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${places.length} places',
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 4),
                itemCount: places.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _SimilarPlaceCard(data: places[index]),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 130,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 4),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => Container(
              width: 160,
              decoration: BoxDecoration(
                color: const Color(0xFFE8E8E8),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Similar Place Card
// ─────────────────────────────────────────────────────────────────────────────

class _SimilarPlaceCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _SimilarPlaceCard({required this.data});

  String _s(List<String> keys, {String fallback = ''}) {
    for (final k in keys) {
      final v = data[k];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return fallback;
  }

  double? _d(List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v is num) return v.toDouble();
      if (v != null) return double.tryParse(v.toString());
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final placeId = _s(['id', 'placeId']);
    final name = _s(['name', 'title', 'placeName'], fallback: 'Place');
    final category = _s(['categoryName', 'type', 'placeType']);
    final imageUrl = ImageUrlFormatter.extractFromMap(data);
    final rating = _d(['rating', 'averageRating', 'rate']);

    return GestureDetector(
      onTap: () {
        if (placeId.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaceDetailsPage(placeId: placeId),
          ),
        );
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          cacheWidth: 600,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
                if (rating != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFFFB800), size: 12),
                          const SizedBox(width: 3),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF222222),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (category.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.category_outlined,
                              size: 11, color: Color(0xFFAAAAAA)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF999999),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'View ->',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        color: const Color(0xFFF0F0F0),
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Color(0xFFCCCCCC),
          size: 28,
        ),
      );
}

class _FollowButton extends StatefulWidget {
  final String placeId;
  final String placeName;
  final Map<String, dynamic> placeData;

  const _FollowButton({
    required this.placeId,
    required this.placeName,
    required this.placeData,
  });

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  late final FavoritesRemoteDataSource _dataSource;
  bool _isFollowing = false;
  bool _isLoading = true;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _dataSource = sl<FavoritesRemoteDataSource>();
    _checkInitialFollowStatus();
  }

  Future<void> _checkInitialFollowStatus() async {
    if (widget.placeId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 1. Check if placeData already contains the field
    final rawVal = widget.placeData['isFollowing'] ??
        widget.placeData['isFollowed'] ??
        widget.placeData['isFavorite'] ??
        widget.placeData['following'];

    if (rawVal is bool) {
      if (mounted) {
        setState(() {
          _isFollowing = rawVal;
          _isLoading = false;
        });
      }
      return;
    }

    // 2. Otherwise fetch my favorites list
    try {
      final list = await _dataSource.getMyFavorites();
      final isFound = list.any((item) {
        final id = item['placeId']?.toString() ??
            item['id']?.toString() ??
            item['place']?['id']?.toString() ??
            item['targetId']?.toString() ??
            '';
        return id.isNotEmpty && id == widget.placeId;
      });

      if (mounted) {
        setState(() {
          _isFollowing = isFound;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (widget.placeId.isEmpty || _isToggling) return;

    final previousState = _isFollowing;
    final targetState = !_isFollowing;

    setState(() {
      _isFollowing = targetState;
      _isToggling = true;
    });

    try {
      final serverBool = await _dataSource.toggleFavorite(widget.placeId);
      if (mounted) {
        final finalState = serverBool ?? targetState;

        final stateChanged = previousState != finalState;

        setState(() {
          _isFollowing = finalState;
          _isToggling = false;
        });

        if (stateChanged) {
          HapticFeedback.lightImpact();
        }

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  finalState
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    finalState
                        ? 'You are now following "${widget.placeName}"'
                        : 'Unfollowed "${widget.placeName}"',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor:
                finalState ? const Color(0xFFFE5D17) : const Color(0xFF323232),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFollowing = previousState;
          _isToggling = false;
        });

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update follow status. Please try again.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 36,
        width: 95,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFFE5D17),
            ),
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: InkWell(
        key: ValueKey(_isFollowing),
        borderRadius: BorderRadius.circular(999),
        onTap: _isToggling ? null : _toggleFollow,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isFollowing
                ? const Color(0xFFFFF0E8)
                : const Color(0xFFFE5D17),
            borderRadius: BorderRadius.circular(999),
            border: _isFollowing
                ? Border.all(color: const Color(0xFFFE5D17), width: 1.5)
                : null,
            boxShadow: _isFollowing
                ? []
                : const [
                    BoxShadow(
                      color: Color(0x40FE5D17),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isToggling) ...[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                        _isFollowing ? const Color(0xFFFE5D17) : Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
              ] else ...[
                Icon(
                  _isFollowing ? Icons.check_rounded : Icons.add_rounded,
                  size: 18,
                  color: _isFollowing ? const Color(0xFFFE5D17) : Colors.white,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                _isFollowing ? 'Following' : 'Follow',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _isFollowing ? const Color(0xFFFE5D17) : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpfulVoteWidget extends StatefulWidget {
  final String reviewId;

  const _HelpfulVoteWidget({required this.reviewId});

  @override
  State<_HelpfulVoteWidget> createState() => _HelpfulVoteWidgetState();
}

class _HelpfulVoteWidgetState extends State<_HelpfulVoteWidget> {
  static final Set<String> _votedReviews = {};
  bool _feedbackGiven = false;

  @override
  void initState() {
    super.initState();
    if (_votedReviews.contains(widget.reviewId)) {
      _feedbackGiven = true;
    }
  }

  void _onVote(bool isHelpful) {
    if (widget.reviewId.isNotEmpty) {
      _votedReviews.add(widget.reviewId);
    }
    setState(() {
      _feedbackGiven = true;
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isHelpful ? 'Thanks for your feedback!' : 'Feedback submitted.',
          style: const TextStyle(fontSize: 13),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_feedbackGiven) {
      return const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Did you find this helpful?',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: const BorderSide(color: Color(0xFFD0D0D0)),
              ),
              onPressed: () => _onVote(true),
              child: const Text(
                'Yes',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: const BorderSide(color: Color(0xFFD0D0D0)),
              ),
              onPressed: () => _onVote(false),
              child: const Text(
                'No',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
