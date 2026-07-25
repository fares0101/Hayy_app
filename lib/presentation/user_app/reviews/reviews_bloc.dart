import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/user_app/datasources/reviews_remote_data_source.dart';
import 'reviews_event.dart';
import 'reviews_state.dart';

class ReviewsBloc extends Bloc<ReviewsEvent, ReviewsState> {
  final ReviewsRemoteDataSource remoteDataSource;
  
  int _currentPage = 1;
  final int _pageSize = 10;

  ReviewsBloc({required this.remoteDataSource}) : super(ReviewsInitial()) {
    on<LoadReviewsEvent>(_onLoadReviews);
    on<AddReviewEvent>(_onAddReview);
    on<UpdateReviewEvent>(_onUpdateReview);
  }

  Future<void> _onLoadReviews(LoadReviewsEvent event, Emitter<ReviewsState> emit) async {
    if (event.refresh) {
      _currentPage = 1;
    } else {
      if (state.hasReachedMax || state.isLoading) return;
      _currentPage++;
    }

    if (state is ReviewsLoaded && !event.refresh) {
      emit((state as ReviewsLoaded).copyWith(isLoading: true));
    } else {
      emit(const ReviewsLoaded(isLoading: true));
    }

    try {
      final newReviews = await remoteDataSource.getPlaceReviews(
        event.placeId,
        pageNumber: _currentPage,
        pageSize: _pageSize,
      );

      final hasReachedMax = newReviews.length < _pageSize;

      if (event.refresh) {
        emit(ReviewsLoaded(
          reviews: newReviews,
          isLoading: false,
          hasReachedMax: hasReachedMax,
        ));
      } else {
        final currentReviews = state.reviews;
        emit(ReviewsLoaded(
          reviews: List.of(currentReviews)..addAll(newReviews),
          isLoading: false,
          hasReachedMax: hasReachedMax,
        ));
      }
    } catch (e) {
      if (event.refresh) {
        emit(ReviewsError(errorMessage: e.toString()));
      } else {
        emit((state as ReviewsLoaded).copyWith(
          isLoading: false,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  Future<void> _onAddReview(AddReviewEvent event, Emitter<ReviewsState> emit) async {
    final currentState = state;
    if (currentState is ReviewsLoaded) {
      emit(currentState.copyWith(isAddingReview: true));
    } else {
      emit(const ReviewsLoaded(isAddingReview: true));
    }

    try {
      final newReview = await remoteDataSource.addReview(
        placeId: event.placeId,
        rating: event.rating,
        comment: event.comment,
        imageFilePath: event.imageFilePath,
      );

      // Insert at top
      final updatedReviews = List.of(state.reviews)..insert(0, newReview);
      emit(ReviewsLoaded(
        reviews: updatedReviews,
        isAddingReview: false,
        hasReachedMax: state.hasReachedMax,
      ));
    } catch (e) {
      if (currentState is ReviewsLoaded) {
        emit(currentState.copyWith(
          isAddingReview: false,
          errorMessage: e.toString(),
        ));
      } else {
        emit(ReviewsError(
          reviews: state.reviews,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  Future<void> _onUpdateReview(UpdateReviewEvent event, Emitter<ReviewsState> emit) async {
    final currentState = state;
    if (currentState is ReviewsLoaded) {
      emit(currentState.copyWith(isAddingReview: true));
    } else {
      emit(const ReviewsLoaded(isAddingReview: true));
    }

    try {
      final updatedReview = await remoteDataSource.updateReview(
        reviewId: event.reviewId,
        rating: event.rating,
        comment: event.comment,
        imageFilePath: event.imageFilePath,
        existingImageUrl: event.existingImageUrl,
      );

      final updatedReviews = state.reviews.map((r) {
        return r.id == event.reviewId ? updatedReview : r;
      }).toList();

      emit(ReviewsLoaded(
        reviews: updatedReviews,
        isAddingReview: false,
        hasReachedMax: state.hasReachedMax,
      ));
    } catch (e) {
      if (currentState is ReviewsLoaded) {
        emit(currentState.copyWith(
          isAddingReview: false,
          errorMessage: e.toString(),
        ));
      } else {
        emit(ReviewsError(
          reviews: state.reviews,
          errorMessage: e.toString(),
        ));
      }
    }
  }
}
