import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/api_client.dart';
import 'core/storage/user_session_manager.dart';
import 'core/services/privacy_service.dart';
import 'core/services/notification_settings_service.dart';
import 'core/services/signal_r_service.dart';
import 'data/user_app/datasources/auth_remote_data_source.dart';
import 'data/user_app/datasources/business_posts_remote_data_source.dart';
import 'data/user_app/datasources/comments_remote_data_source.dart';
import 'data/user_app/datasources/favorites_remote_data_source.dart';
import 'data/user_app/datasources/notifications_remote_data_source.dart';
import 'data/user_app/datasources/places_remote_data_source.dart';
import 'data/user_app/datasources/interests_remote_data_source.dart';
import 'data/user_app/datasources/booking_remote_data_source.dart';
import 'data/user_app/datasources/reviews_remote_data_source.dart';
import 'data/user_app/repositories/auth_repository_impl.dart';
import 'domain/user_app/repositories/auth_repository.dart';
import 'domain/user_app/usecases/login_usecase.dart';
import 'domain/user_app/usecases/forgot_password_usecase.dart';
import 'presentation/user_app/login/login_bloc.dart';
import 'presentation/user_app/forgot_password/forgot_password_bloc.dart';
import 'presentation/user_app/notifications/notifications_bloc.dart';
import 'presentation/user_app/profile/profile_bloc.dart';
import 'presentation/user_app/booking/booking_bloc.dart';
import 'presentation/user_app/reviews/reviews_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  // Core
  sl.registerLazySingleton(() => UserSessionManager(sl()));
  sl.registerLazySingleton(() => ApiClient(userSessionManager: sl()));
  sl.registerLazySingleton(() => PrivacyService(sl()));
  sl.registerLazySingleton(() => NotificationSettingsService(sl(), sl()));

  sl.registerLazySingleton(() => SignalRService(sl()));

  final cachedToken = sl<UserSessionManager>().getToken();
  if (cachedToken != null) {
    sl<ApiClient>().setToken(cachedToken);
    sl<SignalRService>().connect();
  }

  // Data Sources
  sl.registerLazySingleton(() => AuthRemoteDataSource(sl()));
  sl.registerLazySingleton(() => BusinessPostsRemoteDataSource(sl()));
  sl.registerLazySingleton(() => CommentsRemoteDataSource(sl()));
  sl.registerLazySingleton(() => FavoritesRemoteDataSource(sl()));
  sl.registerLazySingleton(() => NotificationsRemoteDataSource(sl()));
  sl.registerLazySingleton(() => PlacesRemoteDataSource(sl()));
  sl.registerLazySingleton(() => InterestsRemoteDataSource(sl()));
  sl.registerLazySingleton(() => BookingRemoteDataSource(sl()));
  sl.registerLazySingleton(() => ReviewsRemoteDataSource(apiClient: sl()));

  // Repositories
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()));

  // Use Cases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => ForgotPasswordUseCase(sl()));

  // Blocs
  sl.registerFactory(() => LoginBloc(sl(), sl(), sl()));
  sl.registerFactory(() => ForgotPasswordBloc(sl()));
  sl.registerFactory(() => NotificationsBloc(sl(), sl()));
  sl.registerFactory(() => ProfileBloc(sl(), sl()));
  sl.registerFactory(() => BookingBloc(sl(), sl()));
  sl.registerFactory(() => ReviewsBloc(remoteDataSource: sl()));
}
