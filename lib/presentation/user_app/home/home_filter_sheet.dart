import 'package:flutter/material.dart';
import '../../../core/widgets/custom_button.dart';

// ─── Filter State Model ────────────────────────────────────────────────────────
class HomeFilterState {
  final String category; // '', 'Restaurants', 'Cafes', 'Events', 'Offers'
  final String sortBy; // '', 'topRated', 'newest', 'mostPopular'
  final bool openNow;

  const HomeFilterState({
    this.category = '',
    this.sortBy = '',
    this.openNow = false,
  });

  HomeFilterState copyWith({String? category, String? sortBy, bool? openNow}) {
    return HomeFilterState(
      category: category ?? this.category,
      sortBy: sortBy ?? this.sortBy,
      openNow: openNow ?? this.openNow,
    );
  }

  HomeFilterState reset() => const HomeFilterState();

  bool get hasActiveFilters =>
      category.isNotEmpty || sortBy.isNotEmpty || openNow;

  int get activeCount =>
      (category.isNotEmpty ? 1 : 0) +
      (sortBy.isNotEmpty ? 1 : 0) +
      (openNow ? 1 : 0);
}

// ─── Filter Bottom Sheet ───────────────────────────────────────────────────────
class HomeFilterSheet extends StatefulWidget {
  final HomeFilterState current;

  const HomeFilterSheet({super.key, required this.current});

  static Future<HomeFilterState?> show(
    BuildContext context, {
    required HomeFilterState current,
  }) {
    return showModalBottomSheet<HomeFilterState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HomeFilterSheet(current: current),
    );
  }

  @override
  State<HomeFilterSheet> createState() => _HomeFilterSheetState();
}

class _HomeFilterSheetState extends State<HomeFilterSheet> {
  late HomeFilterState _draft;

  static const _categories = [
    ('', 'All', Icons.apps_rounded),
    ('Restaurants', 'Restaurants', Icons.restaurant_rounded),
    ('Cafes', 'Cafes', Icons.coffee_rounded),
    ('Events', 'Events', Icons.event_rounded),
    ('Offers', 'Offers', Icons.local_offer_rounded),
  ];

  static const _sortOptions = [
    ('', 'Default', Icons.sort_rounded),
    ('topRated', 'Top Rated', Icons.star_rounded),
    ('newest', 'Newest', Icons.access_time_rounded),
    ('mostPopular', 'Most Popular', Icons.trending_up_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _draft = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Color(0x22000000), blurRadius: 24, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                if (_draft.hasActiveFilters)
                  GestureDetector(
                    onTap: () => setState(() => _draft = _draft.reset()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF641A).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Clear All',
                        style: TextStyle(
                          color: Color(0xFFFF641A),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Category ─────────────────────────────────────────────
                  const _SectionLabel(label: 'Category'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((item) {
                      final (value, label, icon) = item;
                      final selected = _draft.category == value;
                      return _FilterChip(
                        label: label,
                        icon: icon,
                        selected: selected,
                        onTap: () => setState(
                          () => _draft = _draft.copyWith(category: value),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),

                  // ── Sort By ───────────────────────────────────────────────
                  const _SectionLabel(label: 'Sort By'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sortOptions.map((item) {
                      final (value, label, icon) = item;
                      final selected = _draft.sortBy == value;
                      return _FilterChip(
                        label: label,
                        icon: icon,
                        selected: selected,
                        onTap: () => setState(
                          () => _draft = _draft.copyWith(sortBy: value),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),

                  // ── Open Now ──────────────────────────────────────────────
                  const _SectionLabel(label: 'Availability'),
                  const SizedBox(height: 10),
                  _OpenNowTile(
                    value: _draft.openNow,
                    onChanged: (v) =>
                        setState(() => _draft = _draft.copyWith(openNow: v)),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),

          // ── Action Buttons ────────────────────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF555555),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: CustomButton(
                      text: _draft.hasActiveFilters
                            ? 'Apply (${_draft.activeCount})'
                            : 'Apply',
                      onPressed: () => Navigator.pop(context, _draft),
                      height: 50,
                      borderRadius: 12,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.white,
                      ),
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
}

// ─── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A1A),
        letterSpacing: 0.1,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF641A) : const Color(0xFFF5F5F9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? const Color(0xFFFF641A)
                : const Color(0xFFE0E0E6),
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF641A).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : const Color(0xFF777777),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF444444),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenNowTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OpenNowTile({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: value
            ? const Color(0xFFFF641A).withValues(alpha: 0.05)
            : const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? const Color(0xFFFF641A) : const Color(0xFFE8E8EE),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: value
                  ? const Color(0xFFFF641A).withValues(alpha: 0.12)
                  : const Color(0xFFEEEEF2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.schedule_rounded,
              size: 20,
              color: value ? const Color(0xFFFF641A) : const Color(0xFF888888),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Open Now',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  'Show only currently open places',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFFFF641A),
            activeTrackColor: const Color(0xFFFF641A).withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}
