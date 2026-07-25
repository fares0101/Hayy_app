import 'package:flutter_bloc/flutter_bloc.dart';
import 'splash_state.dart';

class SplashCubit extends Cubit<SplashState> {
  SplashCubit() : super(SplashInitial());

  void initialize() async {
    emit(SplashLoading());
    await Future.delayed(const Duration(seconds: 3));
    emit(SplashLoaded());
  }
}
