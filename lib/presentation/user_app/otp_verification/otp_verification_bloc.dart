import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'otp_verification_state.dart';

abstract class OtpVerificationEvent extends Equatable {
  const OtpVerificationEvent();

  @override
  List<Object> get props => [];
}

class VerifyOtpEvent extends OtpVerificationEvent {
  final String otp;
  const VerifyOtpEvent(this.otp);

  @override
  List<Object> get props => [otp];
}

class ResendOtpEvent extends OtpVerificationEvent {}

class OtpVerificationBloc extends Bloc<OtpVerificationEvent, OtpVerificationState> {
  OtpVerificationBloc() : super(OtpVerificationInitial()) {
    on<VerifyOtpEvent>(_onVerifyOtp);
    on<ResendOtpEvent>(_onResendOtp);
  }

  void _onVerifyOtp(VerifyOtpEvent event, Emitter<OtpVerificationState> emit) async {
    emit(OtpVerificationLoading());
    // TODO: Implement OTP verification logic
  }

  void _onResendOtp(ResendOtpEvent event, Emitter<OtpVerificationState> emit) async {
    emit(OtpVerificationLoading());
    // TODO: Implement resend OTP logic
  }
}