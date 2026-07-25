import 'package:flutter/material.dart';

import '../../../app_router.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/storage/user_session_manager.dart';
import '../../../core/widgets/app_theme.dart';
import '../../../core/widgets/themed_top_header.dart';
import '../../../data/user_app/datasources/interests_remote_data_source.dart';
import '../../../data/user_app/datasources/auth_remote_data_source.dart';
import '../../../data/user_app/models/user_model.dart';
import '../../../injection_container.dart';

class YourInterestsPage extends StatefulWidget {
  const YourInterestsPage({super.key});

  @override
  State<YourInterestsPage> createState() => _YourInterestsPageState();
}

class _YourInterestsPageState extends State<YourInterestsPage> {
  final List<String> _locations = const [
    'Mansoura, Egypt',
    'Cairo, Egypt',
    'Alexandria, Egypt',
    'Giza, Egypt',
    'Aswan, Egypt',
  ];

  late final UserSessionManager _sessionManager;
  late final InterestsRemoteDataSource _interestsDataSource;

  List<_InterestCategory> _categories = const [];
  final Set<String> _selectedCategoryIds = <String>{};
  final Set<String> _selectedSubInterestIds = <String>{};

  bool _isLoading = true;
  bool _isSaving = false;
  String _userId = '';
  String? _activeCategoryId;
  String _selectedLocation = 'Mansoura, Egypt';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _needsName = false;
  bool _needsEmail = false;

  @override
  void initState() {
    super.initState();
    _sessionManager = sl<UserSessionManager>();
    _interestsDataSource = sl<InterestsRemoteDataSource>();
    _userId = _sessionManager.getUser()?.id ?? '';
    _loadInterests();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadInterests() async {
    final user = _sessionManager.getUser();
    if (user != null) {
      _needsName = user.name.trim().isEmpty;
      _needsEmail = user.email.trim().isEmpty;
      _nameController.text = user.name;
      _emailController.text = user.email;
    }

    final savedPreferences =
        _sessionManager.getInterestPreferences(userId: _userId) ?? const {};
    final savedCategoryIds =
        _readStringList(savedPreferences['selectedCategoryIds']).toSet();
    final savedSubInterestIds =
        _readStringList(savedPreferences['selectedSubInterestIds']).toSet();
    final savedLocation =
        (savedPreferences['location'] as String?)?.trim() ?? '';
    final fallbackLocation = user?.city.trim() ?? '';

    try {
      final rawInterests = await _interestsDataSource.getInterests();
      final categories = _buildCategories(
        rawInterests.isEmpty ? _defaultInterestMaps() : rawInterests,
      );

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _selectedCategoryIds
          ..clear()
          ..addAll(
            savedCategoryIds.where(
              (id) => categories.any((category) => category.id == id),
            ),
          );
        _selectedSubInterestIds
          ..clear()
          ..addAll(
            savedSubInterestIds.where(
              (id) => categories.any(
                (category) =>
                    category.subInterests.any((item) => item.id == id),
              ),
            ),
          );
        _selectedLocation = _resolveLocation(savedLocation, fallbackLocation);
        _activeCategoryId = _selectedCategoryIds.isNotEmpty
            ? _selectedCategoryIds.first
            : (categories.isNotEmpty ? categories.first.id : null);
        _isLoading = false;
      });
    } catch (_) {
      final categories = _buildCategories(_defaultInterestMaps());
      if (!mounted) return;

      setState(() {
        _categories = categories;
        _selectedCategoryIds
          ..clear()
          ..addAll(
            savedCategoryIds.where(
              (id) => categories.any((category) => category.id == id),
            ),
          );
        _selectedSubInterestIds
          ..clear()
          ..addAll(
            savedSubInterestIds.where(
              (id) => categories.any(
                (category) =>
                    category.subInterests.any((item) => item.id == id),
              ),
            ),
          );
        _selectedLocation = _resolveLocation(savedLocation, fallbackLocation);
        _activeCategoryId = _selectedCategoryIds.isNotEmpty
            ? _selectedCategoryIds.first
            : (categories.isNotEmpty ? categories.first.id : null);
        _isLoading = false;
      });
    }
  }

  List<_InterestCategory> _buildCategories(
      List<Map<String, dynamic>> rawItems) {
    final categories = <_InterestCategory>[];

    for (final item in rawItems) {
      final id = (item['id'] ?? '').toString().trim();
      final label = (item['name'] ?? item['label'] ?? '').toString().trim();
      if (id.isEmpty || label.isEmpty) {
        continue;
      }

      categories.add(
        _InterestCategory(
          id: id,
          label: label,
          icon: _iconForCategory(label),
          subInterests: _subInterestsForCategory(id, label),
        ),
      );
    }

    return categories;
  }

  List<Map<String, String>> _defaultInterestMaps() {
    return const [
      {'id': 'cafe', 'name': 'Cafes'},
      {'id': 'event', 'name': 'Events'},
      {'id': 'offer', 'name': 'Offers'},
      {'id': 'party', 'name': 'Parties'},
      {'id': 'restaurant', 'name': 'Restaurant'},
      {'id': 'art', 'name': 'Art'},
      {'id': 'sports', 'name': 'Sports'},
    ];
  }

  IconData _iconForCategory(String label) {
    final text = label.toLowerCase();
    if (text.contains('cafe') || text.contains('coffee')) {
      return Icons.coffee_outlined;
    }
    if (text.contains('event')) {
      return Icons.event_outlined;
    }
    if (text.contains('offer')) {
      return Icons.local_offer_outlined;
    }
    if (text.contains('part')) {
      return Icons.celebration_outlined;
    }
    if (text.contains('restaurant') || text.contains('food')) {
      return Icons.restaurant_outlined;
    }
    if (text.contains('art')) {
      return Icons.palette_outlined;
    }
    if (text.contains('sport')) {
      return Icons.sports_soccer_outlined;
    }
    return Icons.category_outlined;
  }

  List<_SubInterest> _subInterestsForCategory(String categoryId, String label) {
    final normalized = '${categoryId.toLowerCase()} ${label.toLowerCase()}';

    if (normalized.contains('cafe') || normalized.contains('coffee')) {
      return _buildSubInterests(
        categoryId,
        const [
          ('Coffee', Icons.local_cafe_outlined),
          ('Tea', Icons.emoji_food_beverage_outlined),
          ('Desserts', Icons.cake_outlined),
          ('Work Space', Icons.chair_alt_outlined),
        ],
      );
    }

    if (normalized.contains('event')) {
      return _buildSubInterests(
        categoryId,
        const [
          ('Concerts', Icons.music_note_outlined),
          ('Workshops', Icons.lightbulb_outline),
          ('Festivals', Icons.festival_outlined),
          ('Networking', Icons.groups_outlined),
        ],
      );
    }

    if (normalized.contains('offer')) {
      return _buildSubInterests(
        categoryId,
        const [
          ('Dining Deals', Icons.restaurant_menu_outlined),
          ('Coffee Deals', Icons.coffee_outlined),
          ('Tickets', Icons.confirmation_number_outlined),
          ('Shopping', Icons.shopping_bag_outlined),
        ],
      );
    }

    if (normalized.contains('part')) {
      return _buildSubInterests(
        categoryId,
        const [
          ('Night Parties', Icons.nightlife_outlined),
          ('Birthday', Icons.cake_outlined),
          ('Beach', Icons.beach_access_outlined),
          ('Private Events', Icons.celebration_outlined),
        ],
      );
    }

    if (normalized.contains('restaurant') || normalized.contains('food')) {
      return _buildSubInterests(
        categoryId,
        const [
          ('Fast Food', Icons.lunch_dining_outlined),
          ('Family Dining', Icons.family_restroom_outlined),
          ('Seafood', Icons.set_meal_outlined),
          ('Fine Dining', Icons.dinner_dining_outlined),
        ],
      );
    }

    if (normalized.contains('art')) {
      return _buildSubInterests(
        categoryId,
        const [
          ('Painting', Icons.brush_outlined),
          ('Crafts', Icons.handyman_outlined),
          ('Galleries', Icons.image_outlined),
          ('Photography', Icons.camera_alt_outlined),
        ],
      );
    }

    if (normalized.contains('sport')) {
      return _buildSubInterests(
        categoryId,
        const [
          ('Football', Icons.sports_soccer_outlined),
          ('Gym', Icons.fitness_center_outlined),
          ('Running', Icons.directions_run_outlined),
          ('Padel', Icons.sports_tennis_outlined),
        ],
      );
    }

    return _buildSubInterests(
      categoryId,
      const [
        ('Trending', Icons.trending_up_outlined),
        ('Popular', Icons.auto_awesome_outlined),
        ('Nearby', Icons.location_on_outlined),
        ('Recommended', Icons.thumb_up_alt_outlined),
      ],
    );
  }

  List<_SubInterest> _buildSubInterests(
    String categoryId,
    List<(String, IconData)> options,
  ) {
    return options
        .map(
          (item) => _SubInterest(
            id: '$categoryId:${_slugify(item.$1)}',
            label: item.$1,
            icon: item.$2,
          ),
        )
        .toList();
  }

  String _resolveLocation(String savedLocation, String fallbackLocation) {
    for (final loc in _locations) {
      if (savedLocation.toLowerCase().contains(loc.split(',').first.toLowerCase().trim())) {
        return loc;
      }
    }
    for (final loc in _locations) {
      if (fallbackLocation.toLowerCase().contains(loc.split(',').first.toLowerCase().trim())) {
        return loc;
      }
    }
    return _locations.first;
  }

  void _onCategoryTap(_InterestCategory category) {
    setState(() {
      final isSelected = _selectedCategoryIds.contains(category.id);
      final isActive = _activeCategoryId == category.id;

      if (isSelected && isActive) {
        _selectedCategoryIds.remove(category.id);
        _selectedSubInterestIds.removeWhere(
          (id) => category.subInterests.any((item) => item.id == id),
        );

        if (_selectedCategoryIds.isNotEmpty) {
          _activeCategoryId = _selectedCategoryIds.first;
        } else {
          _activeCategoryId =
              _categories.isNotEmpty ? _categories.first.id : null;
        }
        return;
      }

      _selectedCategoryIds.add(category.id);
      _activeCategoryId = category.id;
    });
  }

  void _onSubInterestTap(_InterestCategory category, _SubInterest subInterest) {
    setState(() {
      _selectedCategoryIds.add(category.id);
      _activeCategoryId = category.id;

      if (_selectedSubInterestIds.contains(subInterest.id)) {
        _selectedSubInterestIds.remove(subInterest.id);
      } else {
        _selectedSubInterestIds.add(subInterest.id);
      }
    });
  }

  Future<void> _onContinue() async {
    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose at least one interest.')),
      );
      return;
    }

    if (_needsName && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    if (_needsEmail && _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentUser = _sessionManager.getUser() ?? UserModel.empty;
      final updatedUser = currentUser.copyWith(
        name: _needsName ? _nameController.text.trim() : currentUser.name,
        email: _needsEmail ? _emailController.text.trim() : currentUser.email,
        city: _selectedLocation,
      );

      await _sessionManager.saveUser(updatedUser);

      final authDataSource = sl<AuthRemoteDataSource>();
      try {
        if (_needsName || _needsEmail) {
          await authDataSource.updateUserProfile(
            fullName: updatedUser.name,
            email: updatedUser.email,
            city: updatedUser.city,
          );
        } else {
          await authDataSource.updateProfile(city: updatedUser.city);
        }
      } catch (_) {}

      try {
        final refreshedProfile = await authDataSource.fetchUserProfile();
        await _sessionManager.saveAuthSession(refreshedProfile);
      } catch (_) {}
    } catch (_) {}

    final selectedCategories = _categories
        .where((category) => _selectedCategoryIds.contains(category.id))
        .toList();
    final selectedSubInterests = selectedCategories
        .expand((category) => category.subInterests)
        .where((item) => _selectedSubInterestIds.contains(item.id))
        .toList();

    try {
      await _interestsDataSource.saveInterests(
        selectedIds: selectedCategories.map((category) => category.id).toList(),
        customInterests: selectedSubInterests
            .map((item) => item.label)
            .toList(growable: false),
      );
    } catch (_) {
      // Keep onboarding moving even if backend syncing fails for now.
    }

    await _sessionManager.saveInterestPreferences(
      userId: _userId,
      selectedCategoryIds:
          selectedCategories.map((category) => category.id).toList(),
      selectedCategoryLabels:
          selectedCategories.map((category) => category.label).toList(),
      selectedSubInterestIds:
          selectedSubInterests.map((item) => item.id).toList(),
      selectedSubInterestLabels:
          selectedSubInterests.map((item) => item.label).toList(),
      location: _selectedLocation,
    );

    if (!mounted) return;

    setState(() => _isSaving = false);
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
    );
  }

  void _skip() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
    );
  }

  List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  String _slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          ThemedTopHeader(
            title: 'Your Interests',
            showBackButton: true,
            onBackPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFE5D17),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 32 : 16,
                      16,
                      isTablet ? 32 : 16,
                      28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildIntroCard(),
                        const SizedBox(height: 16),
                        _buildCategoryChips(isTablet),
                        const SizedBox(height: 16),
                        _buildActiveCategoryCard(isTablet),
                        const SizedBox(height: 20),
                        _buildProfileAndLocationCard(),
                        const SizedBox(height: 24),
                        _buildContinueButton(isTablet),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose Your Interests',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Select the categories you love so the app can recommend the best places for you later.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF6E6E6E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: _skip,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6E6E6E),
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Skip',
              style: TextStyle(
                fontSize: 14,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(bool isTablet) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categories.map((category) {
        final isSelected = _selectedCategoryIds.contains(category.id);
        return InkWell(
          onTap: () => _onCategoryTap(category),
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: isTablet ? 12 : 9,
            ),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFE5D17) : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFFFE5D17),
                width: 1.2,
              ),
              boxShadow: isSelected
                  ? const [
                      BoxShadow(
                        color: Color(0x22FE5D17),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  category.icon,
                  size: 16,
                  color: isSelected ? Colors.white : const Color(0xFFFE5D17),
                ),
                const SizedBox(width: 6),
                Text(
                  category.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFFFE5D17),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActiveCategoryCard(bool isTablet) {
    final activeCategory = _categories.cast<_InterestCategory?>().firstWhere(
          (category) => category?.id == _activeCategoryId,
          orElse: () => _categories.isNotEmpty ? _categories.first : null,
        );

    if (activeCategory == null) {
      return const SizedBox.shrink();
    }

    final isSelected = _selectedCategoryIds.contains(activeCategory.id);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isSelected ? 1 : 0.65,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                isSelected ? const Color(0xFFFE5D17) : const Color(0xFFE7E1DC),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEFE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    activeCategory.icon,
                    color: const Color(0xFFFE5D17),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeCategory.label,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Choose what you love the most',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF777777),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF1C1C1C),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: activeCategory.subInterests.map((subInterest) {
                final isPicked =
                    _selectedSubInterestIds.contains(subInterest.id);
                return InkWell(
                  onTap: () => _onSubInterestTap(activeCategory, subInterest),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: isTablet ? 170 : 132,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isPicked
                          ? const Color(0xFFFFE8DC)
                          : const Color(0xFFFDFDFD),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isPicked
                            ? const Color(0xFFFE5D17)
                            : const Color(0xFFE7E1DC),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              subInterest.icon,
                              size: 18,
                              color: const Color(0xFFFE5D17),
                            ),
                            const Spacer(),
                            Icon(
                              isPicked
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: isPicked
                                  ? const Color(0xFFFE5D17)
                                  : const Color(0xFFB9B2AC),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          subInterest.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF202020),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFE5D17),
          width: 1.2,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLocation,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          borderRadius: BorderRadius.circular(18),
          items: _locations.map((location) {
            return DropdownMenuItem<String>(
              value: location,
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFFFE5D17),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    location,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1C1C1C),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedLocation = value);
          },
        ),
      ),
    );
  }

  Widget _buildProfileAndLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile & Location',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Please fill in your details and choose your location to proceed.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: Color(0xFF6E6E6E),
            ),
          ),
          const SizedBox(height: 16),
          if (_needsName) ...[
            const Text(
              'Full Name',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1C),
              ),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _nameController,
              hint: 'Enter your name',
            ),
            const SizedBox(height: 16),
          ],
          if (_needsEmail) ...[
            const Text(
              'Email Address',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1C),
              ),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _emailController,
              hint: 'Enter your email',
            ),
            const SizedBox(height: 16),
          ],
          const Text(
            'Your Location',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1C),
            ),
          ),
          const SizedBox(height: 8),
          _buildLocationSelector(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 14,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: AppTheme.primary,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildContinueButton(bool isTablet) {
    return CustomButton(
      text: 'Continue',
      isLoading: _isSaving,
      onPressed: _onContinue,
      height: isTablet ? 62 : 58,
    );
  }
}

class _InterestCategory {
  final String id;
  final String label;
  final IconData icon;
  final List<_SubInterest> subInterests;

  const _InterestCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.subInterests,
  });
}

class _SubInterest {
  final String id;
  final String label;
  final IconData icon;

  const _SubInterest({
    required this.id,
    required this.label,
    required this.icon,
  });
}
