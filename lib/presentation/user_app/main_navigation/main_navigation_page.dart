import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hidable/hidable.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../injection_container.dart';
import '../home/home_page.dart';
import '../search/search_page.dart';
import '../notifications/notifications_page.dart';
import '../notifications/notifications_bloc.dart';
import '../notifications/notifications_state.dart';
import '../profile/profile_page.dart';
import '../settings/settings_page.dart';

class MainNavigationPage extends StatefulWidget {
  final int initialIndex;

  const MainNavigationPage({
    super.key,
    this.initialIndex = 2,
  });

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage>
    with WidgetsBindingObserver {
  late int _selectedIndex;
  final ScrollController _homeScrollController = ScrollController();
  final ScrollController _notificationsScrollController = ScrollController();
  final ScrollController _settingsScrollController = ScrollController();
  final ScrollController _profileScrollController = ScrollController();
  final GlobalKey<HomePageState> _homeKey = GlobalKey<HomePageState>();
  late final NotificationsBloc _notificationsBloc;

  ScrollController get _activeScrollController {
    switch (_selectedIndex) {
      case 1:
        return _notificationsScrollController;
      case 2:
        return _homeScrollController;
      case 3:
        return _settingsScrollController;
      case 4:
        return _profileScrollController;
      default:
        return _homeScrollController;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 4);
    _notificationsBloc = sl<NotificationsBloc>()..add(LoadNotificationsEvent());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _homeScrollController.dispose();
    _notificationsScrollController.dispose();
    _settingsScrollController.dispose();
    _profileScrollController.dispose();
    _notificationsBloc.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _notificationsBloc.add(RefreshNotificationsEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomBarMetrics = _buildBottomBarMetrics(context);

    return BlocProvider.value(
      value: _notificationsBloc,
      child: Scaffold(
        body: _LazyIndexedStack(
          index: _selectedIndex,
          itemBuilders: [
            (ctx) => SearchPage(
                  onBackPressed: () => setState(() => _selectedIndex = 2),
                ),
            (ctx) => NotificationsPage(
                  scrollController: _notificationsScrollController,
                ),
            (ctx) => HomePage(
                  key: _homeKey,
                  scrollController: _homeScrollController,
                ),
            (ctx) => SettingsPage(
                  scrollController: _settingsScrollController,
                  onBackPressed: () => setState(() => _selectedIndex = 2),
                  onOpenNotifications: () => setState(() => _selectedIndex = 1),
                ),
            (ctx) => ProfilePage(
                  scrollController: _profileScrollController,
                  onBackPressed: () => setState(() => _selectedIndex = 2),
                  onOpenNotifications: () => setState(() => _selectedIndex = 1),
                ),
          ],
        ),
        bottomNavigationBar: Hidable(
          controller: _activeScrollController,
          preferredWidgetSize: Size.fromHeight(bottomBarMetrics.totalHeight),
          child: _buildBottomNavigationBar(bottomBarMetrics),
        ),
      ),
    );
  }

  _BottomBarMetrics _buildBottomBarMetrics(BuildContext context) {
    final screenWidth = ResponsiveUtils.width(context);
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
    final badgeSize = isCompact ? 14.0 : 16.0;
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

    return _BottomBarMetrics(
      horizontalPadding: horizontalPadding,
      verticalPadding: verticalPadding,
      iconSize: iconSize,
      itemSize: itemSize,
      centerItemSize: centerItemSize,
      badgeSize: badgeSize,
      labelFontSize: labelFontSize,
      labelSpacing: labelSpacing,
      contentHeight: contentHeight,
      totalHeight: contentHeight + bottomInset,
    );
  }

  Widget _buildBottomNavigationBar(_BottomBarMetrics metrics) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
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
                  // Frosted glass base
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
                          Icons.search_rounded,
                          'Search',
                          0,
                          iconSize: metrics.iconSize,
                          itemSize: metrics.itemSize,
                          badgeSize: metrics.badgeSize,
                          labelFontSize: metrics.labelFontSize,
                          labelSpacing: metrics.labelSpacing,
                        ),
                      ),
                      Expanded(
                        child: _buildNavItem(
                          Icons.notifications_rounded,
                          'Notif',
                          1,
                          iconSize: metrics.iconSize,
                          itemSize: metrics.itemSize,
                          badgeSize: metrics.badgeSize,
                          labelFontSize: metrics.labelFontSize,
                          labelSpacing: metrics.labelSpacing,
                        ),
                      ),
                      Expanded(
                        child: _buildNavItem(
                          Icons.home_rounded,
                          'Home',
                          2,
                          iconSize: metrics.iconSize,
                          itemSize: metrics.centerItemSize,
                          badgeSize: metrics.badgeSize,
                          labelFontSize: metrics.labelFontSize,
                          labelSpacing: metrics.labelSpacing,
                          isCenter: true,
                        ),
                      ),
                      Expanded(
                        child: _buildNavItem(
                          Icons.settings_rounded,
                          'Settings',
                          3,
                          iconSize: metrics.iconSize,
                          itemSize: metrics.itemSize,
                          badgeSize: metrics.badgeSize,
                          labelFontSize: metrics.labelFontSize,
                          labelSpacing: metrics.labelSpacing,
                        ),
                      ),
                      Expanded(
                        child: _buildNavItem(
                          Icons.person_rounded,
                          'Profile',
                          4,
                          iconSize: metrics.iconSize,
                          itemSize: metrics.itemSize,
                          badgeSize: metrics.badgeSize,
                          labelFontSize: metrics.labelFontSize,
                          labelSpacing: metrics.labelSpacing,
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

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index, {
    required double iconSize,
    required double itemSize,
    required double badgeSize,
    required double labelFontSize,
    required double labelSpacing,
    bool isCenter = false,
  }) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        if (_selectedIndex == index) {
          if (index == 2) {
            _homeKey.currentState?.handleHomeTabTap();
          }
        } else {
          HapticFeedback.selectionClick();
          setState(() => _selectedIndex = index);
          if (index == 1) {
            _notificationsBloc.add(RefreshNotificationsEvent());
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Icon container ───────────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
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
                        BoxShadow(
                          color: const Color(0xFFFE6A1C).withValues(alpha: 0.20),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    )
                  : BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? const Color(0xFFFE6A1C).withValues(alpha: 0.12)
                          : Colors.transparent,
                    ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: iconSize,
                    color: isCenter
                        ? Colors.white
                        : isSelected
                            ? const Color(0xFFFE6A1C)
                            : const Color(0xFF9A9A9A),
                  ),
                  if (index == 1)
                    Positioned(
                      right: -(badgeSize * 0.35),
                      top: -(badgeSize * 0.4),
                      child: BlocBuilder<NotificationsBloc, NotificationsState>(
                        builder: (context, state) {
                          if (state.unreadCount <= 0) return const SizedBox.shrink();
                          final countLabel = state.unreadCount > 99 ? '99+' : '${state.unreadCount}';
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: badgeSize * 0.3,
                              vertical: 1.5,
                            ),
                            constraints: BoxConstraints(
                              minWidth: badgeSize,
                              minHeight: badgeSize,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFE6A1C),
                              borderRadius: BorderRadius.all(Radius.circular(10)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              countLabel,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: badgeSize * 0.58,
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: labelSpacing),
            // ── Label ────────────────────────────────────────────────────────
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: labelFontSize,
                  height: 1,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected
                      ? const Color(0xFFFE6A1C)
                      : const Color(0xFF9A9A9A),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(label, maxLines: 1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
}

class _BottomBarMetrics {
  final double horizontalPadding;
  final double verticalPadding;
  final double iconSize;
  final double itemSize;
  final double centerItemSize;
  final double badgeSize;
  final double labelFontSize;
  final double labelSpacing;
  final double contentHeight;
  final double totalHeight;

  const _BottomBarMetrics({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.iconSize,
    required this.itemSize,
    required this.centerItemSize,
    required this.badgeSize,
    required this.labelFontSize,
    required this.labelSpacing,
    required this.contentHeight,
    required this.totalHeight,
  });
}

class _LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<WidgetBuilder> itemBuilders;

  const _LazyIndexedStack({
    required this.index,
    required this.itemBuilders,
  });

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  late final List<bool> _activated;

  @override
  void initState() {
    super.initState();
    _activated = List<bool>.generate(
      widget.itemBuilders.length,
      (i) => i == widget.index,
    );
  }

  @override
  void didUpdateWidget(_LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index >= 0 && widget.index < _activated.length) {
      if (!_activated[widget.index]) {
        _activated[widget.index] = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: List.generate(
        widget.itemBuilders.length,
        (i) => _activated[i]
            ? widget.itemBuilders[i](context)
            : const SizedBox.shrink(),
      ),
    );
  }
}
