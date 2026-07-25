import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/user_app/usecases/forgot_password_usecase.dart';

part 'forgot_password_state.dart';

class ForgotPasswordBloc extends Cubit<ForgotPasswordState> {
  final ForgotPasswordUseCase forgotPasswordUseCase;

  ForgotPasswordBloc(this.forgotPasswordUseCase) : super(ForgotPasswordInitial());

  Future<void> sendResetEmail(String email) async {
    emit(ForgotPasswordLoading());
    final result = await forgotPasswordUseCase(email);
    result.fold(
      (failure) => emit(ForgotPasswordError(failure.message)),
      (_) => emit(ForgotPasswordSuccess()),
    );
  }
}
