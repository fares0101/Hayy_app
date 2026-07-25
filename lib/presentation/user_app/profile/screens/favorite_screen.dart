import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/widgets/themed_top_header.dart';
import '../../../../app_router.dart';
import '../../../../injection_container.dart';
import '../../../../data/user_app/datasources/favorites_remote_data_source.dart';
import '../../../../core/utils/image_url_formatter.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  late Future<List<Map<String, dynamic>>> _favoritesFuture;
  late final FavoritesRemoteDataSource _placesDataSource;

  @override
  void initState() {
    super.initState();
    _placesDataSource = sl<FavoritesRemoteDataSource>();
    _loadFavorites();
  }

  void _loadFavorites() {
    setState(() {
      _favoritesFuture = _placesDataSource.getMyFavorites();
    });
  }

  Future<void> _removePlaceFavorite(String placeId, String placeName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Unfollow Place',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'Unfollow "$placeName"?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF5C5C5C)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6A6A6A))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFE5D17),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Unfollow'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _placesDataSource.toggleFavorite(placeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unfollowed "$placeName".'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF323232),
          ),
        );
        _loadFavorites();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not unfollow. Please try again.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F2EE),
      body: Column(
        children: [
          ThemedTopHeader(
            title: 'My Following',
            showBackButton: true,
            onBackPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: _buildPlacesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _favoritesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerLoading();
        }
        if (snapshot.hasError) {
          return _buildErrorState(_loadFavorites);
        }
        final favorites = snapshot.data ?? [];
        if (favorites.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people_alt_outlined,
            title: 'Not following any places',
            subtitle: 'Follow any place to see it here!',
          );
        }
        return RefreshIndicator(
          color: const Color(0xFFFE5D17),
          onRefresh: () async => _loadFavorites(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            itemCount: favorites.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildPlaceCard(favorites[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade50,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
                    Shimmer.fromColors(
                      baseColor: Colors.grey.shade200,
                      highlightColor: Colors.grey.shade50,
                      child: Container(
                        height: 16,
                        width: double.infinity,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Shimmer.fromColors(
                      baseColor: Colors.grey.shade200,
                      highlightColor: Colors.grey.shade50,
                      child: Container(
                        height: 14,
                        width: 120,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Shimmer.fromColors(
                      baseColor: Colors.grey.shade200,
                      highlightColor: Colors.grey.shade50,
                      child: Container(
                        height: 14,
                        width: 80,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade50,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 64, color: Color(0xFFCCCCCC)),
          const SizedBox(height: 16),
          const Text('Could not load following', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2E2E2E))),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFE5D17),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: const Color(0xFFFE5D17)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2E2E2E))),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF8A8A8A))),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> place) {
    final rawPlaceObj = place['place'] ?? place['targetPlace'] ?? place['businessPlace'] ?? place['followedPlace'];
    final placeData = (rawPlaceObj is Map) ? Map<String, dynamic>.from(rawPlaceObj) : <String, dynamic>{};
    final merged = <String, dynamic>{...place, ...placeData};

    final placeId = (merged['placeId'] ?? merged['id'] ?? merged['targetPlaceId'])?.toString() ?? '';
    final placeName = (merged['name'] ?? merged['placeName'] ?? merged['title'] ?? merged['businessName'] ?? 'Unknown').toString();
    final category = (merged['category'] ?? merged['categoryName'] ?? merged['type'] ?? merged['placeType'] ?? '').toString();
    
    final ratingRaw = merged['rating'] ?? merged['averageRating'] ?? merged['avgRating'] ?? merged['rate'] ?? merged['reviewsRating'];
    double rating = ratingRaw is num ? ratingRaw.toDouble() : double.tryParse(ratingRaw?.toString() ?? '') ?? 0.0;

    if (rating == 0.0 && merged['reviews'] is List) {
      final reviewsList = merged['reviews'] as List;
      if (reviewsList.isNotEmpty) {
        double sum = 0;
        int count = 0;
        for (final r in reviewsList) {
          if (r is Map) {
            final rVal = r['rating'] ?? r['rate'] ?? r['score'];
            if (rVal is num) {
              sum += rVal.toDouble();
              count++;
            }
          }
        }
        if (count > 0) rating = sum / count;
      }
    }

    final imageUrl = ImageUrlFormatter.extractFromMap(merged);

    return GestureDetector(
      onTap: () {
        if (placeId.isNotEmpty) {
          Navigator.pushNamed(
            context,
            AppRoutes.placeDetails,
            arguments: placeId,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, width: 90, height: 90, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholderImage(placeName))
                : _placeholderImage(placeName),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 4),
                Text(placeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2E2E2E))),
                if (category.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(category, style: const TextStyle(fontSize: 13, color: Color(0xFF8A8A8A))),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < rating.round() ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 14,
                        color: const Color(0xFFFFB300),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating > 0 ? rating.toStringAsFixed(1) : '0.0',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A4A4A)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (placeId.isNotEmpty)
            IconButton(
              onPressed: () => _removePlaceFavorite(placeId, placeName),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFFFF4EF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.person_remove_rounded, color: Color(0xFFFE5D17), size: 20),
            ),
        ],
      ),
    ));
  }

  Widget _placeholderImage(String name) {
    return Container(
      width: 90,
      height: 90,
      color: const Color(0xFFFFF0E8),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFFFE5D17)),
        ),
      ),
    );
  }
}
