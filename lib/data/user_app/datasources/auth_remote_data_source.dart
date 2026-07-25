import 'dart:io';

import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/helpers/profile_image_helper.dart';
import '../../../core/network/api_client.dart';

class AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSource(this.apiClient);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await apiClient.post(
      '/api/app/auth/login',
      data: {'email': email, 'password': password},
    );
    final responseData = _ensureMapResponse(response.data);
    _cacheTokenFromResponse(responseData);
    return responseData;
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
    required String city,
  }) async {
    final formData = FormData.fromMap({
      'FullName': fullName,
      'Email': email,
      'Password': password,
      'ConfirmPassword': confirmPassword,
      'City': city,
    });

    final response = await apiClient.post(
      '/api/app/auth/register',
      data: formData,
    );
    return _ensureMapResponse(response.data);
  }

  Future<Map<String, dynamic>> googleLogin({
    required String provider,
    required String idToken,
  }) async {
    final response = await apiClient.post(
      '/api/app/auth/google-login',
      data: {
        'provider': provider,
        'idToken': idToken,
      },
    );
    final responseData = _ensureMapResponse(response.data);
    print('Google Login Response: $responseData');
    _cacheTokenFromResponse(responseData);
    return responseData;
  }

  Future<void> forgotPassword(String email) async {
    await apiClient.post(
      '/api/app/auth/forgot-password',
      data: {'email': email},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await apiClient.post(
      '/api/app/auth/reset-password',
      data: {
        'email': email,
        'token': token,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
  }

  Future<Map<String, dynamic>> fetchUserProfile() async {
    try {
      // Try the profile endpoint first (holds display name, city, image)
      final response = await apiClient.get(ApiConstants.userProfile);
      print('Fetch User Profile Response Status: ${response.statusCode}');
      print('Fetch User Profile Response Data: ${response.data}');
      return _ensureMapResponse(response.data);
    } catch (e) {
      print('User profile fetch failed, trying fallback auth/me: $e');
      // Fallback to authMe endpoint
      try {
        final response = await apiClient.get(ApiConstants.authMe);
        print('Fallback AuthMe Response: ${response.data}');
        return _ensureMapResponse(response.data);
      } catch (fallbackError) {
        print('Fetch Profile Error: $fallbackError');
        if (fallbackError is DioException) {
          print('DioException Type: ${fallbackError.type}');
          print('DioException Response: ${fallbackError.response?.data}');
          print('DioException Status: ${fallbackError.response?.statusCode}');
        }
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>> updateUserProfile({
    required String fullName,
    required String email,
    required String city,
    String? profileImagePath,
    String? password,
  }) async {
    final trimmedPassword = password?.trim() ?? '';
    final localImagePath =
        ProfileImageHelper.resolveLocalPath(profileImagePath);
    final resolvedProfileImage = localImagePath.isNotEmpty
        ? localImagePath
        : ProfileImageHelper.resolve(profileImagePath);
    final hasLocalImage = localImagePath.isNotEmpty;

    final payload = <String, dynamic>{
      'FullName': fullName,
      'fullName': fullName,
      'name': fullName,
      'Name': fullName,
      'Email': email,
      'email': email,
      'City': city,
      'city': city,
      if (trimmedPassword.isNotEmpty) 'Password': trimmedPassword,
      if (trimmedPassword.isNotEmpty) 'password': trimmedPassword,
      if (trimmedPassword.isNotEmpty) 'ConfirmPassword': trimmedPassword,
      if (trimmedPassword.isNotEmpty) 'confirmPassword': trimmedPassword,
      if (resolvedProfileImage.isNotEmpty &&
          resolvedProfileImage.startsWith('http')) ...{
        'profileImage': resolvedProfileImage,
        'profileImageUrl': resolvedProfileImage,
        'imageUrl': resolvedProfileImage,
        'avatar': resolvedProfileImage,
        'image': resolvedProfileImage,
        'ProfileImagePath': resolvedProfileImage,
        'profileImagePath': resolvedProfileImage,
      }
    };

    final endpoints = [
      {'path': ApiConstants.updateProfile, 'method': 'PUT'},
      {'path': ApiConstants.userProfile, 'method': 'PATCH'},
      {'path': ApiConstants.userProfile, 'method': 'PUT'},
      {'path': ApiConstants.userProfile, 'method': 'POST'},
    ];

    DioException? lastError;

    // 1. Try sending as JSON first (standard for modern APIs updating text data)
    if (!hasLocalImage) {
      for (final endpoint in endpoints) {
        try {
          final path = endpoint['path'] as String;
          final method = endpoint['method'] as String;
          print('Attempting profile update via JSON: $method $path');

          final Response response;
          if (method == 'PUT') {
            response = await apiClient.put(path, data: payload);
          } else if (method == 'PATCH') {
            response = await apiClient.patch(path, data: payload);
          } else {
            response = await apiClient.post(path, data: payload);
          }

          print('Successfully updated profile via JSON: $method $path');
          return _resolveProfileUpdateResponse(response.data);
        } on DioException catch (e) {
          lastError = e;
          print(
              'Failed profile update via JSON on ${endpoint['path']}: code=${e.response?.statusCode}, error=${e.message}');
        }
      }
    }

    // 2. Fallback to FormData (in case backend requires multi-part/form-data)

    for (final endpoint in endpoints) {
      try {
        final path = endpoint['path'] as String;
        final method = endpoint['method'] as String;
        print('Attempting profile update via FormData fallback: $method $path');

        final Map<String, dynamic> formDataMap =
            Map<String, dynamic>.from(payload);
        if (hasLocalImage) {
          final file = File(localImagePath);
          final fileName = file.path.split(RegExp(r'[/\\]')).last;
          formDataMap['image'] =
              await MultipartFile.fromFile(file.path, filename: fileName);
          formDataMap['profileImage'] =
              await MultipartFile.fromFile(file.path, filename: fileName);
          formDataMap['ProfileImage'] =
              await MultipartFile.fromFile(file.path, filename: fileName);
          formDataMap['file'] =
              await MultipartFile.fromFile(file.path, filename: fileName);
        }

        final formData = FormData.fromMap(formDataMap);
        final Response response;
        if (method == 'PUT') {
          response = await apiClient.put(path, data: formData);
        } else if (method == 'PATCH') {
          response = await apiClient.patch(path, data: formData);
        } else {
          response = await apiClient.post(path, data: formData);
        }

        print('Successfully updated profile via FormData: $method $path');
        return _resolveProfileUpdateResponse(response.data);
      } on DioException catch (e) {
        lastError = e;
        print(
            'Failed profile update via FormData on ${endpoint['path']}: code=${e.response?.statusCode}, error=${e.message}');
      }
    }

    throw lastError ?? Exception('Failed to update profile on all endpoints.');
  }

  Future<String?> uploadProfileImage(String localImagePath) async {
    final file = File(localImagePath);
    if (!file.existsSync()) return null;

    final fileName = file.path.split(RegExp(r'[/\\]')).last;

    // Try the most likely endpoint first, then fall back to alternatives.
    final endpoints = [
      '/api/User/upload-image',
      '/api/User/profile/image',
      '/api/User/profile-image',
      '/api/app/auth/upload-image',
    ];

    for (final endpoint in endpoints) {
      try {
        // Create a new FormData instance for every endpoint request to avoid stream reuse errors.
        final formData = FormData.fromMap({
          'image': await MultipartFile.fromFile(file.path, filename: fileName),
          'profileImage':
              await MultipartFile.fromFile(file.path, filename: fileName),
          'ProfileImage':
              await MultipartFile.fromFile(file.path, filename: fileName),
          'file': await MultipartFile.fromFile(file.path, filename: fileName),
        });
        final response = await apiClient.post(endpoint, data: formData);
        final url = _extractImageUrl(response.data);
        if (url != null && url.isNotEmpty) {
          return url;
        }
      } on DioException catch (e) {
        // 404 → try next endpoint; anything else → stop early.
        if (e.response?.statusCode != 404) {
          print('uploadProfileImage error on $endpoint: $e');
          break;
        }
      } catch (e) {
        print('uploadProfileImage unexpected error on $endpoint: $e');
        break;
      }
    }

    return null;
  }

  /// Tries to extract an image URL from various common API response shapes.
  String? _extractImageUrl(dynamic data) {
    if (data == null) return null;

    Map<String, dynamic>? map;
    if (data is Map<String, dynamic>) {
      map = data;
    } else if (data is Map) {
      map = Map<String, dynamic>.from(data);
    } else if (data is String) {
      final resolved = ProfileImageHelper.resolve(data);
      return resolved.isNotEmpty ? resolved : null;
    }

    if (map == null) return null;

    const urlKeys = [
      'imageUrl',
      'profileImage',
      'profileImageUrl',
      'profileImagePath',
      'ProfileImagePath',
      'url',
      'image',
      'avatarUrl',
      'avatar',
      'photoUrl',
      'photo',
      'picture',
    ];
    for (final key in urlKeys) {
      final val = map[key];
      if (val is String && val.trim().isNotEmpty) {
        final resolved = ProfileImageHelper.resolve(val);
        if (resolved.isNotEmpty) return resolved;
      }
    }

    for (final key in ['data', 'result', 'user', 'profile']) {
      final nested = map[key];
      if (nested is Map) {
        final nestedUrl = _extractImageUrl(Map<String, dynamic>.from(nested));
        if (nestedUrl != null && nestedUrl.isNotEmpty) {
          return nestedUrl;
        }
      }
    }

    return null;
  }

  Future<void> updateProfile({String? city}) async {
    try {
      // Try the update endpoint first
      final formData = FormData.fromMap({
        if (city != null) 'City': city,
      });
      await apiClient.put(ApiConstants.updateProfile, data: formData);
    } on DioException catch (e) {
      // If 404, try alternative endpoint
      if (e.response?.statusCode == 404) {
        print('Update endpoint not found, trying alternative...');

        // Try PATCH instead of PUT
        try {
          final formData = FormData.fromMap({
            if (city != null) 'City': city,
          });
          await apiClient.patch('/api/User/profile', data: formData);
          return;
        } catch (_) {}

        // Try POST to profile
        try {
          final formData = FormData.fromMap({
            if (city != null) 'City': city,
          });
          await apiClient.post('/api/User/profile', data: formData);
          return;
        } catch (_) {}

        // If all fail, throw original error
        rethrow;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String token,
  }) async {
    final response = await apiClient.post(
      '/api/app/auth/verify-email',
      data: {
        'email': email,
        'token': token,
      },
    );
    final responseData = _ensureMapResponse(response.data);
    _cacheTokenFromResponse(responseData);
    return responseData;
  }

  Future<Map<String, dynamic>> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    final response = await apiClient.post(
      '/api/app/auth/verify-email-otp',
      data: {
        'email': email,
        'otp': otp,
      },
    );
    final responseData = _ensureMapResponse(response.data);
    _cacheTokenFromResponse(responseData);
    return responseData;
  }

  Future<void> resendOtp(String email) async {
    await apiClient.post(
      '/api/app/auth/resend-otp',
      data: {'email': email},
    );
  }

  Future<void> logout() async {
    await apiClient.post('/api/app/auth/logout');
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    await apiClient.post(
      '/api/app/auth/change-password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmNewPassword': confirmNewPassword,
      },
    );
  }

  Future<void> deleteAccount() async {
    final endpoints = const [
      '/api/app/auth/account',
      '/api/User',
      '/api/User/delete',
      '/api/User/profile',
    ];

    DioException? lastDioException;

    for (final endpoint in endpoints) {
      try {
        print('Attempting to delete account via: $endpoint');
        await apiClient.delete(endpoint);
        print('Successfully deleted account via: $endpoint');
        return;
      } on DioException catch (e) {
        lastDioException = e;
        if (e.response?.statusCode == 404) {
          print('Endpoint $endpoint returned 404. Trying next fallback...');
          continue;
        }
        rethrow;
      }
    }

    if (lastDioException != null) {
      throw lastDioException;
    }
  }

  Map<String, dynamic> _ensureMapResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception('Unexpected response format from server.');
  }

  void _cacheTokenFromResponse(Map<String, dynamic> responseData) {
    final token = _extractToken(responseData);
    if (token != null && token.isNotEmpty) {
      apiClient.setToken(token);
    }
  }

  String? _extractToken(Map<String, dynamic> responseData) {
    const possibleKeys = ['token', 'accessToken', 'jwtToken'];

    for (final key in possibleKeys) {
      final value = responseData[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }

    final nested = responseData['data'];
    if (nested is Map<String, dynamic>) {
      for (final key in possibleKeys) {
        final value = nested[key];
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }

    return null;
  }

  Map<String, dynamic> _resolveProfileUpdateResponse(dynamic data) {
    try {
      return _ensureMapResponse(data);
    } catch (_) {
      // Some profile update endpoints return empty bodies; provide a safe fallback map.
      return <String, dynamic>{};
    }
  }
}
