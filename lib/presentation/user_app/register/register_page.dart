import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import '../otp_verification/otp_verification_page.dart';
import '../../../core/storage/user_session_manager.dart';
import '../../../data/user_app/datasources/auth_remote_data_source.dart';
import '../../../app_router.dart';
import '../../../core/constants/assets_constants.dart';
import '../../../core/widgets/app_theme.dart';
import '../../../injection_container.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _agreeToTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  // Password strength tracking
  _PasswordCriteria _criteria = const _PasswordCriteria();
  bool _passwordTouched = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    final p = _passwordController.text;
    setState(() {
      _passwordTouched = p.isNotEmpty;
      _criteria = _PasswordCriteria.evaluate(p);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final topSectionHeight = screenHeight * 0.2;

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
                SizedBox(height: topSectionHeight - 28),
                Expanded(
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final horizontalPadding = screenWidth * 0.08;
                          final contentWidth =
                              screenWidth - (horizontalPadding * 2);

                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: 24,
                            ),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  width: contentWidth,
                                  child: _buildRegisterContent(
                                    screenHeight: screenHeight,
                                    screenWidth: screenWidth,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
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

  Widget _buildRegisterContent({
    required double screenHeight,
    required double screenWidth,
  }) {
    final fieldSpacing = screenHeight * 0.016;
    final sectionSpacing = screenHeight * 0.024;
    final textFieldPadding = screenHeight * 0.016;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sign up for the app',
          style: TextStyle(
            fontSize: screenHeight * 0.028,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: screenHeight * 0.03),
        _buildTextField(
          controller: _nameController,
          hint: 'Enter your name',
          screenHeight: screenHeight,
          verticalPadding: textFieldPadding,
        ),
        SizedBox(height: fieldSpacing),
        _buildTextField(
          controller: _cityController,
          hint: 'Your City',
          screenHeight: screenHeight,
          verticalPadding: textFieldPadding,
        ),
        SizedBox(height: fieldSpacing),
        _buildTextField(
          controller: _emailController,
          hint: 'Email/phone number',
          screenHeight: screenHeight,
          verticalPadding: textFieldPadding,
        ),
        SizedBox(height: fieldSpacing),
        // ── Password field + strength indicator ──────────────────────────
        _buildPasswordFieldWithStrength(
          controller: _passwordController,
          hint: 'Password',
          obscureText: _obscurePassword,
          screenHeight: screenHeight,
          verticalPadding: textFieldPadding,
          onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        SizedBox(height: fieldSpacing),
        _buildTextField(
          controller: _confirmPasswordController,
          hint: 'Confirm password',
          obscureText: _obscureConfirmPassword,
          screenHeight: screenHeight,
          verticalPadding: textFieldPadding,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.grey.shade400,
              size: 20,
            ),
            onPressed: () => setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            }),
          ),
        ),
        SizedBox(height: sectionSpacing * 1.2),
        _AnimatedButton(
          text: 'Sign Up',
          onPressed: () async {
            // Validate
            if (_nameController.text.isEmpty ||
                _cityController.text.isEmpty ||
                _emailController.text.isEmpty ||
                _passwordController.text.isEmpty ||
                _confirmPasswordController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please fill all fields')),
              );
              return;
            }

            // Password strength gate — must be at least "Good" (3+ criteria)
            if (_criteria.score < 3) {
              setState(() => _passwordTouched = true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Your password is too weak. Please follow the requirements shown below.',
                  ),
                  backgroundColor: Color(0xFFD32F2F),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }

            if (_passwordController.text != _confirmPasswordController.text) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Passwords do not match')),
              );
              return;
            }

            if (!_agreeToTerms) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please agree to terms and conditions'),
                ),
              );
              return;
            }

            // Show loading
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const Center(
                child: CircularProgressIndicator(color: Color(0xFFFE5D17)),
              ),
            );

            try {
              final authDataSource = sl<AuthRemoteDataSource>();
              await authDataSource.register(
                fullName: _nameController.text,
                email: _emailController.text,
                password: _passwordController.text,
                confirmPassword: _confirmPasswordController.text,
                city: _cityController.text,
              );

              final userSessionManager = sl<UserSessionManager>();
              await userSessionManager.clearUserData();
              await userSessionManager.mergeUserData(
                name: _nameController.text,
                email: _emailController.text,
                city: _cityController.text,
              );

              if (!mounted) return;
              Navigator.pop(context); // Close loading

              // Navigate to OTP verification
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OtpVerificationPage(
                    email: _emailController.text,
                    password: _passwordController.text,
                  ),
                ),
              );
            } catch (e) {
              if (!mounted) return;
              Navigator.pop(context); // Close loading
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_extractErrorMessage(e))),
              );
            }
          },
          screenWidth: screenWidth,
          screenHeight: screenHeight,
        ),
        SizedBox(height: sectionSpacing),
        Text(
          'OR',
          style: TextStyle(
            fontSize: screenHeight * 0.018,
            color: AppTheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: sectionSpacing),
        _buildGoogleButton(screenHeight),
        SizedBox(height: sectionSpacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: TextStyle(
                fontSize: screenHeight * 0.015,
                color: Colors.black87,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(
                'Login',
                style: TextStyle(
                  fontSize: screenHeight * 0.015,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: sectionSpacing),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: Checkbox(
                value: _agreeToTerms,
                onChanged: (value) => setState(() => _agreeToTerms = value ?? false),
                activeColor: const Color(0xFFFE5D17),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "By clicking on 'sign up', you're agreeing to the Chunky app Terms of Service and Privacy Policy",
                style: TextStyle(
                  fontSize: screenHeight * 0.013,
                  color: Colors.black54,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Password field with live strength indicator ───────────────────────────
  Widget _buildPasswordFieldWithStrength({
    required TextEditingController controller,
    required String hint,
    required bool obscureText,
    required double screenHeight,
    required double verticalPadding,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: controller,
          hint: hint,
          obscureText: obscureText,
          screenHeight: screenHeight,
          verticalPadding: verticalPadding,
          suffixIcon: IconButton(
            icon: Icon(
              obscureText
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.grey.shade400,
              size: 20,
            ),
            onPressed: onToggle,
          ),
        ),
        // Show strength UI only after user starts typing
        if (_passwordTouched) ...[
          const SizedBox(height: 10),
          _PasswordStrengthBar(criteria: _criteria),
          const SizedBox(height: 8),
          _PasswordCriteriaList(criteria: _criteria),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required double screenHeight,
    required double verticalPadding,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppTheme.textMuted,
          fontSize: screenHeight * 0.016,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(
            color: Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(
            color: AppTheme.primary,
            width: 1.5,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: verticalPadding,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildGoogleButton(double screenHeight) {
    return GestureDetector(
      onTap: () async {
        try {
          // Step 1: Authenticate with Google
          final GoogleSignInAccount account = await GoogleSignIn.instance.authenticate();
          final GoogleSignInAuthentication auth = account.authentication;
          
          if (auth.idToken == null) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Google Sign-In did not return idToken')),
            );
            return;
          }
          
          // Step 2: Show loading
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(
              child: CircularProgressIndicator(color: Color(0xFFFE5D17)),
            ),
          );

          final userSessionManager = sl<UserSessionManager>();
          await userSessionManager.clearUserData();
          await userSessionManager.mergeUserData(
            name: account.displayName,
            email: account.email,
            profileImagePath: account.photoUrl,
          );

          // Step 3: Send ID token to backend
          final authDataSource = sl<AuthRemoteDataSource>();
          final response = await authDataSource.googleLogin(
            provider: 'google',
            idToken: auth.idToken!,
          );
          await userSessionManager.saveAuthSession(response);

          if (!mounted) return;
          Navigator.pop(context); // Close loading

          // Step 4: Check if profile is complete
          try {
            final profile = await authDataSource.fetchUserProfile();
            await userSessionManager.saveAuthSession(profile);
            final resolvedUser = userSessionManager.getUser();

            if (resolvedUser?.hasRequiredProfile == true) {
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, AppRoutes.home);
              return;
            }
          } catch (profileError) {
            print('Profile fetch error: $profileError');
          }

          if (!mounted) return;
          Navigator.pushReplacementNamed(context, AppRoutes.completeProfile);
          return;
        } on GoogleSignInException catch (e) {
          if (e.code == GoogleSignInExceptionCode.canceled) {
            final recoveredIdToken = await _recoverIdTokenAfterCanceled();
            if (recoveredIdToken != null) {
              // Show loading
              if (!mounted) return;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFE5D17)),
                ),
              );

              final account =
                  await GoogleSignIn.instance.attemptLightweightAuthentication();
              final userSessionManager = sl<UserSessionManager>();
              await userSessionManager.clearUserData();
              await userSessionManager.mergeUserData(
                name: account?.displayName,
                email: account?.email,
                profileImagePath: account?.photoUrl,
              );

              final authDataSource = sl<AuthRemoteDataSource>();
              final response = await authDataSource.googleLogin(
                provider: 'google',
                idToken: recoveredIdToken,
              );
              await userSessionManager.saveAuthSession(response);

              if (!mounted) return;
              Navigator.pop(context); // Close loading

              // Check if profile is complete
              try {
                final profile = await authDataSource.fetchUserProfile();
                await userSessionManager.saveAuthSession(profile);
                final resolvedUser = userSessionManager.getUser();

                if (resolvedUser?.hasRequiredProfile == true) {
                  if (!mounted) return;
                  Navigator.pushReplacementNamed(context, AppRoutes.home);
                  return;
                }
              } catch (_) {}

              if (!mounted) return;
              Navigator.pushReplacementNamed(context, AppRoutes.completeProfile);
              return;
            }

            if (!mounted) return;
            final details = e.description ?? 'No extra details';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Google Sign-In canceled: $details')),
            );
            return;
          }
          final description = (e.description ?? '').toLowerCase();
          if (description.contains('no credential available')) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Google account is not available for this app yet. Check Google account on device and OAuth SHA-1/package setup.',
                ),
              ),
            );
            return;
          }
          
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Google sign in failed: ${e.toString()}')),
          );
        } catch (e) {
          if (!mounted) return;
          // Close loading if open
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

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _emailController.dispose();
    _passwordController.removeListener(_onPasswordChanged);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
      return error.message ?? 'Request failed';
    }
    return error.toString();
  }

  Future<String?> _recoverIdTokenAfterCanceled() async {
    try {
      final lightweightAuthFuture =
          GoogleSignIn.instance.attemptLightweightAuthentication(
        reportAllExceptions: true,
      );
      if (lightweightAuthFuture == null) {
        return null;
      }
      final account = await lightweightAuthFuture;
      return account?.authentication.idToken;
    } catch (_) {
      return null;
    }
  }
}

class _AnimatedButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final double screenWidth;
  final double screenHeight;
  const _AnimatedButton({
    required this.text,
    required this.onPressed,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {
        _controller.reverse();
        HapticFeedback.mediumImpact();
        widget.onPressed();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.screenWidth * 0.5,
          height: widget.screenHeight * 0.065,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF7A35), Color(0xFFFE6A1C), Color(0xFFD4510E)],
              stops: [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Color(0x40FE6A1C),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.text,
              style: TextStyle(
                fontSize: widget.screenHeight * 0.02,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Password strength data model
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordCriteria {
  final bool hasMinLength;   // ≥ 8 characters
  final bool hasUppercase;   // A-Z
  final bool hasLowercase;   // a-z
  final bool hasDigit;       // 0-9
  final bool hasSpecial;     // !@#\$%^&*…

  const _PasswordCriteria({
    this.hasMinLength = false,
    this.hasUppercase = false,
    this.hasLowercase = false,
    this.hasDigit = false,
    this.hasSpecial = false,
  });

  factory _PasswordCriteria.evaluate(String password) {
    return _PasswordCriteria(
      hasMinLength: password.length >= 8,
      hasUppercase: password.contains(RegExp(r'[A-Z]')),
      hasLowercase: password.contains(RegExp(r'[a-z]')),
      hasDigit: password.contains(RegExp(r'[0-9]')),
      hasSpecial: password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>\-_=+\[\]\\\/~`]')),
    );
  }

  /// Number of criteria met (0–5)
  int get score =>
      (hasMinLength ? 1 : 0) +
      (hasUppercase ? 1 : 0) +
      (hasLowercase ? 1 : 0) +
      (hasDigit ? 1 : 0) +
      (hasSpecial ? 1 : 0);

  /// Human-readable label
  String get label {
    if (score <= 1) return 'Very Weak';
    if (score == 2) return 'Weak';
    if (score == 3) return 'Fair';
    if (score == 4) return 'Good';
    return 'Strong';
  }

  /// Brand-consistent color
  Color get color {
    if (score <= 1) return const Color(0xFFD32F2F); // deep red
    if (score == 2) return const Color(0xFFFF6F00); // amber-orange
    if (score == 3) return const Color(0xFFF9A825); // yellow-amber
    if (score == 4) return const Color(0xFF43A047); // green
    return const Color(0xFF1B5E20);                 // deep green
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated segmented strength bar
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordStrengthBar extends StatelessWidget {
  final _PasswordCriteria criteria;
  const _PasswordStrengthBar({required this.criteria});

  @override
  Widget build(BuildContext context) {
    final score = criteria.score;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (i) {
            final filled = i < score;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                height: 5,
                margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: filled
                      ? criteria.color
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 5),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: criteria.color,
          ),
          child: Text(criteria.label),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live criteria checklist
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordCriteriaList extends StatelessWidget {
  final _PasswordCriteria criteria;
  const _PasswordCriteriaList({required this.criteria});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password must contain:',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF444444),
            ),
          ),
          const SizedBox(height: 8),
          _CriterionRow(met: criteria.hasMinLength, text: 'At least 8 characters'),
          _CriterionRow(met: criteria.hasUppercase, text: 'At least one uppercase letter (A-Z)'),
          _CriterionRow(met: criteria.hasLowercase, text: 'At least one lowercase letter (a-z)'),
          _CriterionRow(met: criteria.hasDigit,     text: 'At least one number (0-9)'),
          _CriterionRow(met: criteria.hasSpecial,   text: 'At least one special character (!@#\$…)'),
        ],
      ),
    );
  }
}

class _CriterionRow extends StatelessWidget {
  final bool met;
  final String text;
  const _CriterionRow({required this.met, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: met
                  ? const Color(0xFF43A047).withValues(alpha: 0.12)
                  : Colors.transparent,
              border: Border.all(
                color: met
                    ? const Color(0xFF43A047)
                    : Colors.black.withValues(alpha: 0.22),
                width: 1.4,
              ),
            ),
            child: Center(
              child: Icon(
                met ? Icons.check_rounded : Icons.close_rounded,
                size: 11,
                color: met
                    ? const Color(0xFF43A047)
                    : Colors.black.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 12,
                color: met
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF888888),
                fontWeight: met ? FontWeight.w500 : FontWeight.w400,
              ),
              child: Text(text),
            ),
          ),
        ],
      ),
    );
  }
}
