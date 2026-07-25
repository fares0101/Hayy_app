import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../app_router.dart';
import '../../../data/user_app/datasources/places_remote_data_source.dart';
import '../../../injection_container.dart';
import '../../../core/widgets/themed_top_header.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/utils/image_url_formatter.dart';

class OfferDetailsPage extends StatefulWidget {
  final String offerId;
  final Map<String, dynamic>? offerData;

  const OfferDetailsPage({super.key, required this.offerId, this.offerData});

  @override
  State<OfferDetailsPage> createState() => _OfferDetailsPageState();
}

class _OfferDetailsPageState extends State<OfferDetailsPage> {
  Map<String, dynamic>? _offerData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOfferDetails();
  }

  Future<void> _loadOfferDetails() async {
    // If data was passed directly (from list), use it
    if (widget.offerData != null && widget.offerData!.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _offerData = widget.offerData;
        _isLoading = false;
      });
      return;
    }

    final offerId = widget.offerId.trim();
    if (offerId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid offer ID.';
      });
      return;
    }

    try {
      final dataSource = sl<PlacesRemoteDataSource>();
      final data = await dataSource.getOfferDetails(offerId);

      if (!mounted) return;

      setState(() {
        _offerData = data;
        _isLoading = false;
        _errorMessage = data.isEmpty ? 'Offer not found.' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load offer details.';
      });
    }
  }

  void _navigateToTab(int index) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
      arguments: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: Column(
        children: [
          ThemedTopHeader(
            title: 'Offer Details',
            showBackButton: true,
            onBackPressed: () => Navigator.maybePop(context),
          ),
          Expanded(child: _buildBodyContent()),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return ShimmerLoading.buildDetailsScreen();
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFE5D17).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_offer_outlined,
                  size: 40,
                  color: Color(0xFFFE5D17),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF545454),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Retry',
                width: 150,
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadOfferDetails();
                },
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOfferCard(context),
        ],
      ),
    );
  }

  Widget _buildOfferCard(BuildContext context) {
    // Extract image: check 'image' key first (pre-formatted by home page mapper),
    // then fall back to full map extraction.
    final dataMap = _offerData ?? widget.offerData ?? {};
    final preFormatted = dataMap['image'];
    final imageUrl = (preFormatted is String && preFormatted.isNotEmpty)
        ? preFormatted
        : ImageUrlFormatter.extractFromMap(dataMap);

    final title = _firstString(
      const ['title', 'offerTitle', 'name'],
      fallback: 'Special Offer',
    );
    final placeName = _firstString(
      const ['placeName', 'businessName', 'merchantName', 'authorName'],
      fallback: '',
    );
    final description = _firstString(
      const ['description', 'shortDescription', 'details'],
      fallback: 'No description available for this offer.',
    );
    final validUntil = _formatDate(
      _firstValue(const ['validUntil', 'endDate', 'expiryDate']),
    );
    final promoCode = _firstString(
      const ['promoCode', 'code', 'couponCode', 'voucherCode'],
      fallback: 'HAYY-SPECIAL',
    );
    final terms = _extractTerms();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBEBEB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageHeader(imageUrl),
            if (placeName.isNotEmpty) _buildMerchantBar(placeName),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B2B2B),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              placeName.isNotEmpty ? placeName : 'Active offer',
              style: const TextStyle(
                color: Color(0xFF8A8A8A),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6E6E6E),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            _buildPromoCodeBox(promoCode),
            const SizedBox(height: 12),
            _buildValidityCard(validUntil),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFEEEEEE), height: 1),
            const SizedBox(height: 16),
            _buildTermsSection(terms),
            const SizedBox(height: 20),
            Center(
              child: CustomButton(
                text: 'Redeem Offer',
                width: double.infinity,
                onPressed: () =>
                    _showRedeemBottomSheet(context, title, promoCode),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageHeader(String imageUrl) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: imageUrl.isEmpty
              ? Container(
                  height: 260,
                  width: double.infinity,
                  color: const Color(0xFF1A1A2A),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.local_offer_outlined,
                    color: Color(0xFF555566),
                    size: 60,
                  ),
                )
              : Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 260,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 260,
                    width: double.infinity,
                    color: const Color(0xFF1A1A2A),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: Color(0xFF555566),
                      size: 60,
                    ),
                  ),
                ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFE5D17), Color(0xFFFF7E47)],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFE5D17).withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flash_on_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  _discountLabel(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMerchantBar(String placeName) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFE5D17).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFFE5D17).withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFFE5D17),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_rounded,
                color: Colors.white, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              placeName,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2B2B2B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCodeBox(String code) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB08A), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFE5D17).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.confirmation_number_outlined,
              color: Color(0xFFFE5D17),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROMO CODE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B8B8B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  code,
                  style: const TextStyle(
                    color: Color(0xFF1E1E1E),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Promo Code "$code" copied!'),
                  backgroundColor: const Color(0xFF2E2E2E),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFE5D17),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Copy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidityCard(String validUntil) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFE5D17).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.access_time_filled_rounded,
              size: 18,
              color: Color(0xFFFE5D17),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Validity Period',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF8B8B8B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Valid until $validUntil',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E2E2E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection(List<String> terms) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.verified_user_outlined,
                size: 18, color: Color(0xFF2E2E2E)),
            SizedBox(width: 8),
            Text(
              'Terms & Conditions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E2E2E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...terms.map(
          (term) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: Color(0xFFFE5D17),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    term,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF555555),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showRedeemBottomSheet(
      BuildContext context, String offerTitle, String promoCode) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFE5D17).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_offer_outlined,
                  size: 40,
                  color: Color(0xFFFE5D17),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFE5D17).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_offer_outlined,
                  size: 40,
                  color: Color(0xFFFE5D17),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                offerTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2E2E),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Show this promo code at the venue to claim your discount.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6E6E6E),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4EF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFB08A)),
                ),
                child: Text(
                  promoCode,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFE5D17),
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Done',
                width: double.infinity,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    final metrics = _getBottomBarMetrics();
    return Container(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          14,
          0,
          14,
          MediaQuery.paddingOf(context).bottom == 0 ? 10 : 0,
        ),
        child: SafeArea(
          top: false,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: metrics.contentHeight,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFE6A1C).withValues(alpha: 0.12),
                      blurRadius: 24,
                      spreadRadius: -2,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.horizontalPadding,
                    vertical: metrics.verticalPadding,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildNavItem(
                          icon: Icons.search_rounded,
                          label: 'Search',
                          iconSize: metrics.iconSize,
                          itemSize: metrics.itemSize,
                          labelFontSize: metrics.labelFontSize,
                          labelSpacing: metrics.labelSpacing,
                          onTap: () => _navigateToTab(0),
                        ),
                      ),
                      Expanded(
                        child: _buildNavItem(
                          icon: Icons.notifications_rounded,
                          label: 'Notif',
                          iconSize: metrics.iconSize,
                          itemSize: metrics.itemSize,
                          labelFontSize: metrics.labelFontSize,
                          labelSpacing: metrics.labelSpacing,
                          onTap: () => _navigateToTab(1),
                        ),
                      ),
                      Expanded(
                        child: _buildNavItem(
                          icon: Icons.home_rounded,
                          label: 'Home',
                          iconSize: metrics.iconSize,
                          itemSize: metrics.centerItemSize,
                          labelFontSize: metrics.labelFontSize,
                          labelSpacing: metrics.labelSpacing,
                          isCenter: true,
                          isSelected: true,
                          onTap: () => _navigateToTab(2),
                        ),
                      ),
                      Expanded(
                        child: _buildNavItem(
                          icon: Icons.settings_rounded,
                          label: 'Settings',
                          iconSize: metrics.iconSize,
                          itemSize: metrics.itemSize,
                          labelFontSize: metrics.labelFontSize,
                          labelSpacing: metrics.labelSpacing,
                          onTap: () => _navigateToTab(3),
                        ),
                      ),
                      Expanded(
                        child: _buildNavItem(
                          icon: Icons.person_rounded,
                          label: 'Profile',
                          iconSize: metrics.iconSize,
                          itemSize: metrics.itemSize,
                          labelFontSize: metrics.labelFontSize,
                          labelSpacing: metrics.labelSpacing,
                          onTap: () => _navigateToTab(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _OfferBottomBarMetrics _getBottomBarMetrics() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScaler = MediaQuery.textScalerOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final horizontalPadding = _adaptiveValue(
      width: screenWidth,
      compact: 8,
      regular: 12,
      expanded: 18,
    );
    final verticalPadding = _adaptiveValue(
      width: screenWidth,
      compact: 6,
      regular: 8,
      expanded: 10,
    );
    final itemExtent = (screenWidth - (horizontalPadding * 2)) / 5;
    final isCompact = itemExtent < 72;
    final isExpanded = itemExtent > 90;
    final iconSize = isCompact ? 18.0 : (isExpanded ? 22.0 : 20.0);
    final itemSize = isCompact ? 34.0 : (isExpanded ? 42.0 : 38.0);
    final centerItemSize = isCompact ? 40.0 : (isExpanded ? 48.0 : 44.0);
    final labelFontSize = isCompact ? 9.0 : 10.0;
    final labelSpacing = isCompact ? 3.0 : 4.0;
    final minHeight = isCompact ? 64.0 : (isExpanded ? 76.0 : 70.0);
    final scaledLabelHeight = textScaler.scale(labelFontSize) * 1.4;
    final tallestItem = math.max(itemSize, centerItemSize);
    final buffer = isCompact ? 8.0 : (isExpanded ? 16.0 : 12.0);
    final requiredContentHeight = tallestItem +
        labelSpacing +
        scaledLabelHeight +
        (verticalPadding * 2) +
        buffer;
    final contentHeight = math.max(minHeight, requiredContentHeight);

    return _OfferBottomBarMetrics(
      horizontalPadding: horizontalPadding,
      verticalPadding: verticalPadding,
      iconSize: iconSize,
      itemSize: itemSize,
      centerItemSize: centerItemSize,
      labelFontSize: labelFontSize,
      labelSpacing: labelSpacing,
      contentHeight: contentHeight,
      totalHeight: contentHeight + bottomInset,
    );
  }

  double _adaptiveValue({
    required double width,
    required double compact,
    required double regular,
    required double expanded,
  }) {
    if (width < 360) {
      return compact;
    }
    if (width > 520) {
      return expanded;
    }
    return regular;
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required double iconSize,
    required double itemSize,
    required double labelFontSize,
    required double labelSpacing,
    bool isSelected = false,
    bool isCenter = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: itemSize,
            height: itemSize,
            decoration: isCenter
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFF8C50),
                        Color(0xFFFE6A1C),
                        Color(0xFFD4510E),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFE6A1C).withValues(alpha: 0.45),
                        blurRadius: 14,
                        spreadRadius: -2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  )
                : BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFFFE6A1C).withValues(alpha: 0.12)
                        : Colors.transparent,
                  ),
            child: Icon(
              icon,
              size: iconSize,
              color: isCenter
                  ? Colors.white
                  : (isSelected
                      ? const Color(0xFFFE6A1C)
                      : const Color(0xFF9A9A9A)),
            ),
          ),
          SizedBox(height: labelSpacing),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: labelFontSize,
                  height: 1,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected
                      ? const Color(0xFFFE6A1C)
                      : const Color(0xFF9A9A9A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  dynamic _firstValue(List<String> keys) {
    final map = _offerData ?? const <String, dynamic>{};

    for (final key in keys) {
      final value = map[key];
      if (value != null) {
        return value;
      }
    }

    final nestedMapCandidates = [map['data'], map['result'], map['offer']];
    for (final candidate in nestedMapCandidates) {
      if (candidate is Map) {
        final nested = Map<String, dynamic>.from(candidate);
        for (final key in keys) {
          final value = nested[key];
          if (value != null) {
            return value;
          }
        }
      }
    }

    final place = map['place'];
    if (place is Map) {
      final nestedPlace = Map<String, dynamic>.from(place);
      for (final key in keys) {
        final value = nestedPlace[key];
        if (value != null) {
          return value;
        }
      }
    }

    return null;
  }

  String _firstString(List<String> keys, {String fallback = ''}) {
    final value = _firstValue(keys);
    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _discountLabel() {
    final raw = _firstString(
      const ['discount', 'badge', 'discountPercentage', 'discountRate'],
      fallback: '10',
    );

    if (raw.isEmpty) {
      return '10% Off';
    }

    if (RegExp(r'off', caseSensitive: false).hasMatch(raw)) {
      return raw;
    }

    if (raw.contains('%')) {
      return '$raw Off';
    }

    final number = num.tryParse(raw);
    if (number != null) {
      final value =
          number % 1 == 1 ? number.toInt().toString() : number.toString();
      return '$value% Off';
    }

    return raw;
  }

  List<String> _extractTerms() {
    final termsValue = _firstValue(const [
      'terms',
      'termsAndConditions',
      'conditions',
    ]);

    if (termsValue is List) {
      return termsValue
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (termsValue is String) {
      return termsValue
          .split(RegExp(r'[\n\r]+'))
          .map((item) => item.trim().replaceFirst(RegExp(r'^[-\s]+'), ''))
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (termsValue is Map) {
      final items = termsValue['items'];
      if (items is List) {
        return items
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    }

    return const [
      'Offer valid once per user',
      'Dine-in or online order',
      'Cannot be combined with other promotional offers',
    ];
  }

  String _formatDate(dynamic date) {
    if (date == null) {
      return '30 Jan 2026';
    }

    if (date is DateTime) {
      return _formatDateValue(date);
    }

    if (date is int) {
      final parsed = DateTime.fromMillisecondsSinceEpoch(date);
      return _formatDateValue(parsed);
    }

    final text = date.toString().trim();
    if (text.isEmpty) {
      return '30 Jan 2026';
    }

    final parsed = DateTime.tryParse(text);
    if (parsed == null) {
      return text;
    }

    return _formatDateValue(parsed);
  }

  String _formatDateValue(DateTime dateTime) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
  }
}

class _OfferBottomBarMetrics {
  final double horizontalPadding;
  final double verticalPadding;
  final double iconSize;
  final double itemSize;
  final double centerItemSize;
  final double labelFontSize;
  final double labelSpacing;
  final double contentHeight;
  final double totalHeight;

  const _OfferBottomBarMetrics({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.iconSize,
    required this.itemSize,
    required this.centerItemSize,
    required this.labelFontSize,
    required this.labelSpacing,
    required this.contentHeight,
    required this.totalHeight,
  });
}
