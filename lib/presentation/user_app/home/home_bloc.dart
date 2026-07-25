import 'package:flutter_bloc/flutter_bloc.dart';
import 'home_state.dart';

abstract class HomeEvent {}

class LoadHomeDataEvent extends HomeEvent {}

class RefreshHomeDataEvent extends HomeEvent {}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(HomeInitial()) {
    on<LoadHomeDataEvent>(_onLoadHomeData);
    on<RefreshHomeDataEvent>(_onRefreshHomeData);
  }

  void _onLoadHomeData(LoadHomeDataEvent event, Emitter<HomeState> emit) async {
    emit(HomeLoading());
    // TODO: Implement load home data logic
  }

  void _onRefreshHomeData(RefreshHomeDataEvent event, Emitter<HomeState> emit) async {
    emit(HomeLoading());
    // TODO: Implement refresh home data logic
  }
}