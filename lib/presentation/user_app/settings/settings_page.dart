import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app_router.dart';
import '../../../core/widgets/themed_top_header.dart';
import '../../../data/user_app/models/user_model.dart';
import '../../../injection_container.dart';
import '../profile/edit_profile_page.dart';
import '../profile/profile_bloc.dart';
import '../profile/profile_state.dart';
import 'privacy_security_page.dart';
import 'notification_settings_page.dart';
import 'add_account_page.dart';
import '../support/help_center_page.dart';
import '../support/terms_and_policies_page.dart';
import '../support/report_problem_page.dart';

class SettingsPage extends StatelessWidget {
  final ScrollController? scrollController;
  final VoidCallback? onBackPressed;
  final VoidCallback? onOpenNotifications;

  const SettingsPage({
    super.key,
    this.scrollController,
    this.onBackPressed,
    this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProfileBloc>()..add(LoadProfileEvent()),
      child: SettingsView(
        scrollController: scrollController,
        onBackPressed: onBackPressed,
        onOpenNotifications: onOpenNotifications,
      ),
    );
  }
}

class SettingsView extends StatefulWidget {
  final ScrollController? scrollController;
  final VoidCallback? onBackPressed;
  final VoidCallback? onOpenNotifications;

  const SettingsView({
    super.key,
    this.scrollController,
    this.onBackPressed,
    this.onOpenNotifications,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  _SettingsScreen _currentScreen = _SettingsScreen.main;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileLoggedOut) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.login,
              (route) => false,
            );
          }
        },
        builder: (context, state) {
          final loadedState = state is ProfileLoaded
              ? state
              : ProfileLoaded(user: UserModel.empty);
          final isLoading =
              (state is ProfileInitial || state is ProfileLoading) &&
                  !loadedState.user.hasCoreData;

          return Stack(
            children: [
              _currentScreen == _SettingsScreen.main
                  ? _SettingsHomeContent(
                      state: state,
                      loadedState: loadedState,
                      scrollController: widget.scrollController,
                      onBackPressed: () {
                        if (widget.onBackPressed != null) {
                          widget.onBackPressed!.call();
                          return;
                        }
                        Navigator.maybePop(context);
                      },
                      onOpenEditProfile: () => _openEditProfile(
                        context,
                        loadedState.user,
                      ),
                      onOpenPrivacySecurity: () {
                        setState(() => _currentScreen = _SettingsScreen.privacy);
                      },
                      onOpenNotifications: () {
                        setState(() => _currentScreen = _SettingsScreen.notifications);
                      },
                    )
                  : _currentScreen == _SettingsScreen.privacy
                      ? PrivacySecurityPage(
                          scrollController: widget.scrollController,
                          onBackPressed: () {
                            setState(() => _currentScreen = _SettingsScreen.main);
                          },
                        )
                      : NotificationSettingsPage(
                          scrollController: widget.scrollController,
                          onBackPressed: () {
                            setState(() => _currentScreen = _SettingsScreen.main);
                          },
                        ),
              if (isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFE6A1C),
                  ),
                ),
              if (loadedState.isLoggingOut)
                Container(
                  color: const Color(0x33000000),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(
                    color: Color(0xFFFE6A1C),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEditProfile(BuildContext context, UserModel user) async {
    if (!user.hasCoreData) {
      _showMessage(context, 'Your profile is still loading.');
      return;
    }

    final updatedUser = await Navigator.of(context).push<UserModel>(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(user: user),
      ),
    );

    if (updatedUser == null || !context.mounted) {
      return;
    }

    context.read<ProfileBloc>().add(UpdateProfileEvent());
    _showMessage(context, 'Profile updated successfully.');
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

enum _SettingsScreen { main, privacy, notifications }

class _SettingsHomeContent extends StatelessWidget {
  final ProfileState state;
  final ProfileLoaded loadedState;
  final ScrollController? scrollController;
  final VoidCallback onBackPressed;
  final VoidCallback onOpenEditProfile;
  final VoidCallback onOpenPrivacySecurity;
  final VoidCallback onOpenNotifications;

  const _SettingsHomeContent({
    required this.state,
    required this.loadedState,
    required this.scrollController,
    required this.onBackPressed,
    required this.onOpenEditProfile,
    required this.onOpenPrivacySecurity,
    required this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ThemedTopHeader(
          title: 'Settings',
          showBackButton: true,
          onBackPressed: onBackPressed,
        ),
        Expanded(
          child: CustomScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      if (state is ProfileError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _SettingsMessageCard(
                            message: (state as ProfileError).message,
                          ),
                        ),
                      _SettingsSection(
                        title: 'Account',
                        items: [
                          _SettingsAction(
                            icon: Icons.person_outline_rounded,
                            title: 'Edit profile',
                            onTap: onOpenEditProfile,
                          ),
                          _SettingsAction(
                            icon: Icons.shield_outlined,
                            title: 'Privacy& security',
                            onTap: onOpenPrivacySecurity,
                          ),
                          _SettingsAction(
                            icon: Icons.notifications_none_rounded,
                            title: 'Notifications',
                            onTap: onOpenNotifications,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SettingsSection(
                        title: 'Support & About',
                        items: [
                          _SettingsAction(
                            icon: Icons.help_outline_rounded,
                            title: 'Help Center',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const HelpCenterPage()),
                              );
                            },
                          ),
                          _SettingsAction(
                            icon: Icons.info_outline_rounded,
                            title: 'Terms and Policies',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const TermsAndPoliciesPage()),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SettingsSection(
                        title: 'Actions',
                        items: [
                          _SettingsAction(
                            icon: Icons.flag_outlined,
                            title: 'Report a problem',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ReportProblemPage()),
                              );
                            },
                          ),
                          _SettingsAction(
                            icon: Icons.group_add_outlined,
                            title: 'Add account',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AddAccountPage()),
                              );
                            },
                          ),
                          _SettingsAction(
                            icon: Icons.logout_rounded,
                            title: 'Log out',
                            onTap: () => _confirmLogout(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsAction> items;

  const _SettingsSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E1E1E),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Color(0xFFE8E8EE),
                  ),
                _SettingsTile(item: items[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final _SettingsAction item;

  const _SettingsTile({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(
                item.icon,
                color: const Color(0xFF565656),
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsMessageCard extends StatelessWidget {
  final String message;

  const _SettingsMessageCard({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3EC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF7A3E1D),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SettingsAction {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}

// Removed unused _showSettingsMessage method

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
