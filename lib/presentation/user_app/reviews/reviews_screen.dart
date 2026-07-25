import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/utils/image_url_formatter.dart';
import '../../../../core/widgets/app_theme.dart';
import '../../../../core/widgets/themed_top_header.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../data/user_app/models/review_model.dart';
import '../../../../injection_container.dart';
import 'reviews_bloc.dart';
import 'reviews_event.dart';
import 'reviews_state.dart';
import 'package:intl/intl.dart';

class ReviewsScreen extends StatelessWidget {
  final String placeId;

  const ReviewsScreen({super.key, required this.placeId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ReviewsBloc>()
        ..add(LoadReviewsEvent(placeId: placeId, refresh: true)),
      child: ReviewsView(placeId: placeId),
    );
  }
}

class ReviewsView extends StatefulWidget {
  final String placeId;
  const ReviewsView({super.key, required this.placeId});

  @override
  State<ReviewsView> createState() => _ReviewsViewState();
}

class _ReviewsViewState extends State<ReviewsView> {
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = context.read<ReviewsBloc>().state;
      if (state is ReviewsLoaded && !state.isLoading && !state.hasReachedMax) {
        context
            .read<ReviewsBloc>()
            .add(LoadReviewsEvent(placeId: widget.placeId, refresh: false));
      }
    }
  }

  void _showAddReviewBottomSheet(BuildContext context) {
    final bloc = context.read<ReviewsBloc>();
    double rating = 5.0;
    final commentController = TextEditingController();
    String? selectedImagePath;
    bool isPickingImage = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: StatefulBuilder(builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Write a Review',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: const Color(0xFFFF6A1C),
                        size: 36,
                      ),
                      onPressed: () {
                        setState(() => rating = index + 1.0);
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Share your experience...',
                    filled: true,
                    fillColor: const Color(0xFFF6F6F6),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ReviewImageSourceButton(
                        icon: Icons.photo_library_outlined,
                        label: 'Gallery',
                        isLoading: isPickingImage,
                        onTap: () async {
                          setState(() => isPickingImage = true);
                          final path =
                              await _pickReviewImage(ImageSource.gallery);
                          setState(() {
                            selectedImagePath = path ?? selectedImagePath;
                            isPickingImage = false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ReviewImageSourceButton(
                        icon: Icons.photo_camera_outlined,
                        label: 'Camera',
                        isLoading: isPickingImage,
                        onTap: () async {
                          setState(() => isPickingImage = true);
                          final path =
                              await _pickReviewImage(ImageSource.camera);
                          setState(() {
                            selectedImagePath = path ?? selectedImagePath;
                            isPickingImage = false;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                if (selectedImagePath != null) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 340,
                          ),
                          child: Image.file(
                            File(selectedImagePath!),
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: InkWell(
                            onTap: () =>
                                setState(() => selectedImagePath = null),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    ),
                    onPressed: () {
                      if (commentController.text.trim().isNotEmpty) {
                        bloc.add(AddReviewEvent(
                          placeId: widget.placeId,
                          rating: rating,
                          comment: commentController.text.trim(),
                          imageFilePath: selectedImagePath,
                        ));
                        Navigator.pop(bottomSheetContext);
                      }
                    },
                    child: const Text('Submit',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          }),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _pickReviewImage(ImageSource source) async {
    if (_isDesktopPlatform && source == ImageSource.camera) {
      _showMessage('Camera is not supported on desktop right now.');
      return null;
    }

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      return image?.path;
    } catch (e) {
      _showMessage(
        source == ImageSource.camera
            ? 'Could not open the camera right now.'
            : 'Could not open the gallery right now.',
      );
      return null;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  bool get _isDesktopPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          const ThemedTopHeader(
            title: 'Reviews & Ratings',
            showBackButton: true,
          ),
          Expanded(
            child: BlocConsumer<ReviewsBloc, ReviewsState>(
              listener: (context, state) {
                if (state.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(state.errorMessage!),
                        backgroundColor: Colors.red),
                  );
                }
              },
              builder: (context, state) {
                if (state is ReviewsInitial ||
                    (state is ReviewsLoaded &&
                        state.isLoading &&
                        state.reviews.isEmpty)) {
                  return ShimmerLoading.buildVerticalList(itemCount: 5);
                }

                if (state is ReviewsError && state.reviews.isEmpty) {
                  return Center(
                    child: Text(state.errorMessage ?? 'Failed to load reviews',
                        style: const TextStyle(color: Colors.red)),
                  );
                }

                final reviews = state.reviews;

                // Calculate average rating
                double avgRating = 0;
                List<int> ratingCounts = [0, 0, 0, 0, 0];
                if (reviews.isNotEmpty) {
                  double total = 0;
                  for (var r in reviews) {
                    total += r.rating;
                    if (r.rating >= 1 && r.rating <= 5) {
                      ratingCounts[r.rating.round() - 1]++;
                    }
                  }
                  avgRating = total / reviews.length;
                }

                return RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () async {
                    context.read<ReviewsBloc>().add(LoadReviewsEvent(
                        placeId: widget.placeId, refresh: true));
                  },
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    children: [
                      // Overview Section
                      _buildRatingOverview(
                          avgRating, reviews.length, ratingCounts),
                      const SizedBox(height: 24),

                      // Write Review Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999)),
                          ),
                          onPressed: () => _showAddReviewBottomSheet(context),
                          child: const Text('Write a review',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 32),

                      const Text(
                        'User Reviews',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 16),

                      if (reviews.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                              child: Text('No reviews yet. Be the first!',
                                  style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 16))),
                        )
                      else
                        ...reviews.map((review) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _ReviewCard(review: review),
                            )),

                      if (state is ReviewsLoaded &&
                          state.isLoading &&
                          reviews.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.primary)),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingOverview(double avg, int total, List<int> counts) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          children: [
            Text(avg.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            Row(
              children: List.generate(
                  5,
                  (index) => Icon(
                        index < avg.round()
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: const Color(0xFFFF6A1C),
                        size: 16,
                      )),
            ),
            const SizedBox(height: 4),
            Text('$total Reviews',
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: List.generate(5, (index) {
              final star = 5 - index;
              final count = counts[star - 1];
              final ratio = total == 0 ? 0.0 : count / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text('$star★',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE0E0E0),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF6A1C)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Depth3DCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: Container(
                  width: 40,
                  height: 40,
                  color: const Color(0xFFE0E0E0),
                  child: _UserAvatar(imageUrl: review.userImage, size: 40),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.userName,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    Row(
                      children: List.generate(
                          5,
                          (index) => Icon(
                                index < review.rating.round()
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: const Color(0xFFFF6A1C),
                                size: 14,
                              )),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(review.createdAt),
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.comment,
            style: const TextStyle(
                fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
          ),
          if (review.reviewImages.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _ReviewImage(imageUrl: review.reviewImages),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localDate);
    if (diff.isNegative || diff.inSeconds < 60) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 30) return '${diff.inDays} days ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    return DateFormat.yMMMd().format(localDate);
  }
}

class _ReviewImageSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _ReviewImageSourceButton({
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: isLoading ? null : onTap,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 19),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primary,
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.28)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppTheme.primary.withValues(alpha: 0.035),
      ),
    );
  }
}

class _ReviewImage extends StatelessWidget {
  final String imageUrl;

  const _ReviewImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final raw = imageUrl.trim();
    final formatted = ImageUrlFormatter.format(raw);
    Widget image;

    if (formatted.startsWith('http://') || formatted.startsWith('https://')) {
      image = Image.network(
        formatted,
        width: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else {
      final file = File(raw);
      if (!file.existsSync()) return const SizedBox.shrink();
      image = Image.file(
        file,
        width: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: image,
      ),
    );
  }
}

/// A flexible avatar widget that safely displays network URLs,
/// local file paths, or falls back to a person icon.
class _UserAvatar extends StatelessWidget {
  final String imageUrl;
  final double size;

  const _UserAvatar({required this.imageUrl, required this.size});

  static String _resolve(String img) {
    if (File(img).existsSync()) return img;
    return ImageUrlFormatter.format(img);
  }

  @override
  Widget build(BuildContext context) {
    final raw = imageUrl.trim();
    final fallback = Icon(Icons.person, size: size * 0.6, color: Colors.white);

    if (raw.isEmpty) return fallback;

    final img = _resolve(raw);

    if (img.startsWith('http://') || img.startsWith('https://')) {
      return Image.network(
        img,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    // Local file path
    final file = File(img);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return fallback;
  }
}
