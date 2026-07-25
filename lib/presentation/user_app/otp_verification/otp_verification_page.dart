import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/assets_constants.dart';
import '../../../core/widgets/app_theme.dart';
import '../../../data/user_app/datasources/auth_remote_data_source.dart';
import '../../../injection_container.dart';
import '../../../app_router.dart';
import '../../../data/user_app/models/user_model.dart';
import '../../../core/storage/user_session_manager.dart';
import '../../../core/network/api_client.dart';

class OtpVerificationPage extends StatefulWidget {
  final String email;
  final String? password;
  const OtpVerificationPage({super.key, required this.email, this.password});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final topSectionHeight = screenHeight * 0.12;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Top gradient section
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: topSectionHeight,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF7A35), Color(0xFFFE6A1C), Color(0xFFD4510E)],
                  stops: [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x40FE6A1C),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                    spreadRadius: -4,
                  ),
                ],
              ),
            ),
          ),

          // Cream rounded card
          Positioned(
            top: topSectionHeight - 28,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Back button
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                SizedBox(height: topSectionHeight - 80),
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        Text(
                          'We have sent the verification\ncode to your email address',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: screenHeight * 0.022,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Illustration
                        Image.asset(
                          AssetsConstants.verificationIllustration,
                          height: screenHeight * 0.22,
                          errorBuilder: (_, __, ___) => Container(
                            height: screenHeight * 0.22,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.verified_user_outlined,
                              size: 80,
                              color: Color(0xFFFE5D17),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        // OTP Fields
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6,
                              (index) => _buildOtpField(index, screenHeight)),
                        ),
                        const SizedBox(height: 24),
                        // Resend text
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "If you didn't receive a code, ",
                              style: TextStyle(
                                fontSize: screenHeight * 0.016,
                                color: Colors.black87,
                              ),
                            ),
                            GestureDetector(
                              onTap: _resendOtp,
                              child: Text(
                                'Resend',
                                style: TextStyle(
                                  fontSize: screenHeight * 0.016,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'OR',
                          style: TextStyle(
                            fontSize: screenHeight * 0.018,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Google button
                        _buildGoogleButton(screenHeight),
                        const SizedBox(height: 32),
                        // Login link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: TextStyle(
                                fontSize: screenHeight * 0.016,
                                color: Colors.black87,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: screenHeight * 0.016,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpField(int index, double screenHeight) {
    const circleSize = 48.0;
    const fontSize = circleSize * 0.5;

    return Container(
      width: circleSize,
      height: circleSize,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        maxLines: 1,
        cursorColor: const Color(0xFFFE5D17),
        cursorWidth: 2.0,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          if (index == 5 && value.isNotEmpty) {
            _verifyOtp();
          }
        },
      ),
    );
  }

  Widget _buildGoogleButton(double screenHeight) {
    return GestureDetector(
      onTap: () async {
        try {
          final account = await GoogleSignIn.instance.authenticate();
          final auth = account.authentication;

          if (auth.idToken == null) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('فشل تسجيل الدخول بـ Google')),
            );
            return;
          }

          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(
              child: CircularProgressIndicator(color: Color(0xFFFE5D17)),
            ),
          );

          final authDataSource = sl<AuthRemoteDataSource>();
          final userSessionManager = sl<UserSessionManager>();
          await userSessionManager.clearUserData();
          await userSessionManager.mergeUserData(
            name: account.displayName,
            email: account.email,
            profileImagePath: account.photoUrl,
          );

          final response = await authDataSource.googleLogin(
            provider: 'google',
            idToken: auth.idToken!,
          );
          await userSessionManager.saveAuthSession(response);

          if (!mounted) return;
          Navigator.pop(context); // Close loading

          // Check profile completion
          try {
            final profile = await authDataSource.fetchUserProfile();
            await userSessionManager.saveAuthSession(profile);
            final resolvedUser = userSessionManager.getUser();
            final alreadyDoneInterests = userSessionManager.hasCompletedInterests(
              userId: resolvedUser?.id.trim(),
            );

            if (!mounted) return;
            if (resolvedUser?.hasRequiredProfile == true || alreadyDoneInterests) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.home,
                (route) => false,
              );
            } else {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.completeProfile,
                (route) => false,
              );
            }
          } catch (_) {
            if (!mounted) return;
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.completeProfile,
              (route) => false,
            );
          }
        } on GoogleSignInException catch (e) {
          if (!mounted) return;
          final description = (e.description ?? '').toLowerCase();
          if (description.contains('no credential available')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'لا يوجد حساب Google متاح لهذا التطبيق حالياً. تأكد من إضافة حساب Google على الجهاز وإعدادات OAuth (SHA-1 و package name).',
                ),
              ),
            );
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_extractErrorMessage(e))),
          );
        } catch (e) {
          if (!mounted) return;
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_extractErrorMessage(e))),
          );
        }
      },
      child: Container(
        width: screenHeight * 0.065,
        height: screenHeight * 0.065,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Center(
          child: Image.asset(
            AssetsConstants.googleIcon,
            width: screenHeight * 0.03,
            height: screenHeight * 0.03,
            errorBuilder: (_, __, ___) => Icon(
              Icons.g_mobiledata,
              color: Colors.red,
              size: screenHeight * 0.04,
            ),
          ),
        ),
      ),
    );
  }

  void _verifyOtp() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length != 6) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFFE5D17)),
      ),
    );

    try {
      final authDataSource = sl<AuthRemoteDataSource>();
      final response = await authDataSource.verifyEmailOtp(
        email: widget.email,
        otp: otp,
      );

      print('OTP Verification Response: $response');

      // Save session and update API client token
      final userSessionManager = sl<UserSessionManager>();
      await userSessionManager.saveAuthSession(response);

      var token = userSessionManager.getToken();

      // If the backend didn't provide a token in the OTP response, automatically log in.
      if ((token == null || token.isEmpty) && widget.password != null && widget.password!.isNotEmpty) {
        try {
          print('Auto-login triggered as OTP response lacked a token...');
          final loginResponse = await authDataSource.login(widget.email, widget.password!);
          await userSessionManager.saveAuthSession(loginResponse);
          token = userSessionManager.getToken();
        } catch (loginError) {
          print('Auto-login failed: $loginError');
        }
      }

      // Make sure API client has the token
      if (token != null && token.isNotEmpty) {
        print('Token saved: ${token.length > 20 ? token.substring(0, 20) : token}...');
        sl<ApiClient>().setToken(token);
      }

      // Fetch user profile from backend to get complete data
      try {
        final profile = await authDataSource.fetchUserProfile();
        print('User Profile fetched: $profile');

        // Save the complete profile data
        await userSessionManager.saveAuthSession(profile);
      } catch (profileError) {
        print('Failed to fetch profile: $profileError');
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم التحقق بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );

      final resolvedUser = userSessionManager.getUser() ?? UserModel.empty;
      final nextRoute = resolvedUser.hasRequiredProfile
          ? (userSessionManager.hasCompletedInterests(userId: resolvedUser.id)
              ? AppRoutes.home
              : AppRoutes.interests)
          : AppRoutes.completeProfile;

      Navigator.pushNamedAndRemoveUntil(
        context,
        nextRoute,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_extractErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resendOtp() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFFE5D17)),
      ),
    );

    try {
      final authDataSource = sl<AuthRemoteDataSource>();
      await authDataSource.resendOtp(widget.email);

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إعادة إرسال الكود!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_extractErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _extractErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'] ?? data['error'] ?? data['title'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
      if (data is String && data.isNotEmpty) {
        return data;
      }
      return error.message ?? 'فشل الطلب';
    }
    return error.toString();
  }
}
