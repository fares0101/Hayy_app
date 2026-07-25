abstract class AddReviewState {}

class AddReviewInitial extends AddReviewState {}

class AddReviewLoading extends AddReviewState {}

class AddReviewSuccess extends AddReviewState {}

class AddReviewError extends AddReviewState {
  final String message;
  AddReviewError(this.message);
}