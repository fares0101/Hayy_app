import 'package:flutter/material.dart';
import '../../../core/widgets/app_theme.dart';
import '../../../core/widgets/themed_top_header.dart';

class TermsAndPoliciesPage extends StatefulWidget {
  const TermsAndPoliciesPage({super.key});

  @override
  State<TermsAndPoliciesPage> createState() => _TermsAndPoliciesPageState();
}

class _TermsAndPoliciesPageState extends State<TermsAndPoliciesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          ThemedTopHeader(
            title: 'Terms & Policies',
            showBackButton: true,
            onBackPressed: () => Navigator.maybePop(context),
          ),
          // ── Tabs ───────────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFFF641A),
              labelColor: const Color(0xFFFF641A),
              unselectedLabelColor: const Color(0xFF666666),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: const [
                Tab(text: 'Terms of Service'),
                Tab(text: 'Privacy Policy'),
              ],
            ),
          ),
          // ── Tab contents ───────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTermsOfService(),
                _buildPrivacyPolicy(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsOfService() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLastUpdatedBadge('Last updated: June 2026'),
          const SizedBox(height: 16),
          _buildSectionTitle('1. Acceptance of Terms'),
          _buildSectionBody(
              'By accessing and using HAYY App, you agree to comply with and be bound by these Terms of Service. If you do not agree to these terms, please do not use the app.'),
          _buildSectionTitle('2. User Registration'),
          _buildSectionBody(
              'To access certain features of the App, including ticket bookings and adding reviews, you must register for an account. You agree to provide accurate, current, and complete information during registration.'),
          _buildSectionTitle('3. Booking and Payments'),
          _buildSectionBody(
              'All ticket bookings made through the App are subject to availability and acceptance by the event organizer. Payment must be made through our authorized payment gateways. All purchases are final and non-refundable unless specified otherwise by the organizer.'),
          _buildSectionTitle('4. User Conduct'),
          _buildSectionBody(
              'You agree not to post comments, reviews, or media that are illegal, offensive, defamatory, or violate the privacy of others. HAYY reserves the right to remove any content at our sole discretion.'),
          _buildSectionTitle('5. Limitation of Liability'),
          _buildSectionBody(
              'HAYY App is provided on an "as is" and "as available" basis. We do not warrant that the app will be uninterrupted or error-free. Under no circumstances shall HAYY be liable for any direct or indirect damages resulting from your use of the app.'),
        ],
      ),
    );
  }

  Widget _buildPrivacyPolicy() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLastUpdatedBadge('Last updated: June 2026'),
          const SizedBox(height: 16),
          _buildSectionTitle('1. Information We Collect'),
          _buildSectionBody(
              'We collect information you provide directly to us, such as your name, email address, profile image, phone number, and location data when you use the app to discover places.'),
          _buildSectionTitle('2. How We Use Your Information'),
          _buildSectionBody(
              'We use the information we collect to operate and improve the app, personalize your experience, process bookings, display your profile picture on comments/reviews, and send you push notifications or marketing communications if enabled in your settings.'),
          _buildSectionTitle('3. Sharing of Information'),
          _buildSectionBody(
              'We do not sell your personal data. We share information only with service providers (e.g., payment processors, database hosting services) and event organizers as required to fulfill bookings.'),
          _buildSectionTitle('4. Data Retention and Deletion'),
          _buildSectionBody(
              'We retain your personal data for as long as your account is active. You can request permanent deletion of your account and all associated data directly from your Profile settings page at any time.'),
          _buildSectionTitle('5. Security'),
          _buildSectionBody(
              'We take reasonable measures, including secure encryption and access controls, to protect your information from loss, theft, misuse, unauthorized access, and alteration.'),
        ],
      ),
    );
  }

  Widget _buildLastUpdatedBadge(String date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF641A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        date,
        style: const TextStyle(
          color: Color(0xFFFF641A),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF222222),
        ),
      ),
    );
  }

  Widget _buildSectionBody(String body) {
    return Text(
      body,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF555555),
        height: 1.45,
      ),
    );
  }
}
