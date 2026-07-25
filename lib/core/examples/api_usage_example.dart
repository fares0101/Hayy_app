import 'package:dio/dio.dart';
import '../network/api_client.dart';
import '../../data/user_app/datasources/auth_remote_data_source.dart';

// مثال على كيفية استخدام API في Login Bloc

class LoginExample {
  final AuthRemoteDataSource authDataSource;

  LoginExample(this.authDataSource);

  Future<void> loginUser(String email, String password) async {
    try {
      // استدعاء API
      final response = await authDataSource.login(email, password);
      
      // حفظ Token
      final token = response['token'];
      final apiClient = ApiClient();
      apiClient.setToken(token);
      
      // حفظ بيانات المستخدم
      final userData = response['user'];
      print('Login successful: $userData');
      
    } on DioException catch (e) {
      if (e.response != null) {
        // خطأ من السيرفر
        print('Error: ${e.response?.data}');
      } else {
        // خطأ في الاتصال
        print('Connection error: ${e.message}');
      }
    }
  }
}
