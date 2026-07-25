import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'splash_cubit.dart';
import '../../../app_router.dart';
import '../../../injection_container.dart';
import '../../../core/storage/user_session_manager.dart';

// ══════════════════════════════════════════════════════════════════
// Page + View
// ══════════════════════════════════════════════════════════════════
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => SplashCubit()..initialize(),
        child: const SplashView(),
      );
}

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with TickerProviderStateMixin {
  late final AnimationController _pinController;
  late final Animation<double> _pinAnimation;

  late final AnimationController _rippleController;

  late final AnimationController _taglineController;
  late final Animation<double> _taglineAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Pin Drop Controller (700-900ms)
    _pinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _pinAnimation = CurvedAnimation(
      parent: _pinController,
      curve: Curves.easeOutBack, // overshoot and settle naturally
    );

    // 2. Ripple Controller (loops continuously)
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // 3. Tagline Controller (fade in after pin settles)
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _taglineAnimation = CurvedAnimation(
      parent: _taglineController,
      curve: Curves.easeIn,
    );

    // Sequence trigger
    _pinController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _rippleController.repeat();
        _taglineController.forward();
      }
    });

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      _pinController.forward();
    }

    // Settle time and page redirect logic
    await Future.delayed(const Duration(milliseconds: 3300));
    if (mounted) {
      final token = sl<UserSessionManager>().getToken();
      final targetRoute = (token != null && token.isNotEmpty)
          ? AppRoutes.home
          : AppRoutes.onboarding;
      Navigator.pushReplacementNamed(context, targetRoute);
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _rippleController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;

    // The visual width of the logo letters H A Y Y should occupy ~78% of screen width.
    final double logoW = sw * 0.78;

    // Bounding box of the letters inside the SVG canvas (1536x1024):
    // Left: 318.95, Right: 1377.00 (Width: 1058.05)
    // Top: 303.79, Bottom: 667.00 (Height: 363.21)
    final double logoH =
        logoW * (363.21 / 1058.05); // Aspect ratio of the letter bounding box

    // Canvas scaling factors to render the SVG exactly cropped to the letters bounds
    final double svgW = logoW * (1536 / 1058.05);
    final double svgH =
        svgW / 1.5; // Aspect ratio of the SVG canvas is 1.5 (1536x1024)
    final double leftOffset = -logoW * (318.95 / 1058.05);
    final double topOffset = -logoH * (303.79 / 363.21);

    // Relative positions inside the visual bounding box of the Stack
    // Center of A is at X = 710.81 -> (710.81 - 318.95) = 391.86 relative to H's left edge
    final double centerAX = logoW * (391.86 / 1058.05);
    final double pinW = logoW * (105 / 1058.05); // Smaller pin size (105 instead of 135)
    final double pinH = pinW * 1.375; // location_pin.svg aspect ratio is 55/40
    final double rippleW = logoW * (300 / 1058.05); // Match smaller pin width proportion
    final double rippleH = rippleW * 0.22;

    // Resting position: Y = 593.79 in the SVG -> (593.79 - 303.79) = 290.0 relative to A's top peak
    // This controls the vertical position (up/down) of the pin and ripple. Increase 290.0 to move down, decrease to move up.
    final double restPinTipY = logoH * (320.0 / 363.21); // Moved lower (320.0 instead of 290.0)

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Color(0xFFFE6E30), // Soft radial glow in the center
              Color(0xFFFE5116), // Dark orange towards edges
            ],
            center: Alignment.center,
            radius: 1.05,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo + Pin + Ripple Stack
              SizedBox(
                width: logoW,
                height:
                    logoH, // Height ends exactly at the baseline of the letters
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Concentric Ripple Animation
                    Positioned(
                      left: centerAX - rippleW / 2,
                      top: restPinTipY - rippleH / 2 + 4,
                      child: RippleAnimation(
                        width: rippleW,
                        height: rippleH,
                        animation: _rippleController,
                      ),
                    ),

                    // 2. Wordmark Logo Shadow (Crisp PNG Shadow)
                    Positioned(
                      left: leftOffset,
                      top: topOffset + 1.2,
                      width: svgW,
                      height: svgH,
                      child: Image.asset(
                        'assets/images/logos/Logo PNG.png',
                        width: svgW,
                        height: svgH,
                        color: const Color(0x1C000000),
                        colorBlendMode: BlendMode.srcIn,
                        fit: BoxFit.contain,
                      ),
                    ),

                    // 3. Wordmark Logo Foreground
                    Positioned(
                      left: leftOffset,
                      top: topOffset,
                      width: svgW,
                      height: svgH,
                      child: SplashLogo(
                        width: svgW,
                        height: svgH,
                      ),
                    ),

                    // 4. Location Pin Shadow (Crisp Vector Shadow)
                    AnimatedBuilder(
                      animation: _pinAnimation,
                      builder: (context, _) {
                        final double startY = -logoH * 3.0;
                        final double endY = restPinTipY - pinH;
                        final double currentY =
                            startY + (endY - startY) * _pinAnimation.value;

                        return Positioned(
                          left: centerAX - pinW / 2,
                          top: currentY + 1.2,
                          child: SvgPicture.asset(
                            'assets/images/logos/location_pin.svg',
                            width: pinW,
                            height: pinH,
                            colorFilter: const ColorFilter.mode(
                                Color(0x1C000000), BlendMode.srcIn),
                            fit: BoxFit.contain,
                          ),
                        );
                      },
                    ),

                    // 5. Location Pin Foreground
                    AnimatedBuilder(
                      animation: _pinAnimation,
                      builder: (context, _) {
                        final double startY = -logoH * 3.0;
                        final double endY = restPinTipY - pinH;
                        final double currentY =
                            startY + (endY - startY) * _pinAnimation.value;

                        return Positioned(
                          left: centerAX - pinW / 2,
                          top: currentY,
                          child: AnimatedLocationPin(
                            width: pinW,
                            height: pinH,
                            animation: _pinAnimation,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 55), // Spacing between ripple and tagline
              // Tagline
              SplashTagline(
                width: sw,
                animation: _taglineAnimation,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Component Widgets
// ══════════════════════════════════════════════════════════════════

class SplashLogo extends StatelessWidget {
  final double width;
  final double height;

  const SplashLogo({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logos/Logo PNG.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }
}

class AnimatedLocationPin extends StatelessWidget {
  final double width;
  final double height;
  final Animation<double> animation;

  const AnimatedLocationPin({
    super.key,
    required this.width,
    required this.height,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/logos/location_pin.svg',
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }
}

class RippleAnimation extends StatelessWidget {
  final double width;
  final double height;
  final Animation<double> animation;

  const RippleAnimation({
    super.key,
    required this.width,
    required this.height,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          size: Size(width, height),
          painter: _RipplePainter(animation.value),
        );
      },
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress;

  _RipplePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFAC82) // Soft light orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final cx = size.width / 2;
    final cy = size.height / 2;

    for (int i = 0; i < 3; i++) {
      // Offset each circle's start time
      final double t = (progress - (i / 3.0)) % 1.0;
      if (t < 0) continue;

      // Shrink size (collapsing towards center)
      final double currentW = size.width * (1.0 - t);
      final double currentH = size.height * (1.0 - t);

      // Fade out opacity as they get smaller
      final double opacity = (1.0 - t) * 0.35;

      paint.color = const Color(0xFFFFAC82).withValues(alpha: opacity);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: currentW,
          height: currentH,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class SplashTagline extends StatelessWidget {
  final double width;
  final Animation<double> animation;

  const SplashTagline({
    super.key,
    required this.width,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final double lineWidth = width * 0.17;
    const lineColor = Color(0x44FFFFFF); // Soft white line

    final txtStyle = GoogleFonts.cairo(
      color: const Color(0xDDFFFFFF), // High contrast soft white
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      height: 1.0,
    );

    return FadeTransition(
      opacity: animation,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: lineWidth, height: 0.8, color: lineColor),
          const SizedBox(width: 16),
          Text(
            'كل مكان له حكاية',
            style: txtStyle,
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(width: 16),
          Container(width: lineWidth, height: 0.8, color: lineColor),
        ],
      ),
    );
  }
}
