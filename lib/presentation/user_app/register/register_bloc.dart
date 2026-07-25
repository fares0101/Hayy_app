import 'package:flutter_bloc/flutter_bloc.dart';

part 'register_state.dart';

class RegisterBloc extends Cubit<RegisterState> {
  RegisterBloc() : super(RegisterInitial());
}
