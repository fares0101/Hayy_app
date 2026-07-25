import 'package:flutter_bloc/flutter_bloc.dart';
import 'add_review_state.dart';

abstract class AddReviewEvent {}

class SubmitReviewEvent extends AddReviewEvent {
  final String placeId;
  final int rating;
  final String comment;
  SubmitReviewEvent(this.placeId, this.rating, this.comment);
}

class AddReviewBloc extends Bloc<AddReviewEvent, AddReviewState> {
  AddReviewBloc() : super(AddReviewInitial()) {
    on<SubmitReviewEvent>(_onSubmitReview);
  }

  void _onSubmitReview(SubmitReviewEvent event, Emitter<AddReviewState> emit) async {
    emit(AddReviewLoading());
    // TODO: Implement submit review logic
  }
}