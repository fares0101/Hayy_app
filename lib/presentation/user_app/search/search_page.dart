import 'dart:async';

import 'package:flutter/material.dart';
import 'package:redacted/redacted.dart';
import '../../../core/storage/user_session_manager.dart';
import '../../../data/user_app/datasources/places_remote_data_source.dart';
import '../../../data/user_app/datasources/interests_remote_data_source.dart';
import '../../../injection_container.dart';
import '../../../core/widgets/custom_button.dart';
import '../discovery/discovery_list_page.dart';

class SearchPage extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const SearchPage({super.key, this.onBackPressed});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final UserSessionManager _sessionManager;
  late final PlacesRemoteDataSource _dataSource;
  late final InterestsRemoteDataSource _interestsDataSource;
  Timer? _searchDebounce;
  Timer? _recentSearchDebounce;
  int _activeSearchRequestId = 0;
  String _userId = '';

  bool _isLoading = false;
  String? _errorMessage;
  List<DiscoveryListItem> _searchResults = [];
  bool _hasSearched = false;

  List<String> _recentSearches = [];

  List<Map<String, dynamic>> _suggestions = [
    {
      'text': 'Restaurants',
      'query': 'Restaurant',
      'icon': Icons.restaurant_rounded,
      'iconBg': const Color(0xFFFF641A),
      'iconColor': Colors.white,
    },
    {
      'text': 'Cafés & Coffee',
      'query': 'Cafe',
      'icon': Icons.local_cafe_rounded,
      'iconBg': const Color(0xFFFFF0E8),
      'iconColor': const Color(0xFFFE5D17),
    },
    {
      'text': 'Events & Shows',
      'query': 'Event',
      'icon': Icons.event_note_rounded,
      'iconBg': const Color(0xFFEDE8F7),
      'iconColor': const Color(0xFF6B3FA0),
    },
    {
      'text': 'Workspaces',
      'query': 'Work',
      'icon': Icons.work_outline_rounded,
      'iconBg': const Color(0xFFE2F0E8),
      'iconColor': const Color(0xFF2E7D50),
    },
    {
      'text': 'Offers & Deals',
      'query': 'Offer',
      'icon': Icons.local_offer_rounded,
      'iconBg': const Color(0xFFFFF3E0),
      'iconColor': const Color(0xFFE65100),
    },
  ];

  final List<Map<String, dynamic>> _defaultSuggestions = [
    {
      'text': 'Restaurants',
      'query': 'Restaurant',
      'icon': Icons.restaurant_rounded,
      'iconBg': const Color(0xFFFF641A),
      'iconColor': Colors.white,
    },
    {
      'text': 'Cafés & Coffee',
      'query': 'Cafe',
      'icon': Icons.local_cafe_rounded,
      'iconBg': const Color(0xFFFFF0E8),
      'iconColor': const Color(0xFFFE5D17),
    },
    {
      'text': 'Events & Shows',
      'query': 'Event',
      'icon': Icons.event_note_rounded,
      'iconBg': const Color(0xFFEDE8F7),
      'iconColor': const Color(0xFF6B3FA0),
    },
    {
      'text': 'Workspaces',
      'query': 'Work',
      'icon': Icons.work_outline_rounded,
      'iconBg': const Color(0xFFE2F0E8),
      'iconColor': const Color(0xFF2E7D50),
    },
    {
      'text': 'Offers & Deals',
      'query': 'Offer',
      'icon': Icons.local_offer_rounded,
      'iconBg': const Color(0xFFFFF3E0),
      'iconColor': const Color(0xFFE65100),
    },
  ];

  @override
  void initState() {
    super.initState();
    _sessionManager = sl<UserSessionManager>();
    _dataSource = sl<PlacesRemoteDataSource>();
    _interestsDataSource = sl<InterestsRemoteDataSource>();
    _userId = _sessionManager.getUser()?.id ?? '';
    _loadRecentSearches();
    _loadCategorySuggestions();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _loadRecentSearches() async {
    final searches = _sessionManager.getRecentSearches(userId: _userId);
    if (!mounted) return;
    setState(() => _recentSearches = searches);
  }

  Future<void> _loadCategorySuggestions() async {
    try {
      final categories = await _interestsDataSource.getInterests();
      if (!mounted || categories.isEmpty) return;

      final List<Map<String, dynamic>> fetchedSuggestions = [];
      final List<Color> bgColors = [
        const Color(0xFFFF641A),
        const Color(0xFFEDE8F7),
        const Color(0xFFE2F0E8),
        const Color(0xFFFFF0E8),
        const Color(0xFFFFF3E0),
      ];
      final List<Color> iconColors = [
        Colors.white,
        const Color(0xFF6B3FA0),
        const Color(0xFF2E7D50),
        const Color(0xFFFE5D17),
        const Color(0xFFE65100),
      ];
      final List<IconData> icons = [
        Icons.restaurant_rounded,
        Icons.local_cafe_rounded,
        Icons.event_note_rounded,
        Icons.work_outline_rounded,
        Icons.local_offer_rounded,
        Icons.place_rounded,
      ];

      for (int i = 0; i < categories.length; i++) {
        final cat = categories[i];
        final name = cat['name']?.toString() ?? '';
        if (name.trim().isEmpty) continue;

        fetchedSuggestions.add({
          'text': name,
          'query': name,
          'icon': icons[i % icons.length],
          'iconBg': bgColors[i % bgColors.length],
          'iconColor': iconColors[i % iconColors.length],
        });
      }

      if (fetchedSuggestions.isNotEmpty) {
        setState(() {
          final existingNames = fetchedSuggestions
              .map((s) => s['text'].toString().toLowerCase())
              .toSet();
          for (final d in _defaultSuggestions) {
            if (!existingNames.contains(d['text'].toString().toLowerCase())) {
              fetchedSuggestions.add(d);
            }
          }
          _suggestions = fetchedSuggestions;
        });
      }
    } catch (_) {
      // Keep default static suggestions if fetch fails
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _recentSearchDebounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _removeRecent(String query) async {
    await _sessionManager.removeRecentSearch(query, userId: _userId);
    if (!mounted) return;
    setState(() {
      _recentSearches.removeWhere(
        (item) => item.toLowerCase() == query.trim().toLowerCase(),
      );
    });
  }

  void _onQueryChanged(String value) {
    _searchDebounce?.cancel();
    _recentSearchDebounce?.cancel();

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _activeSearchRequestId++;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _searchResults.clear();
        _hasSearched = false;
      });
      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _performSearch(trimmed),
    );

    _recentSearchDebounce = Timer(
      const Duration(milliseconds: 1200),
      () => _saveRecentSearch(trimmed),
    );
  }

  Future<void> _saveRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return;
    }

    await _sessionManager.saveRecentSearch(trimmed, userId: _userId);
    if (!mounted) return;
    setState(() {
      _recentSearches = _sessionManager.getRecentSearches(userId: _userId);
    });
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final requestId = ++_activeSearchRequestId;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    try {
      List<dynamic> rawItems = [];

      // 1. Try smartSearch first
      try {
        rawItems = await _dataSource.smartSearch(
          userId: _userId,
          searchTerm: trimmed,
        );
      } catch (_) {}

      // 2. Fallback to searchPlaces if smartSearch yielded no items
      if (rawItems.isEmpty) {
        try {
          rawItems = await _dataSource.searchPlaces(trimmed);
        } catch (_) {}
      }

      // 3. Fallback to local filtering on getPlaces if still empty
      if (rawItems.isEmpty) {
        try {
          final allPlaces = await _dataSource.getPlaces();
          final q = trimmed.toLowerCase();
          rawItems = allPlaces.where((p) {
            if (p is! Map) return false;
            final map = Map<String, dynamic>.from(p);
            final name = map['name']?.toString().toLowerCase() ?? '';
            final category = map['categoryName']?.toString().toLowerCase() ?? '';
            final type = map['type']?.toString().toLowerCase() ?? '';
            final desc = map['description']?.toString().toLowerCase() ?? '';
            return name.contains(q) ||
                category.contains(q) ||
                type.contains(q) ||
                desc.contains(q);
          }).toList();
        } catch (_) {}
      }

      if (!mounted || requestId != _activeSearchRequestId) return;

      final items = rawItems.map((item) {
        final map =
            item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
        return DiscoveryDataMapper.fromPlace(map);
      }).toList();

      setState(() {
        _searchResults = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _activeSearchRequestId) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to fetch search results. Please try again.';
      });
    }
  }

  Future<void> _applySearchTerm(String query, {String? displayLabel}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final label = (displayLabel ?? query).trim();

    _searchDebounce?.cancel();
    _recentSearchDebounce?.cancel();
    _controller.value = TextEditingValue(
      text: label,
      selection: TextSelection.collapsed(offset: label.length),
    );
    await _saveRecentSearch(label);
    await _performSearch(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F9),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── AppBar ──────────────────────────────────────────────────────
            _buildSearchBar(),

            const SizedBox(height: 4),

            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          return DiscoveryCard(
            item: const DiscoveryListItem(
              id: 'dummy',
              title: 'Loading Data...',
              subtitle: 'Category Name',
              detailLine: 'Loading detail line',
              accentText: 'Loading description text here',
              footerLinkLabel: 'Loading link',
              imageUrl: 'https://via.placeholder.com/150',
              actionLabel: 'View',
            ),
            pageKind: DiscoveryPageKind.place,
            onPrimaryAction: () {},
            onSecondaryAction: () {},
          ).redacted(
            context: context,
            redact: true,
            configuration: RedactedConfiguration(
              animationDuration: const Duration(milliseconds: 800),
            ),
          );
        },
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            CustomButton(
              onPressed: () => _performSearch(_controller.text),
              text: 'Retry',
              width: 150,
            ),
          ],
        ),
      );
    }

    if (_hasSearched) {
      if (_searchResults.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No results found',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final item = _searchResults[index];
          return DiscoveryCard(
            item: item,
            pageKind: DiscoveryPageKind.place,
            onPrimaryAction: () {
              unawaited(_saveRecentSearch(_controller.text));
              if (item.actionRoute != null) {
                Navigator.pushNamed(
                  context,
                  item.actionRoute!,
                  arguments: item.actionArguments ?? item.id,
                );
              }
            },
            onSecondaryAction: () {
              if (item.actionRoute != null) {
                Navigator.pushNamed(
                  context,
                  item.actionRoute!,
                  arguments: item.actionArguments ?? item.id,
                );
              }
            },
          );
        },
      );
    }

    // Default suggestions view
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          if (_recentSearches.isNotEmpty) ...[
            _sectionTitle('Recent Searches'),
            const SizedBox(height: 8),
            _buildRecentSearches(),
            const SizedBox(height: 22),
          ],
          _sectionTitle('Suggestions'),
          const SizedBox(height: 8),
          _buildSuggestions(),
        ],
      ),
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Back arrow
          GestureDetector(
            onTap: widget.onBackPressed,
            child: const SizedBox(
              width: 38,
              height: 38,
              child: Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Search field
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'Search for place, events...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: _applySearchTerm,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section title ──────────────────────────────────────────────────────────
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A1A),
        ),
      ),
    );
  }

  // ── Recent Searches list ───────────────────────────────────────────────────
  Widget _buildRecentSearches() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: List.generate(_recentSearches.length, (i) {
          return Column(
            children: [
              InkWell(
                onTap: () => _applySearchTerm(_recentSearches[i]),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _recentSearches[i],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2A2A2A),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _removeRecent(_recentSearches[i]),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (i < _recentSearches.length - 1)
                Divider(
                  height: 1,
                  color: Colors.grey.shade100,
                  indent: 44,
                ),
            ],
          );
        }),
      ),
    );
  }

  // ── Suggestions list ───────────────────────────────────────────────────────
  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: List.generate(_suggestions.length, (i) {
          final s = _suggestions[i];
          return Column(
            children: [
              InkWell(
                borderRadius: i == 0
                    ? const BorderRadius.vertical(top: Radius.circular(14))
                    : i == _suggestions.length - 1
                        ? const BorderRadius.vertical(
                            bottom: Radius.circular(14))
                        : BorderRadius.zero,
                onTap: () => _applySearchTerm(
                  (s['query'] ?? s['text']) as String,
                  displayLabel: s['text'] as String,
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: s['iconBg'] as Color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          s['icon'] as IconData,
                          size: 18,
                          color: s['iconColor'] as Color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s['text'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            color: i == 0
                                ? const Color(0xFFFF641A)
                                : const Color(0xFF2A2A2A),
                            fontWeight:
                                i == 0 ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (i < _suggestions.length - 1)
                Divider(
                  height: 1,
                  color: Colors.grey.shade100,
                  indent: 62,
                ),
            ],
          );
        }),
      ),
    );
  }
}
