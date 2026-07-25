import 'package:flutter_bloc/flutter_bloc.dart';
import 'map_view_state.dart';

abstract class MapViewEvent {}

class LoadMapEvent extends MapViewEvent {}

class UpdateLocationEvent extends MapViewEvent {}

class MapViewBloc extends Bloc<MapViewEvent, MapViewState> {
  MapViewBloc() : super(MapViewInitial()) {
    on<LoadMapEvent>(_onLoadMap);
    on<UpdateLocationEvent>(_onUpdateLocation);
  }

  void _onLoadMap(LoadMapEvent event, Emitter<MapViewState> emit) async {
    emit(MapViewLoading());
    // TODO: Implement load map logic
  }

  void _onUpdateLocation(UpdateLocationEvent event, Emitter<MapViewState> emit) async {
    // TODO: Implement update location logic
  }
}