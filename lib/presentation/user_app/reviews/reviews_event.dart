import 'package:equatable/equatable.dart';

abstract class ReviewsEvent extends Equatable {
  const ReviewsEvent();

  @override
  List<Object?> get props => [];
}

class LoadReviewsEvent extends ReviewsEvent {
  final String placeId;
  final bool refresh;

  const LoadReviewsEvent({required this.placeId, this.refresh = false});

  @override
  List<Object?> get props => [placeId, refresh];
}

class AddReviewEvent extends ReviewsEvent {
  final String placeId;
  final double rating;
  final String comment;
  final String? imageFilePath;

  const AddReviewEvent({
    required this.placeId,
    required this.rating,
    required this.comment,
    this.imageFilePath,
  });

  @override
  List<Object?> get props => [placeId, rating, comment, imageFilePath];
}

class UpdateReviewEvent extends ReviewsEvent {
  final String reviewId;
  final double rating;
  final String comment;
  /// Local file path of a newly selected image, or null to keep existing.
  final String? imageFilePath;
  /// Existing remote image URL to keep (when no new image was picked).
  final String? existingImageUrl;

  const UpdateReviewEvent({
    required this.reviewId,
    required this.rating,
    required this.comment,
    this.imageFilePath,
    this.existingImageUrl,
  });

  @override
  List<Object?> get props => [reviewId, rating, comment, imageFilePath, existingImageUrl];
}
