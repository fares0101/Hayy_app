import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app_router.dart';
import '../../../core/constants/assets_constants.dart';
import '../../../core/widgets/app_theme.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Animation controllers for page content transitions
  late AnimationController _contentController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Animation controller for image floating effect
  late AnimationController _imageFloatController;
  late Animation<double> _imageFloatAnimation;

  // Design constants — unified with AppTheme
  static const Color _topGradientStart = Color(0xFFFF7A35);
  static const Color _topGradientMid   = Color(0xFFFE6A1C);
  static const Color _topGradientEnd   = Color(0xFFD4510E);

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Discover Local Gems Around You',
      description:
          'Find cafés, shops, and services in\nyour area with real reviews from neighbors',
      image: AssetsConstants.onboarding1,
    ),
    OnboardingData(
      title: 'Share Your Experience',
      description:
          'Rate places, upload photos,\nand help others make better choices',
      image: AssetsConstants.onboarding2,
    ),
    OnboardingData(
      title: 'Connect with Your Community',
      description:
          'See what your neighbors love\nand discover hidden spots together',
      image: AssetsConstants.onboarding3,
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Content fade/slide animation
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );

    // Subtle floating animation for the image
    _imageFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _imageFloatAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _imageFloatController, curve: Curves.easeInOut),
    );

    _contentController.forward();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _pageController.dispose();
    _imageFloatController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    _contentController.reset();
    _contentController.forward();
  }

  void _handleNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    final isTablet = screenWidth > 600;

    final topSectionHeight = screenHeight * (isTablet ? 0.18 : 0.2);
    final buttonWidth = isTablet ? 140.0 : 120.0;
    final buttonHeight = isTablet ? 56.0 : 50.0;
    final buttonRightMargin = screenWidth * (isTablet ? 0.1 : 0.05);
    final buttonBottomInset =
        MediaQuery.of(context).padding.bottom + (isTablet ? 40 : 32);
    final contentBottomPadding = buttonBottomInset + buttonHeight + (isTablet ? 28 : 24);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── Top orange gradient section ──────────────────────────────
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
                  colors: [_topGradientStart, _topGradientMid, _topGradientEnd],
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

          // ── Cream rounded card below the gradient ────────────────────
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

          // ── Page content ─────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Keep content below the rounded top section
                SizedBox(height: topSectionHeight - 28),

                // Scrollable page content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _pages.length,
                    itemBuilder: (context, index) =>
                        _buildPageContent(
                          _pages[index],
                          screenHeight,
                          screenWidth,
                          isTablet,
                          contentBottomPadding,
                        ),
                  ),
                ),
              ],
            ),
          ),

          // ── Next button pinned at right side ────────────────────
          Positioned(
            right: buttonRightMargin,
            bottom: buttonBottomInset,
            child: _AnimatedButton(
              onPressed: _handleNext,
              isLastPage: _currentPage == _pages.length - 1,
              width: buttonWidth,
              height: buttonHeight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(
    OnboardingData data,
    double screenHeight,
    double screenWidth,
    bool isTablet,
    double contentBottomPadding,
  ) {
    final titleFontSize = screenHeight * (isTablet ? 0.032 : 0.027);
    final descFontSize = screenHeight * (isTablet ? 0.018 : 0.016);
    final imageHeight = screenHeight * (isTablet ? 0.29 : 0.26);
    final horizontalPadding = screenWidth * (isTablet ? 0.15 : 0.08);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        0,
        horizontalPadding,
        contentBottomPadding,
      ),
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _imageFloatAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _imageFloatAnimation.value),
                      child: child,
                    );
                  },
                  child: Image.asset(
                    data.image,
                    height: imageHeight,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: screenHeight * 0.04),
                Text(
                  data.title,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: screenHeight * 0.015),
                Text(
                  data.description,
                  style: TextStyle(
                    fontSize: descFontSize,
                    color: AppTheme.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: screenHeight * 0.04),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                      margin: EdgeInsets.symmetric(horizontal: isTablet ? 5 : 4),
                      width: _currentPage == index ? (isTablet ? 26 : 22) : (isTablet ? 10 : 8),
                      height: isTablet ? 10 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? AppTheme.primary
                            : AppTheme.primaryGlow,
                        borderRadius: BorderRadius.circular(isTablet ? 10 : 8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Next Button
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLastPage;
  final double width;
  final double height;
  const _AnimatedButton({
    required this.onPressed,
    this.isLastPage = false,
    this.width = 120,
    this.height = 50,
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
        HapticFeedback.selectionClick();
        widget.onPressed();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF7A35), Color(0xFFFE6A1C), Color(0xFFD4510E)],
              stops: [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(widget.height / 2),
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
              widget.isLastPage ? "Let's go!" : 'Next',
              style: TextStyle(
                fontSize: widget.width * 0.13,
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
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingData {
  final String title;
  final String description;
  final String image;

  OnboardingData({
    required this.title,
    required this.description,
    required this.image,
  });
}
