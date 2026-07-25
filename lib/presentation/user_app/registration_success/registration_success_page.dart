import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../../app_router.dart';
import '../../../core/storage/user_session_manager.dart';
import '../../../core/services/signal_r_service.dart';
import '../../../injection_container.dart';

class RegistrationSuccessPage extends StatefulWidget {
  const RegistrationSuccessPage({super.key});

  @override
  State<RegistrationSuccessPage> createState() =>
      _RegistrationSuccessPageState();
}

class _RegistrationSuccessPageState extends State<RegistrationSuccessPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final topSectionHeight = screenHeight * 0.2;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: topSectionHeight,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFE5D17), Color(0xFF98380E)],
                ),
              ),
            ),
          ),
          Positioned(
            top: topSectionHeight - 28,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                SizedBox(height: topSectionHeight - 90),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.08,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: Container(
                              width: screenHeight * 0.15,
                              height: screenHeight * 0.15,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFE5D17).withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                size: screenHeight * 0.08,
                                color: const Color(0xFFFE5D17),
                              ),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.05),
                          Text(
                            'Your Sign up was successful',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: screenHeight * 0.026,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.15),
                          _AnimatedButton(
                            text: 'Go to home',
                            onPressed: () =>
                                _requestLocationAndContinue(context),
                            screenWidth: screenWidth,
                            screenHeight: screenHeight,
                          ),
                        ],
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

  /// Shows a friendly dialog explaining why location is needed,
  /// then requests the permission and navigates forward regardless of outcome.
  Future<void> _requestLocationAndContinue(BuildContext context) async {
    // Step 1: Check current status before showing any dialog
    LocationPermission permission = await Geolocator.checkPermission();

    // Step 2: If already granted/whileInUse — skip the dialog and navigate
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      if (context.mounted) _navigateNext(context);
      return;
    }

    // Step 3: If permanently denied — offer to open settings
    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) await _showPermanentlyDeniedDialog(context);
      if (context.mounted) _navigateNext(context);
      return;
    }

    // Step 4: Show explain-why dialog before the OS prompt
    if (context.mounted) {
      final agreed = await _showLocationExplainDialog(context);
      if (!agreed) {
        // User tapped "Maybe later" — navigate without permission
        if (context.mounted) _navigateNext(context);
        return;
      }
    }

    // Step 5: Request the OS permission
    permission = await Geolocator.requestPermission();

    if (!context.mounted) return;

    if (permission == LocationPermission.deniedForever) {
      await _showPermanentlyDeniedDialog(context);
    }

    if (context.mounted) _navigateNext(context);
  }

  void _navigateNext(BuildContext context) {
    final sessionManager = sl<UserSessionManager>();
    final userId = sessionManager.getUser()?.id;

    // Connect to real-time notifications via SignalR
    sl<SignalRService>().connect();

    final nextRoute = sessionManager.hasCompletedInterests(userId: userId)
        ? AppRoutes.home
        : AppRoutes.interests;
    Navigator.pushReplacementNamed(context, nextRoute);
  }

  /// Branded dialog explaining why the app needs location access.
  Future<bool> _showLocationExplainDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFE5D17).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 38,
                      color: Color(0xFFFE5D17),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Allow Location Access',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'HAYY uses your location to show nearby restaurants, cafes, and events — so you can discover the best places around you.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  // Allow button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFE5D17),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Allow Location',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Skip button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        'Maybe later',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  /// Shown when permission is permanently denied — directs user to settings.
  Future<void> _showPermanentlyDeniedDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Location Disabled',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Location access was denied. You can enable it anytime from your phone\'s Settings → Apps → HAYY → Permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Skip',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openAppSettings();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(
                color: Color(0xFFFE5D17),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
        HapticFeedback.heavyImpact();
        widget.onPressed();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.screenWidth * 0.7,
          height: widget.screenHeight * 0.065,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFE5D17), Color(0xFF98380E)],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFE5D17).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
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
