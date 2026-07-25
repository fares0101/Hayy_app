abstract class MapViewState {}

class MapViewInitial extends MapViewState {}

class MapViewLoading extends MapViewState {}

class MapViewLoaded extends MapViewState {}

class MapViewError extends MapViewState {
  final String message;
  MapViewError(this.message);
}