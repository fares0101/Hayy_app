import 'package:flutter_bloc/flutter_bloc.dart';
import 'search_state.dart';

abstract class SearchEvent {}

class SearchPlacesEvent extends SearchEvent {
  final String query;
  SearchPlacesEvent(this.query);
}

class ClearSearchEvent extends SearchEvent {}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc() : super(SearchInitial()) {
    on<SearchPlacesEvent>(_onSearchPlaces);
    on<ClearSearchEvent>(_onClearSearch);
  }

  void _onSearchPlaces(SearchPlacesEvent event, Emitter<SearchState> emit) async {
    emit(SearchLoading());
    // TODO: Implement search places logic
  }

  void _onClearSearch(ClearSearchEvent event, Emitter<SearchState> emit) async {
    emit(SearchInitial());
  }
}