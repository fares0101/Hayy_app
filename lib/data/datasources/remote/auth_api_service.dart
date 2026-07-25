import 'package:dio/dio.dart';

class AuthApiService {
  final Dio _dio;

  AuthApiService(this._dio);

  Future<Map<String, dynamic>> registerUser({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
    required String city,
  }) async {
    try {
      final formData = FormData.fromMap({
        'FullName': fullName,
        'Email': email,
        'Password': password,
        'ConfirmPassword': confirmPassword,
        'City': city,
      });

      final response = await _dio.post(
        '/api/app/auth/register',
        data: formData,
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }
}
