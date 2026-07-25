import 'package:flutter/material.dart';
import '../../../core/widgets/themed_top_header.dart';
import '../../../core/services/privacy_service.dart';
import '../../../injection_container.dart';

class PrivacySecurityPage extends StatefulWidget {
  final ScrollController? scrollController;
  final VoidCallback onBackPressed;

  const PrivacySecurityPage({
    super.key,
    this.scrollController,
    required this.onBackPressed,
  });

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  final _privacyService = sl<PrivacyService>();
  bool _locationAccess = false;
  bool _privateProfile = false;
  bool _connectedDevices = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final locationStatus = await _privacyService.getLocationPermissionStatus();
    final privateProfile = _privacyService.getPrivateProfileStatus();
    final allowMultiple = _privacyService.getAllowMultipleDevices();
    setState(() {
      _locationAccess = locationStatus;
      _privateProfile = privateProfile;
      _connectedDevices = allowMultiple;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ThemedTopHeader(
          title: 'Privacy & security',
          showBackButton: true,
          onBackPressed: widget.onBackPressed,
        ),
        Expanded(
          child: Padding(
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
                            _PrivacyOptionCard(
                              title: 'Location access',
                              subtitle: 'Allow app to access your location',
                              value: _locationAccess,
                              onChanged: (value) async {
                                if (value) {
                                  final granted = await _privacyService.requestLocationPermission();
                                  if (!granted) {
                                    if (mounted) {
                                      _showPermissionDialog();
                                    }
                                  }
                                  setState(() => _locationAccess = granted);
                                } else {
                                  _showLocationDisableDialog();
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                            _PrivacyOptionCard(
                              title: 'Private profile',
                              subtitle:
                                  'Only approved users can see your reviews',
                              value: _privateProfile,
                              onChanged: (value) async {
                                setState(() => _privateProfile = value);
                                await _privacyService.setPrivateProfile(value);
                              },
                            ),
                            const SizedBox(height: 14),
                            _PrivacyOptionCard(
                              title: 'Connected devices',
                              subtitle: _connectedDevices
                                  ? 'Allow login from multiple devices'
                                  : 'Only this device can access account',
                              value: _connectedDevices,
                              onChanged: (value) async {
                                if (!value) {
                                  _showSingleDeviceDialog();
                                } else {
                                  setState(() => _connectedDevices = value);
                                  await _privacyService.setAllowMultipleDevices(value);
                                }
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
                      onPressed: _savePreferences,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF641A),
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        elevation: 6,
                        shadowColor: const Color(0x33FF641A),
                      ),
                      child: const Text(
                        'Save Preferences',
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

  void _savePreferences() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Privacy preferences saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission'),
        content: const Text(
          'Location permission is required. Please enable it in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _privacyService.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showLocationDisableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable Location'),
        content: const Text(
          'To disable location access, please go to app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _privacyService.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showSingleDeviceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Single Device Mode'),
        content: const Text(
          'Enabling this will log out all other devices. Only this device will have access to your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _connectedDevices = false);
              await _privacyService.setAllowMultipleDevices(false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Other devices have been logged out'),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

class _PrivacyOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrivacyOptionCard({
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
              _PrivacyCheckbox(
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

class _PrivacyCheckbox extends StatelessWidget {
  final bool value;
  final VoidCallback onTap;

  const _PrivacyCheckbox({
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
