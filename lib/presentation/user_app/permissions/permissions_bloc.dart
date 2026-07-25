import 'package:flutter_bloc/flutter_bloc.dart';
import 'permissions_state.dart';

abstract class PermissionsEvent {}

class RequestLocationPermissionEvent extends PermissionsEvent {}

class RequestNotificationPermissionEvent extends PermissionsEvent {}

class PermissionsBloc extends Bloc<PermissionsEvent, PermissionsState> {
  PermissionsBloc() : super(PermissionsInitial()) {
    on<RequestLocationPermissionEvent>(_onRequestLocationPermission);
    on<RequestNotificationPermissionEvent>(_onRequestNotificationPermission);
  }

  void _onRequestLocationPermission(RequestLocationPermissionEvent event, Emitter<PermissionsState> emit) async {
    emit(PermissionsLoading());
    // TODO: Implement location permission logic
  }

  void _onRequestNotificationPermission(RequestNotificationPermissionEvent event, Emitter<PermissionsState> emit) async {
    emit(PermissionsLoading());
    // TODO: Implement notification permission logic
  }
}