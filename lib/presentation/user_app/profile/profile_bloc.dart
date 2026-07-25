import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/storage/user_session_manager.dart';
import '../../../core/services/signal_r_service.dart';
import '../../../core/helpers/profile_image_helper.dart';
import '../../../data/user_app/datasources/auth_remote_data_source.dart';
import '../../../data/user_app/models/user_model.dart';
import '../../../injection_container.dart';
import 'profile_state.dart';

abstract class ProfileEvent {}

class LoadProfileEvent extends ProfileEvent {}

class UpdateProfileEvent extends ProfileEvent {}

class LogoutEvent extends ProfileEvent {}

class DeleteAccountEvent extends ProfileEvent {}

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final AuthRemoteDataSource authRemoteDataSource;
  final UserSessionManager userSessionManager;

  ProfileBloc(this.authRemoteDataSource, this.userSessionManager)
      : super(ProfileInitial()) {
    on<LoadProfileEvent>(_onLoadProfile);
    on<UpdateProfileEvent>(_onUpdateProfile);
    on<LogoutEvent>(_onLogout);
    on<DeleteAccountEvent>(_onDeleteAccount);
  }

  Future<void> _onLoadProfile(
    LoadProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    final cachedUser = userSessionManager.getUser();
    final token = userSessionManager.getToken();

    print(
        'Loading profile - Cached user: ${cachedUser?.toJson()}, Has token: ${token != null}');

    if (cachedUser != null) {
      emit(ProfileLoaded(user: cachedUser));
    } else if (token != null && token.isNotEmpty) {
      final guestUser = const UserModel(
        id: 'guest',
        name: 'User',
        email: '',
        city: '',
      );
      emit(ProfileLoaded(user: guestUser));
    } else {
      emit(ProfileLoading());
    }

    try {
      final response = await authRemoteDataSource.fetchUserProfile();
      print('Profile API Response: $response');

      final remoteUser = UserModel.fromApiResponse(response);
      print(
          'Parsed User: name=${remoteUser.name}, email=${remoteUser.email}, city=${remoteUser.city}');

      if (remoteUser.hasCoreData) {
        // Re-read from storage here so we always get the LATEST saved image
        // path (e.g. after the user just updated their photo in EditProfilePage),
        // rather than relying on the stale `cachedUser` snapshot captured above.
        final freshCachedUser = userSessionManager.getUser() ?? UserModel.empty;
        final cachedImage =
            ProfileImageHelper.resolve(freshCachedUser.profileImagePath);
        final remoteImage =
            ProfileImageHelper.resolve(remoteUser.profileImagePath);
        final hasCachedLocalImage = ProfileImageHelper.resolveLocalPath(
                freshCachedUser.profileImagePath)
            .isNotEmpty;
        final mergedUser = freshCachedUser.copyWith(
          id: remoteUser.id.isNotEmpty ? remoteUser.id : freshCachedUser.id,
          name: remoteUser.name.isNotEmpty
              ? remoteUser.name
              : freshCachedUser.name,
          email: remoteUser.email.isNotEmpty
              ? remoteUser.email
              : freshCachedUser.email,
          city: remoteUser.city.isNotEmpty
              ? remoteUser.city
              : freshCachedUser.city,
          profileImagePath: hasCachedLocalImage
              ? cachedImage
              : (remoteImage.isNotEmpty ? remoteImage : cachedImage),
        );

        await userSessionManager.saveUser(mergedUser);
        emit(ProfileLoaded(user: mergedUser));
        return;
      }
    } catch (e) {
      print('Profile API Error: $e');
    }

    if (cachedUser == null && (token == null || token.isEmpty)) {
      emit(ProfileError('Unable to load your profile right now.'));
    }
  }

  Future<void> _onUpdateProfile(
    UpdateProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      final latestUser = userSessionManager.getUser() ?? currentState.user;
      emit(
        ProfileLoaded(
          user: latestUser,
          isVerified: currentState.isVerified,
        ),
      );
    }
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<ProfileState> emit) async {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      emit(
        ProfileLoaded(
          user: currentState.user,
          isVerified: currentState.isVerified,
          isLoggingOut: true,
        ),
      );
    }

    try {
      await authRemoteDataSource.logout();
    } on DioException catch (_) {
      // Logout should still complete locally even if the backend call fails.
    } catch (_) {
      // Keep local logout resilient.
    }

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}

    await userSessionManager.clearSession();
    authRemoteDataSource.apiClient.clearToken();
    sl<SignalRService>().disconnect();
    emit(ProfileLoggedOut());
  }

  Future<void> _onDeleteAccount(
    DeleteAccountEvent event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      emit(
        ProfileLoaded(
          user: currentState.user,
          isVerified: currentState.isVerified,
          isDeletingAccount: true,
        ),
      );
    }

    try {
      await authRemoteDataSource.deleteAccount();
    } on DioException catch (_) {
      // Even if the backend call fails, clear the session locally.
    } catch (_) {
      // Keep resilient.
    }

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}

    await userSessionManager.clearSession();
    authRemoteDataSource.apiClient.clearToken();
    sl<SignalRService>().disconnect();
    emit(ProfileAccountDeleted());
  }
}
