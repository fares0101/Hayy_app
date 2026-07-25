import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/user_session_manager.dart';

class ApiClient {
  late final Dio _dio;
  String? _token;
  final UserSessionManager? userSessionManager;
  
  Dio get dio => _dio;

  ApiClient({this.userSessionManager}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectionTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Load token from storage if available
    _token = userSessionManager?.getToken();

    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) {
          // Always get fresh token from storage
          final token = _token ?? userSessionManager?.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final options = error.requestOptions;

            // Prevent infinite loop if the refresh-token endpoint itself returns 401
            if (options.path.contains('/refresh-token')) {
              return handler.next(error);
            }

            try {
              final newToken = await _refreshToken();
              if (newToken != null) {
                // Update header with new token
                options.headers['Authorization'] = 'Bearer $newToken';
                
                // Retry the request with the new token
                final response = await _dio.fetch(options);
                return handler.resolve(response);
              }
            } catch (e) {
              // Refresh failed, clear session and pass the error along
              await userSessionManager?.clearSession();
              clearToken();
              return handler.next(error);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<String?> _refreshToken() async {
    final refreshToken = userSessionManager?.getRefreshToken();
    final expiredToken = _token ?? userSessionManager?.getToken();

    if (refreshToken == null || refreshToken.isEmpty || expiredToken == null || expiredToken.isEmpty) {
      return null;
    }

    try {
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: ApiConstants.connectionTimeout,
          receiveTimeout: ApiConstants.receiveTimeout,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      refreshDio.httpClientAdapter = _dio.httpClientAdapter;

      final response = await refreshDio.post(
        '/api/app/auth/refresh-token',
        data: {
          'accessToken': expiredToken,
          'refreshToken': refreshToken,
        },
      );

      final responseData = response.data;
      if (responseData != null && responseData is Map<String, dynamic>) {
        final newToken = _extractToken(responseData);
        final newRefreshToken = _extractRefreshToken(responseData);

        if (newToken != null && newToken.isNotEmpty) {
          _token = newToken;
          await userSessionManager?.sharedPreferences.setString('auth_token', newToken);
          if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
            await userSessionManager?.sharedPreferences.setString('refresh_token', newRefreshToken);
          }
          return newToken;
        }
      }
    } catch (e) {
      print('Token refresh failed: $e');
      rethrow;
    }
    return null;
  }

  String? _extractToken(Map<String, dynamic> responseData) {
    const possibleKeys = ['token', 'accessToken', 'jwtToken'];
    for (final key in possibleKeys) {
      final value = responseData[key];
      if (value is String && value.isNotEmpty) return value;
    }
    final nested = responseData['data'];
    if (nested is Map<String, dynamic>) {
      for (final key in possibleKeys) {
        final value = nested[key];
        if (value is String && value.isNotEmpty) return value;
      }
    }
    return null;
  }

  String? _extractRefreshToken(Map<String, dynamic> responseData) {
    const possibleKeys = ['refreshToken', 'refresh_token'];
    for (final key in possibleKeys) {
      final value = responseData[key];
      if (value is String && value.isNotEmpty) return value;
    }
    final nested = responseData['data'];
    if (nested is Map<String, dynamic>) {
      for (final key in possibleKeys) {
        final value = nested[key];
        if (value is String && value.isNotEmpty) return value;
      }
    }
    return null;
  }

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return await _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return await _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }
}
