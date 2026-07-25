import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app_router.dart';
import '../../../core/widgets/app_theme.dart';
import '../../../data/user_app/models/user_model.dart';
import '../../../injection_container.dart';
import '../booking/screens/my_tickets_screen.dart';
import '../settings/settings_page.dart';
import '../support/chat_with_us_page.dart';
import '../support/contact_us_page.dart';
import '../support/help_center_page.dart';
import 'edit_profile_page.dart';
import 'profile_bloc.dart';
import 'profile_state.dart';
import 'profile_widgets.dart';

class ProfilePage extends StatelessWidget {
  final ScrollController? scrollController;
  final VoidCallback? onBackPressed;
  final VoidCallback? onOpenNotifications;

  const ProfilePage({
    super.key,
    this.scrollController,
    this.onBackPressed,
    this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<ProfileBloc>()..add(LoadProfileEvent()),
      child: ProfileView(
        scrollController: scrollController,
        onBackPressed: onBackPressed,
        onOpenNotifications: onOpenNotifications,
      ),
    );
  }
}

class ProfileView extends StatelessWidget {
  final ScrollController? scrollController;
  final VoidCallback? onBackPressed;
  final VoidCallback? onOpenNotifications;

  const ProfileView({
    super.key,
    this.scrollController,
    this.onBackPressed,
    this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F2EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F2EE),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF141414),
          ),
        ),
        leading: IconButton(
          onPressed: () {
            if (onBackPressed != null) {
              onBackPressed!.call();
              return;
            }
            Navigator.maybePop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF232323),
            size: 22,
          ),
        ),
      ),
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileLoggedOut || state is ProfileAccountDeleted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.login,
              (route) => false,
            );
          }
        },
        builder: (context, state) {
          if (state is ProfileLoading || state is ProfileInitial) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFE6A1C),
              ),
            );
          }

          if (state is ProfileError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  state.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF4A4A4A),
                  ),
                ),
              ),
            );
          }

          final loadedState = state is ProfileLoaded
              ? state
              : ProfileLoaded(user: UserModel.empty);

          return CustomScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      ProfileHeader(
                        userName: loadedState.user.displayName,
                        userCity: loadedState.user.city,
                        profileImagePath: loadedState.user.profileImagePath,
                        isVerified: loadedState.isVerified,
                        onEditPressed: () =>
                            _openEditProfile(context, loadedState.user),
                      ),
                      const SizedBox(height: 14),
                      _ProfileSectionCard(
                        title: 'Accounts',
                        onOpenNotifications: onOpenNotifications,
                        items: const [
                          _ProfileMenuData(
                              Icons.star_outline_rounded, 'My Review'),
                          _ProfileMenuData(
                              Icons.people_alt_outlined, 'My Following'),
                          _ProfileMenuData(
                              Icons.confirmation_num_outlined, 'My Booking'),
                          _ProfileMenuData(
                              Icons.history_rounded, 'History Event Booking'),
                          _ProfileMenuData(
                              Icons.notifications_none_rounded, 'Notification'),
                          _ProfileMenuData(Icons.settings_outlined, 'Setting'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _ProfileSectionCard(
                        title: 'Help',
                        items: [
                          _ProfileMenuData(Icons.chat_bubble_outline_rounded,
                              'Chat with Us'),
                          _ProfileMenuData(Icons.call_outlined, 'Contact Us'),
                          _ProfileMenuData(Icons.live_help_outlined,
                              'Frequently Asked Questions'),
                        ],
                      ),
                      const SizedBox(height: 26),
                      LogoutButton(
                        isLoading: loadedState.isLoggingOut,
                        onPressed: () => _confirmLogout(context),
                      ),
                      const SizedBox(height: 12),
                      DeleteAccountButton(
                        isLoading: loadedState.isDeletingAccount,
                        onPressed: () => _confirmDeleteAccount(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEditProfile(BuildContext context, UserModel user) async {
    final updatedUser = await Navigator.of(context).push<UserModel>(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(user: user),
      ),
    );

    if (updatedUser == null || !context.mounted) {
      return;
    }

    context.read<ProfileBloc>().add(UpdateProfileEvent());
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }


  void _confirmDeleteAccount(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Delete Account',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFFD32F2F),
          ),
        ),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone.',
          style: TextStyle(color: Color(0xFF5C5C5C), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6A6A6A)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (context.mounted) {
                context.read<ProfileBloc>().add(DeleteAccountEvent());
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Logout',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFFFE6A1C),
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of your account?',
          style: TextStyle(color: Color(0xFF5C5C5C), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6A6A6A)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFE6A1C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<ProfileBloc>().add(LogoutEvent());
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  final String title;
  final List<_ProfileMenuData> items;
  final VoidCallback? onOpenNotifications;

  const _ProfileSectionCard({
    required this.title,
    required this.items,
    this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Depth3DCard(
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
                letterSpacing: 0.8,
              ),
            ),
          ),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Color(0xFFF0EBE6),
              ),
            ProfileMenuItem(
              icon: items[i].icon,
              title: items[i].title,
              onTap: () => _handleMenuTap(context, items[i].title),
            ),
          ],
        ],
      ),
    );
  }

  void _handleMenuTap(BuildContext context, String title) {
    if (title == 'My Booking' || title == 'My Tickets') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MyTicketsScreen()),
      );
      return;
    }
    if (title == 'My Review') {
      Navigator.of(context).pushNamed(AppRoutes.myReviews);
      return;
    }
    if (title == 'My Following') {
      Navigator.of(context).pushNamed(AppRoutes.favorites);
      return;
    }
    if (title == 'History Event Booking') {
      Navigator.of(context).pushNamed(AppRoutes.history);
      return;
    }
    if (title == 'Notification') {
      // Switch to the Notifications tab in the bottom nav
      if (onOpenNotifications != null) {
        onOpenNotifications!.call();
      }
      return;
    }
    if (title == 'Setting') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SettingsPage(
            scrollController: ScrollController(),
          ),
        ),
      );
      return;
    }
    if (title == 'Chat with Us') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ChatWithUsPage()),
      );
      return;
    }
    if (title == 'Contact Us') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ContactUsPage()),
      );
      return;
    }
    if (title == 'Frequently Asked Questions') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HelpCenterPage()),
      );
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$title is coming soon.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _ProfileMenuData {
  final IconData icon;
  final String title;

  const _ProfileMenuData(this.icon, this.title);
}
