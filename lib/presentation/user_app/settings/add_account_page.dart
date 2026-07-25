import 'package:flutter/material.dart';
import '../../../app_router.dart';
import '../../../core/widgets/app_theme.dart';
import '../../../core/widgets/themed_top_header.dart';
import '../../../core/storage/user_session_manager.dart';
import '../../../core/helpers/profile_image_helper.dart';
import '../../../injection_container.dart';

class AddAccountPage extends StatefulWidget {
  const AddAccountPage({super.key});

  @override
  State<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends State<AddAccountPage> {
  late final UserSessionManager _sessionManager;
  final List<Map<String, dynamic>> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _sessionManager = sl<UserSessionManager>();
    _loadAccounts();
  }

  void _loadAccounts() {
    final current = _sessionManager.getUser();
    if (current != null) {
      _savedAccounts.add({
        'id': current.id,
        'name': current.name,
        'email': current.email,
        'avatar': current.profileImagePath,
        'isActive': true,
      });
    }

    // Add a mocked secondary account if none exists, just to populate the switcher UI!
    _savedAccounts.add({
      'id': 'second-mock-guid',
      'name': 'Ramy Ahmed (Business)',
      'email': 'ramy.ahmed@business.com',
      'avatar': '',
      'isActive': false,
    });
  }

  void _switchAccount(Map<String, dynamic> account) {
    if (account['isActive'] == true) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Switch Account'),
        content: Text('Switching account to ${account['name']}...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF641A),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                for (var acc in _savedAccounts) {
                  acc['isActive'] = (acc['id'] == account['id']);
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Switched to ${account['name']}'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Switch'),
          ),
        ],
      ),
    );
  }

  void _addNewAccount() {
    Navigator.pushNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          ThemedTopHeader(
            title: 'Add Account',
            showBackButton: true,
            onBackPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Active Accounts',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Saved accounts list ─────────────────────────────────────
                  _buildSavedAccounts(),
                  const SizedBox(height: 24),

                  // ── Add new account button ──────────────────────────────────
                  _buildAddAccountButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedAccounts() {
    return Column(
      children: _savedAccounts.map((account) {
        final isActive = account['isActive'] as bool;
        final name = account['name'] as String;
        final email = account['email'] as String;
        final avatar = account['avatar'] as String;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => _switchAccount(account),
            child: Depth3DCard(
              borderRadius: 16,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFFF641A).withValues(alpha: 0.1),
                      backgroundImage: ProfileImageHelper.imageProvider(avatar),
                      child: ProfileImageHelper.imageProvider(avatar) == null
                          ? const Icon(Icons.person, color: Color(0xFFFF641A), size: 24)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF222222),
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E7D50).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Active',
                                    style: TextStyle(
                                      color: Color(0xFF2E7D50),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D50))
                    else
                      const Icon(Icons.swap_horiz_rounded, color: Color(0xFFFF641A)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAddAccountButton() {
    return GestureDetector(
      onTap: _addNewAccount,
      child: Depth3DCard(
        borderRadius: 16,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE0D0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Color(0xFFFF641A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Add Another Account',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF641A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
