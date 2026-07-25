import 'package:equatable/equatable.dart';
import '../../../../data/user_app/models/review_model.dart';

abstract class ReviewsState extends Equatable {
  final List<ReviewModel> reviews;
  final bool isLoading;
  final bool isAddingReview;
  final String? errorMessage;
  final bool hasReachedMax;

  const ReviewsState({
    this.reviews = const [],
    this.isLoading = false,
    this.isAddingReview = false,
    this.errorMessage,
    this.hasReachedMax = false,
  });

  @override
  List<Object?> get props => [reviews, isLoading, isAddingReview, errorMessage, hasReachedMax];
}

class ReviewsInitial extends ReviewsState {}

class ReviewsLoaded extends ReviewsState {
  const ReviewsLoaded({
    super.reviews,
    super.isLoading,
    super.isAddingReview,
    super.errorMessage,
    super.hasReachedMax,
  });

  ReviewsLoaded copyWith({
    List<ReviewModel>? reviews,
    bool? isLoading,
    bool? isAddingReview,
    String? errorMessage,
    bool? hasReachedMax,
  }) {
    return ReviewsLoaded(
      reviews: reviews ?? this.reviews,
      isLoading: isLoading ?? this.isLoading,
      isAddingReview: isAddingReview ?? this.isAddingReview,
      errorMessage: errorMessage, // We don't always pass the previous error
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }
}

class ReviewsError extends ReviewsState {
  const ReviewsError({
    super.reviews,
    super.errorMessage,
  });
}
