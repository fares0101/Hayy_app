import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../app_router.dart';
import '../../../core/constants/assets_constants.dart';
import '../../../core/widgets/app_theme.dart';
import '../../../injection_container.dart';
import '../register/register_page.dart';
import 'login_bloc.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LoginBloc>(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
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
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final topSectionHeight = screenHeight * 0.2;

    return BlocListener<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state is LoginSuccess) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        } else if (state is LoginNeedsProfileCompletion) {
          Navigator.pushReplacementNamed(context, AppRoutes.completeProfile);
        } else if (state is LoginError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
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
                                    child: _buildLoginContent(
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
      ),
    );
  }

  Widget _buildLoginContent({
    required double screenHeight,
    required double screenWidth,
  }) {
    final fieldSpacing = screenHeight * 0.018;
    final sectionSpacing = screenHeight * 0.024;
    final textFieldPadding = screenHeight * 0.016;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Welcome!',
          style: TextStyle(
            fontSize: screenHeight * 0.032,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: screenHeight * 0.04),
        _buildTextField(
          controller: _emailController,
          hint: 'Enter your email/number',
          screenHeight: screenHeight,
          verticalPadding: textFieldPadding,
        ),
        SizedBox(height: fieldSpacing),
        _buildTextField(
          controller: _passwordController,
          hint: 'Enter your password',
          obscureText: _obscurePassword,
          screenHeight: screenHeight,
          verticalPadding: textFieldPadding,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.grey.shade400,
              size: 20,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        SizedBox(height: screenHeight * 0.01),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (value) =>
                        setState(() => _rememberMe = value ?? false),
                    activeColor: const Color(0xFFFE5D17),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Remember Me',
                  style: TextStyle(
                    fontSize: screenHeight * 0.014,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.forgotPassword),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Forgotten password?',
                style: TextStyle(
                  fontSize: screenHeight * 0.014,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: sectionSpacing * 1.35),
        BlocBuilder<LoginBloc, LoginState>(
          builder: (context, state) {
            return _AnimatedButton(
              text: 'Log In',
              isLoading: state is LoginLoading,
              onPressed: () {
                final email = _emailController.text.trim();
                final password = _passwordController.text;
                if (email.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }
                context.read<LoginBloc>().login(email, password);
              },
              screenWidth: screenWidth,
              screenHeight: screenHeight,
            );
          },
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
              "Don't have an account? ",
              style: TextStyle(
                fontSize: screenHeight * 0.015,
                color: Colors.black87,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return FadeTransition(
                      opacity: animation,
                      child: const RegisterPage(),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 400),
                ),
              ),
              child: Text(
                'Sign Up',
                style: TextStyle(
                  fontSize: screenHeight * 0.015,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
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
          final GoogleSignInAccount account =
              await GoogleSignIn.instance.authenticate();
          final GoogleSignInAuthentication auth = account.authentication;
          if (!mounted) return;
          if (auth.idToken == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Google Sign-In did not return idToken')),
            );
            return;
          }
          context.read<LoginBloc>().googleLogin(
                auth.idToken!,
                name: account.displayName,
                email: account.email,
                profileImagePath: account.photoUrl,
              );
        } on GoogleSignInException catch (e) {
          if (e.code == GoogleSignInExceptionCode.canceled) {
            final recoveredIdToken = await _recoverIdTokenAfterCanceled();
            if (!mounted) return;
            if (recoveredIdToken != null) {
              final account =
                  await GoogleSignIn.instance.attemptLightweightAuthentication();
              if (!mounted) return;
              context.read<LoginBloc>().googleLogin(
                    recoveredIdToken,
                    name: account?.displayName,
                    email: account?.email,
                    profileImagePath: account?.photoUrl,
                  );
              return;
            }
            if (!mounted) return;
            final details = e.description ?? 'No extra details';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Google Sign-In canceled: $details',
                ),
              ),
            );
            return;
          }
          final description = (e.description ?? '').toLowerCase();
          if (description.contains('network_error') || e.code == 'network_error') {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لا يوجد اتصال بالإنترنت. يرجى التحقق من الشبكة والمحاولة مرة أخرى.'),
              ),
            );
            return;
          }
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
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('network_error') || errorStr.contains('socketexception') || errorStr.contains('failed host lookup')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لا يوجد اتصال بالإنترنت. يرجى التحقق من الشبكة والمحاولة مرة أخرى.'),
              ),
            );
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Google sign in failed: ${e.toString()}')),
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

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class _AnimatedButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final double screenWidth;
  final double screenHeight;
  final bool isLoading;
  const _AnimatedButton({
    required this.text,
    required this.onPressed,
    required this.screenWidth,
    required this.screenHeight,
    this.isLoading = false,
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
      onTapDown: widget.isLoading ? null : (_) => _controller.forward(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.isLoading ? null : () {
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
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
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
