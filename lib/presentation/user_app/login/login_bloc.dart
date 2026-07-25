import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../../core/storage/user_session_manager.dart';
import '../../../core/services/signal_r_service.dart';
import '../../../domain/user_app/usecases/login_usecase.dart';
import '../../../data/user_app/datasources/auth_remote_data_source.dart';
import '../../../injection_container.dart';

part 'login_state.dart';

class LoginBloc extends Cubit<LoginState> {
  final LoginUseCase loginUseCase;
  final AuthRemoteDataSource authDataSource;
  final UserSessionManager userSessionManager;

  LoginBloc(
    this.loginUseCase,
    this.authDataSource,
    this.userSessionManager,
  ) : super(LoginInitial());

  Future<void> login(String email, String password) async {
    emit(LoginLoading());
    final result = await loginUseCase(email, password);
    await result.fold(
      (failure) async => emit(LoginError(failure.message)),
      (userData) async {
        await userSessionManager.clearUserData();
        await userSessionManager.mergeUserData(email: email);
        _cacheTokenFromResponse(userData);
        await userSessionManager.saveAuthSession(userData);

        // Fetch complete profile data from backend
        try {
          final profile = await authDataSource.fetchUserProfile();
          print('Profile fetched after login: $profile');
          await userSessionManager.saveAuthSession(profile);
        } catch (profileError) {
          print('Failed to fetch profile after login: $profileError');
        }

        final resolvedUser = userSessionManager.getUser();
        final alreadyDoneInterests = userSessionManager.hasCompletedInterests(
          userId: resolvedUser?.id.trim(),
        );

        if (resolvedUser?.hasRequiredProfile == true || alreadyDoneInterests) {
          sl<SignalRService>().connect();
          emit(LoginSuccess(userData));
        } else {
          emit(LoginNeedsProfileCompletion());
        }
      },
    );
  }

  Future<void> googleLogin(
    String idToken, {
    String? name,
    String? email,
    String? profileImagePath,
  }) async {
    emit(LoginLoading());
    try {
      print('Starting Google Login with idToken');
      await userSessionManager.clearUserData();
      await userSessionManager.mergeUserData(
        name: name,
        email: email,
        profileImagePath: profileImagePath,
      );

      final response = await authDataSource.googleLogin(
        provider: 'google',
        idToken: idToken,
      );
      print('Google Login Response received: $response');
      
      _cacheTokenFromResponse(response);
      await userSessionManager.saveAuthSession(response);

      print('Checking profile completeness...');
      try {
        final profile = await authDataSource.fetchUserProfile();
        print('Profile fetched: $profile');
        await userSessionManager.saveAuthSession(profile);
      } catch (profileError) {
        print('Profile fetch error: $profileError');
      }

      final resolvedUser = userSessionManager.getUser();
      final alreadyDoneInterests = userSessionManager.hasCompletedInterests(
        userId: resolvedUser?.id.trim(),
      );

      if (resolvedUser?.hasRequiredProfile == true || alreadyDoneInterests) {
        print('Profile is complete or interests already done');
        sl<SignalRService>().connect();
        emit(LoginSuccess(response));
      } else {
        print('Profile incomplete - needs completion');
        emit(LoginNeedsProfileCompletion());
      }
    } on DioException catch (e) {
      print('Google Login DioException: ${e.message}');
      print('Response: ${e.response?.data}');
      emit(LoginError(_extractDioMessage(e)));
    } catch (e) {
      print('Google Login Error: $e');
      emit(LoginError(e.toString()));
    }
  }

  void _cacheTokenFromResponse(Map<String, dynamic> response) {
    final token = _extractToken(response);
    if (token != null && token.isNotEmpty) {
      authDataSource.apiClient.setToken(token);
    }
  }

  String? _extractToken(Map<String, dynamic> response) {
    final directKeys = ['token', 'accessToken', 'jwtToken'];
    for (final key in directKeys) {
      final value = response[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      for (final key in directKeys) {
        final value = data[key];
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }

    return null;
  }

  String _extractDioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'] ?? data['error'] ?? data['title'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    if (data is String && data.isNotEmpty) {
      return data;
    }
    return e.message ?? 'Request failed';
  }
}
