import '../../../data/user_app/models/user_model.dart';

abstract class ProfileState {}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final UserModel user;
  final bool isVerified;
  final bool isLoggingOut;
  final bool isDeletingAccount;

  ProfileLoaded({
    required this.user,
    this.isVerified = true,
    this.isLoggingOut = false,
    this.isDeletingAccount = false,
  });
}

class ProfileLoggedOut extends ProfileState {}

class ProfileAccountDeleted extends ProfileState {}

class ProfileError extends ProfileState {
  final String message;
  ProfileError(this.message);
}
