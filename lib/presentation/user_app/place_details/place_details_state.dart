abstract class PlaceDetailsState {}

class PlaceDetailsInitial extends PlaceDetailsState {}

class PlaceDetailsLoading extends PlaceDetailsState {}

class PlaceDetailsLoaded extends PlaceDetailsState {
  final Map<String, dynamic> data;
  PlaceDetailsLoaded(this.data);
}

class PlaceDetailsError extends PlaceDetailsState {
  final String message;
  PlaceDetailsError(this.message);
}
