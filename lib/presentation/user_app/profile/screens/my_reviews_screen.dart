import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/user_session_manager.dart';
import '../../../../core/widgets/app_theme.dart';
import '../../../../core/widgets/themed_top_header.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../data/user_app/datasources/reviews_remote_data_source.dart';
import '../../../../injection_container.dart';
import '../../../../core/utils/image_url_formatter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MyReviewsScreen — fetches from GET /api/Reviews/user/{userId} with pagination
// ─────────────────────────────────────────────────────────────────────────────

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  // ── State ─────────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _initialLoad = true;
  String? _error;

  // ── Pagination ────────────────────────────────────────────────────────────
  int _page = 1;
  static const int _pageSize = 10;

  // ── Scroll ────────────────────────────────────────────────────────────────
  final ScrollController _scrollController = ScrollController();

  // ── Dependencies ──────────────────────────────────────────────────────────
  late final ReviewsRemoteDataSource _dataSource;
  late final UserSessionManager _sessionManager;
  String? _userId;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _dataSource = ReviewsRemoteDataSource(apiClient: sl<ApiClient>());
    _sessionManager = sl<UserSessionManager>();
    _userId = _sessionManager.getUser()?.id;

    _scrollController.addListener(_onScroll);
    _fetchPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) _fetchPage();
    }
  }

  Future<void> _fetchPage({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      _page = 1;
      _reviews.clear();
      _hasMore = true;
      _error = null;
    }

    if (_userId == null || _userId!.isEmpty) {
      setState(() {
        _initialLoad = false;
        _error = 'User not found. Please log in again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      if (refresh) _initialLoad = true;
    });

    try {
      final fetched = await _dataSource.getUserReviews(
        _userId!,
        pageNumber: _page,
        pageSize: _pageSize,
      );

      dev.log('[MyReviews] page $_page → ${fetched.length} items', name: 'MyReviews');

      setState(() {
        _page++;
        _isLoading = false;
        _initialLoad = false;
        _error = null;
        _hasMore = fetched.length == _pageSize;
        _reviews.addAll(fetched.map((r) => {
              'id': r.id,
              'placeId': r.placeId,
              'placeName': r.placeName,
              'placeImageUrl': r.placeImageUrl,
              'rating': r.rating,
              'comment': r.comment,
              'createdAt': r.createdAt.toIso8601String(),
            }));
      });
    } catch (e) {
      dev.log('[MyReviews] error: $e', name: 'MyReviews');
      setState(() {
        _isLoading = false;
        _initialLoad = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _deleteReview(String reviewId) async {
    try {
      final apiClient = sl<ApiClient>();
      await apiClient.delete(
        ApiConstants.updateReview.replaceAll('{reviewId}', reviewId),
      );
      if (mounted) {
        _showSnack('Review deleted successfully.', isError: false);
        _fetchPage(refresh: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Failed to delete: $e', isError: true);
    }
  }

  // ── Image picker helper ────────────────────────────────────────────────────
  Future<String?> _pickImage(ImageSource source) async {
    try {
      final xFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      return xFile?.path;
    } catch (_) {
      if (mounted) _showSnack('Could not open image source.', isError: true);
      return null;
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> review) async {
    final reviewId = review['id']?.toString() ?? '';
    if (reviewId.isEmpty) return;

    int rating = (review['rating'] as num?)?.round() ?? 5;
    final commentController = TextEditingController(
      text: review['comment']?.toString() ?? '',
    );
    // Track whether the user picked a new image or wants to keep the old one
    String? newImagePath;      // local path from camera / gallery
    bool isPickingImage = false;
    // Existing image URL from the review data (kept unless user removes it)
    final existingImageUrl = ImageUrlFormatter.extractFromMap(review);
    bool keepExisting = existingImageUrl.isNotEmpty;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Which image to preview: newly picked local file takes priority
          final showLocalPreview = newImagePath != null;
          final showNetworkPreview = !showLocalPreview && keepExisting;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Edit Review',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Stars ───────────────────────────────────────────────
                  const Text(
                    'Rating',
                    style: TextStyle(fontSize: 13, color: Color(0xFF7A7A7A)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return GestureDetector(
                        onTap: () => setDialogState(() => rating = star),
                        child: Icon(
                          star <= rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: const Color(0xFFFFB300),
                          size: 34,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // ── Comment ─────────────────────────────────────────────
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Write your review...',
                      hintStyle: const TextStyle(color: Color(0xFF9A9A9A)),
                      filled: true,
                      fillColor: const Color(0xFFF8F4F0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppTheme.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Photo label ─────────────────────────────────────────
                  const Text(
                    'Photo (optional)',
                    style: TextStyle(fontSize: 13, color: Color(0xFF7A7A7A)),
                  ),
                  const SizedBox(height: 8),

                  // ── Gallery / Camera buttons ─────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _imageSourceButton(
                          icon: Icons.photo_library_outlined,
                          label: 'Gallery',
                          isLoading: isPickingImage,
                          onTap: () async {
                            setDialogState(() => isPickingImage = true);
                            final path = await _pickImage(ImageSource.gallery);
                            setDialogState(() {
                              isPickingImage = false;
                              if (path != null) {
                                newImagePath = path;
                                keepExisting = false;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _imageSourceButton(
                          icon: Icons.photo_camera_outlined,
                          label: 'Camera',
                          isLoading: isPickingImage,
                          onTap: () async {
                            setDialogState(() => isPickingImage = true);
                            final path = await _pickImage(ImageSource.camera);
                            setDialogState(() {
                              isPickingImage = false;
                              if (path != null) {
                                newImagePath = path;
                                keepExisting = false;
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  // ── Image preview ────────────────────────────────────────
                  if (showLocalPreview || showNetworkPreview) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          showLocalPreview
                              ? ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 300),
                                  child: Image.file(
                                    File(newImagePath!),
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 300),
                                  child: Image.network(
                                    existingImageUrl,
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                          // Remove button
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () => setDialogState(() {
                                newImagePath = null;
                                keepExisting = false;
                              }),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel',
                    style: TextStyle(color: Color(0xFF6A6A6A))),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _updateReview(
                    reviewId: reviewId,
                    rating: rating,
                    comment: commentController.text.trim(),
                    imageFilePath: newImagePath,
                    existingImageUrl: keepExisting ? existingImageUrl : null,
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateReview({
    required String reviewId,
    required int rating,
    required String comment,
    String? imageFilePath,
    String? existingImageUrl,
  }) async {
    try {
      await _dataSource.updateReview(
        reviewId: reviewId,
        rating: rating.toDouble(),
        comment: comment,
        imageFilePath: imageFilePath,
        existingImageUrl: existingImageUrl,
      );
      if (mounted) {
        _showSnack('Review updated successfully.', isError: false);
        _fetchPage(refresh: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Failed to update: $e', isError: true);
    }
  }

  // ── Reusable image source button ──────────────────────────────────────────
  Widget _imageSourceButton({
    required IconData icon,
    required String label,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: isLoading ? null : onTap,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primary,
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.28)),
        padding: const EdgeInsets.symmetric(vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppTheme.primary.withValues(alpha: 0.04),
      ),
    );
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF323232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _confirmDelete(String reviewId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteReview(reviewId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          ThemedTopHeader(
            title: 'My Reviews',
            showBackButton: true,
            onBackPressed: () => Navigator.maybePop(context),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // ── Initial full-screen loading ──────────────────────────────────────
    if (_initialLoad) {
      return ShimmerLoading.buildVerticalList(itemCount: 6);
    }

    // ── Full-screen error (no data yet) ──────────────────────────────────
    if (_error != null && _reviews.isEmpty) {
      return _buildErrorState(_error!);
    }

    // ── Empty state ───────────────────────────────────────────────────────
    if (_reviews.isEmpty) {
      return _buildEmptyState();
    }

    // ── List ──────────────────────────────────────────────────────────────
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        await _fetchPage(refresh: true);
        HapticFeedback.mediumImpact();
      },
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics:
            const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: _reviews.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index == _reviews.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            );
          }
          return _buildReviewCard(_reviews[index]);
        },
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 48, color: Color(0xFFCCCCCC)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Could not load reviews',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E2E2E)),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF8A8A8A)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _fetchPage(refresh: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.rate_review_outlined,
                size: 56, color: Color(0xFFCCCCCC)),
          ),
          const SizedBox(height: 20),
          const Text(
            "You haven't written any reviews yet",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E2E2E)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start exploring places!',
            style: TextStyle(fontSize: 14, color: Color(0xFF8A8A8A)),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final reviewId = review['id']?.toString() ?? '';
    final placeName = review['placeName']?.toString() ??
        review['place']?['name']?.toString() ??
        'Unknown Place';
    final ratingRaw = review['rating'];
    final rating = ratingRaw is num
        ? ratingRaw.toDouble()
        : double.tryParse(ratingRaw?.toString() ?? '') ?? 0;
    final comment = review['comment']?.toString() ?? '';
    final imageUrl = ImageUrlFormatter.extractFromMap({
      ...review,
      if (review['reviewImages'] != null) 'reviewImages': review['reviewImages'],
      if (review['placeImageUrl'] != null) 'placeImageUrl': review['placeImageUrl'],
    });
    final createdAt = review['createdAt']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Place header ───────────────────────────────────────────────
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeAvatar(placeName),
                      )
                    : _placeAvatar(placeName),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      placeName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < rating.round()
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 15,
                            color: const Color(0xFFFFB300),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5A5A5A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Comment ────────────────────────────────────────────────────
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F4F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                comment,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF4A4A4A),
                  height: 1.45,
                ),
              ),
            ),
          ],

          // ── Footer ─────────────────────────────────────────────────────
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 13, color: Color(0xFFB0B0B0)),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(createdAt),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9E9E9E)),
                  ),
                ],
              ),
              if (reviewId.isNotEmpty)
                Row(
                  children: [
                    _actionButton(
                      label: 'Edit',
                      icon: Icons.edit_outlined,
                      color: AppTheme.primary,
                      onTap: () => _showEditDialog(review),
                    ),
                    const SizedBox(width: 8),
                    _actionButton(
                      label: 'Delete',
                      icon: Icons.delete_outline_rounded,
                      color: Colors.red,
                      onTap: () => _confirmDelete(reviewId),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeAvatar(String name) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.tryParse(dateStr)?.toLocal();
      if (dt == null) return dateStr;
      final diff = DateTime.now().difference(dt);
      if (diff.isNegative || diff.inSeconds < 60) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes} minutes ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      if (diff.inDays < 30) return '${diff.inDays} days ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
      return '${(diff.inDays / 365).floor()} years ago';
    } catch (_) {
      return dateStr;
    }
  }
}
