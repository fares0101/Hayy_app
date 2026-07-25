import 'package:flutter/material.dart';
import '../../../core/widgets/app_theme.dart';
import '../../../core/widgets/themed_top_header.dart';
import 'chat_with_us_page.dart';
import 'contact_us_page.dart';
import 'report_problem_page.dart';

class HelpCenterPage extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const HelpCenterPage({super.key, this.onBackPressed});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedCategoryIndex = 0;
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'General',
    'Bookings',
    'Account',
    'Payments',
  ];

  final List<Map<String, String>> _faqs = [
    {
      'category': 'General',
      'question': 'What is HAYY app?',
      'answer':
          'HAYY is your all-in-one local guide to discover top places, exclusive offers, events, and book tickets seamlessly in your city.',
    },
    {
      'category': 'General',
      'question': 'How do I search for places or events?',
      'answer':
          'You can use the search icon on the top bar or explore places by categories on the Home and Discovery tabs.',
    },
    {
      'category': 'Bookings',
      'question': 'How can I view my booked event tickets?',
      'answer':
          'Go to your Profile tab and tap on "My Booking" or "My Tickets". You can view your QR codes and ticket details anytime.',
    },
    {
      'category': 'Bookings',
      'question': 'Can I cancel or modify a ticket booking?',
      'answer':
          'Cancellations depend on the event organizer\'s policy. Please contact support via live chat or email with your booking ID for assistance.',
    },
    {
      'category': 'Account',
      'question': 'How do I update my profile picture or name?',
      'answer':
          'Go to Profile -> Edit Profile. You can select a new picture from your gallery and update your personal info.',
    },
    {
      'category': 'Account',
      'question': 'How do I reset my password?',
      'answer':
          'Log out of your account, tap "Forgot Password?" on the login page, and enter your registered email to receive an OTP.',
    },
    {
      'category': 'Payments',
      'question': 'What payment methods are supported?',
      'answer':
          'We support credit/debit cards (Visa, MasterCard), Meeza cards, and digital wallets.',
    },
    {
      'category': 'Payments',
      'question': 'Is my payment information secure?',
      'answer':
          'Yes! All payments are processed through encrypted, bank-grade payment gateways.',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, String>> get _filteredFaqs {
    return _faqs.where((faq) {
      final matchesCategory = _selectedCategoryIndex == 0 ||
          faq['category'] == _categories[_selectedCategoryIndex];
      final matchesQuery = _searchQuery.isEmpty ||
          faq['question']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq['answer']!.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          ThemedTopHeader(
            title: 'Help Center',
            showBackButton: true,
            onBackPressed: widget.onBackPressed ?? () => Navigator.maybePop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Quick Action Cards ─────────────────────────────────────
                  _buildQuickActionCards(context),
                  const SizedBox(height: 22),

                  // ── Search bar ─────────────────────────────────────────────
                  _buildSearchBar(),
                  const SizedBox(height: 18),

                  // ── Category Pills ─────────────────────────────────────────
                  _buildCategoryTabs(),
                  const SizedBox(height: 18),

                  // ── Section Title ──────────────────────────────────────────
                  const Text(
                    'Frequently Asked Questions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── FAQ List ───────────────────────────────────────────────
                  _buildFaqList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCards(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickCard(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Live Chat',
            subtitle: 'Instant support',
            color: const Color(0xFFFF641A),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatWithUsPage()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickCard(
            icon: Icons.headset_mic_outlined,
            title: 'Contact Us',
            subtitle: 'Call or email',
            color: const Color(0xFF6B3FA0),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactUsPage()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickCard(
            icon: Icons.report_problem_outlined,
            title: 'Report',
            subtitle: 'File a issue',
            color: const Color(0xFF2E7D50),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportProblemPage()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
        decoration: InputDecoration(
          hintText: 'Search for answers...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFFF641A)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final isSelected = i == _selectedCategoryIndex;
          return ChoiceChip(
            label: Text(_categories[i]),
            selected: isSelected,
            onSelected: (_) => setState(() => _selectedCategoryIndex = i),
            selectedColor: const Color(0xFFFF641A),
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF555555),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                color: isSelected ? Colors.transparent : Colors.grey.shade200,
              ),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildFaqList() {
    final list = _filteredFaqs;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                'No FAQs found for "$_searchQuery"',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: list.map((faq) => _FaqTile(faq: faq)).toList(),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Depth3DCard(
        borderRadius: 16,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
}

class _FaqTile extends StatefulWidget {
  final Map<String, String> faq;

  const _FaqTile({required this.faq});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (exp) => setState(() => _isExpanded = exp),
          title: Text(
            widget.faq['question']!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _isExpanded ? const Color(0xFFFF641A) : const Color(0xFF222222),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                widget.faq['answer']!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF555555),
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
