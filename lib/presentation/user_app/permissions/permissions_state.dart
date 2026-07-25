abstract class PermissionsState {}

class PermissionsInitial extends PermissionsState {}

class PermissionsLoading extends PermissionsState {}

class PermissionsGranted extends PermissionsState {}

class PermissionsDenied extends PermissionsState {
  final String message;
  PermissionsDenied(this.message);
}