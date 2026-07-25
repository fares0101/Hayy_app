part of 'login_bloc.dart';

abstract class LoginState {}

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {}

class LoginSuccess extends LoginState {
  final Map<String, dynamic> userData;
  LoginSuccess(this.userData);
}

class LoginNeedsProfileCompletion extends LoginState {}

class LoginError extends LoginState {
  final String message;
  LoginError(this.message);
}
