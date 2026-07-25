import 'package:flutter/material.dart';
import '../../../core/widgets/themed_top_header.dart';
import '../../../core/services/notification_settings_service.dart';
import '../../../injection_container.dart';

class NotificationSettingsPage extends StatefulWidget {
  final ScrollController? scrollController;
  final VoidCallback onBackPressed;

  const NotificationSettingsPage({
    super.key,
    this.scrollController,
    required this.onBackPressed,
  });

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final _notificationService = sl<NotificationSettingsService>();
  bool _isSettingsLoading = true;
  bool _isSaving = false;
  bool _pushNotifications = false;
  bool _emailNotifications = false;
  bool _promotions = false;


  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isSettingsLoading = true);
    try {
      await _notificationService.fetchSettingsFromBackend();
    } catch (_) {}
    
    final pushEnabled = await _notificationService.getPushNotificationsStatus();
    final emailEnabled = _notificationService.getEmailNotificationsStatus();
    final promotionsEnabled = _notificationService.getPromotionsStatus();
    
    if (mounted) {
      setState(() {
        _pushNotifications = pushEnabled;
        _emailNotifications = emailEnabled;
        _promotions = promotionsEnabled;
        _isSettingsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ThemedTopHeader(
          title: 'Notification',
          showBackButton: true,
          onBackPressed: widget.onBackPressed,
        ),
        Expanded(
          child: _isSettingsLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF641A),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
                  child: Column(
                    children: [
                      Expanded(
                        child: CustomScrollView(
                          controller: widget.scrollController,
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverList(
                              delegate: SliverChildListDelegate(
                                [
                                  _NotificationOptionCard(
                                    title: 'Push notifications',
                                    subtitle: 'Receive app push messages',
                                    value: _pushNotifications,
                                    onChanged: (value) async {
                                      if (value) {
                                        final granted = await _notificationService.requestPushNotificationPermission();
                                        if (!granted && mounted) {
                                          _showPermissionDialog();
                                        }
                                        setState(() => _pushNotifications = granted);
                                      } else {
                                        _showDisablePushDialog();
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _NotificationOptionCard(
                                    title: 'Email notifications',
                                    subtitle: 'Offers and updates by email',
                                    value: _emailNotifications,
                                    onChanged: (value) async {
                                      setState(() => _emailNotifications = value);
                                      await _notificationService.setEmailNotifications(value);
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _NotificationOptionCard(
                                    title: 'Promotions',
                                    subtitle: 'Special offers and marketing',
                                    value: _promotions,
                                    onChanged: (value) async {
                                      setState(() => _promotions = value);
                                      await _notificationService.setPromotions(value);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SafeArea(
                        top: false,
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isSaving ? null : _savePreferences,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF641A),
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              elevation: 6,
                              shadowColor: const Color(0x33FF641A),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Save References',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
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

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    try {
      await _notificationService.updateSettingsOnBackend(
        pushEnabled: _pushNotifications,
        emailEnabled: _emailNotifications,
        promotionsEnabled: _promotions,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Notification preferences saved.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Failed to save preferences on server: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }


  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Permission'),
        content: const Text(
          'Push notification permission is required. Please enable it in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _notificationService.openNotificationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showDisablePushDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable Push Notifications'),
        content: const Text(
          'To disable push notifications, please go to app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _notificationService.openNotificationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

class _NotificationOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationOptionCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F5F9),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF727272),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _NotificationCheckbox(
                value: value,
                onTap: () => onChanged(!value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCheckbox extends StatelessWidget {
  final bool value;
  final VoidCallback onTap;

  const _NotificationCheckbox({
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: value ? const Color(0xFFFF641A) : Colors.white,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: value ? const Color(0xFFFF641A) : const Color(0xFFD8D8DE),
          ),
        ),
        child: value
            ? const Icon(
                Icons.check_rounded,
                size: 13,
                color: Colors.white,
              )
            : null,
      ),
    );
  }
}
