import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/widgets/themed_top_header.dart';
import '../../../core/storage/user_session_manager.dart';
import '../../../core/helpers/profile_image_helper.dart';
import '../../../data/user_app/datasources/auth_remote_data_source.dart';
import '../../../data/user_app/models/user_model.dart';
import '../../../injection_container.dart';
import 'image_crop_page.dart';
import 'change_password_page.dart';

class EditProfilePage extends StatefulWidget {
  final UserModel user;

  const EditProfilePage({
    super.key,
    required this.user,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const List<String> _regions = [
    'Mansoura',
    'Cairo',
    'Alexandria',
    'Giza',
    'Tanta',
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late String _selectedRegion;
  late String _profileImagePath;
  bool _isSaving = false;

  final ImagePicker _imagePicker = ImagePicker();

  AuthRemoteDataSource get _authRemoteDataSource => sl<AuthRemoteDataSource>();
  UserSessionManager get _userSessionManager => sl<UserSessionManager>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _profileImagePath =
        ProfileImageHelper.resolve(widget.user.profileImagePath);

    final initialRegion = widget.user.city.trim();
    _selectedRegion = initialRegion.isNotEmpty ? initialRegion : _regions.first;
    if (!_regions.contains(_selectedRegion)) {
      _selectedRegion = _regions.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          ThemedTopHeader(
            title: 'Edit Profile',
            showBackButton: true,
            onBackPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              child: Column(
                children: [
                  SizedBox(
                    height: 84,
                    child: Transform.translate(
                      offset: const Offset(0, -34),
                      child: _buildAvatar(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    label: 'Name',
                    controller: _nameController,
                  ),
                  const SizedBox(height: 18),
                  _buildTextField(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: false,
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.key_rounded, size: 20),
                    label: const Text('Change Password'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFE6A1C),
                      side: const BorderSide(color: Color(0xFFFE6A1C)),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildRegionField(),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFE6A1C),
                        disabledBackgroundColor: const Color(0xFFFFB085),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save changes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
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

  Widget _buildAvatar() {
    final imageProvider = ProfileImageHelper.imageProvider(_profileImagePath);
    final hasImage = imageProvider != null;

    return Transform.translate(
      offset: const Offset(0, -8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: _showImageSourceSheet,
            child: Container(
              width: 122,
              height: 122,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFC5C5C5), width: 2),
                gradient: hasImage
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFEBD9B9), Color(0xFFC3D58A)],
                      ),
                image: hasImage
                    ? DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: hasImage
                  ? null
                  : const Icon(
                      Icons.person_rounded,
                      size: 72,
                      color: Colors.white,
                    ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: 10,
            child: GestureDetector(
              onTap: _showImageSourceSheet,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFFE6A1C),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? hintText,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF3E3E3E),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: TextStyle(
            color: enabled ? const Color(0xFF2D2D2D) : const Color(0xFF777777),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: enabled
                ? const Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: Color(0xFF9C9C9C),
                  )
                : const Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: Color(0xFFB0B0B0),
                  ),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF4F4F4),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE7E7E7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFE6A1C)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Country/Region',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF3E3E3E),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedRegion,
          items: _regions
              .map(
                (region) => DropdownMenuItem<String>(
                  value: region,
                  child: Text(region),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => _selectedRegion = value);
          },
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE7E7E7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFE6A1C)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose where you want to pick the photo from.',
                  style: TextStyle(
                    color: Color(0xFF6B6B6B),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                _ImageSourceTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from gallery',
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickProfileImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 10),
                _ImageSourceTile(
                  icon: Icons.photo_camera_outlined,
                  title: _isDesktopPlatform
                      ? 'Use camera (mobile only)'
                      : 'Use camera',
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickProfileImage(ImageSource.camera);
                  },
                  color: _isDesktopPlatform
                      ? const Color(0xFF8A8A8A)
                      : const Color(0xFF2D2D2D),
                ),
                if (_profileImagePath.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ImageSourceTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Remove current photo',
                    color: const Color(0xFFD9534F),
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() => _profileImagePath = '');
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    if (_isDesktopPlatform && source == ImageSource.camera) {
      _showMessage(
          'Camera is not supported on Windows right now. Please choose from gallery.');
      return;
    }

    try {
      final pickedFile = _isDesktopPlatform
          ? await _imagePicker.pickImage(source: source)
          : await _imagePicker.pickImage(
              source: source,
              maxWidth: 1200,
              imageQuality: 85,
            );
      if (pickedFile == null) {
        return;
      }

      if (!mounted) return;

      // Navigate to ImageCropPage for user adjustment/cropping
      final String? croppedPath = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => ImageCropPage(imagePath: pickedFile.path),
        ),
      );

      if (croppedPath == null || !mounted) {
        return;
      }

      final savedPath = await _persistProfileImage(croppedPath);
      if (!mounted) {
        return;
      }

      setState(() => _profileImagePath = savedPath);
    } on MissingPluginException {
      if (!mounted) {
        return;
      }
      _showMessage(
        'Image picker is not loaded yet. Please stop the app completely and run it again.',
      );
    } on PlatformException catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(
        e.message?.trim().isNotEmpty == true
            ? e.message!.trim()
            : 'The device blocked access to the image source.',
      );
    } catch (e, stackTrace) {
      debugPrint('Profile image pick failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      _showMessage(_desktopFriendlyError(source));
    }
  }

  Future<String> _persistProfileImage(String sourcePath) async {
    final sourceFile = File(sourcePath);
    final directory = await getApplicationDocumentsDirectory();
    final extension = sourceFile.path.split('.').last;
    final fileName =
        'profile_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final targetPath = '${directory.path}/$fileName';
    final copiedFile = await sourceFile.copy(targetPath);
    return copiedFile.path;
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    final email = widget.user.email.trim();

    if (name.isEmpty || email.isEmpty) {
      _showMessage('Please fill in name and email.');
      return;
    }

    setState(() => _isSaving = true);

    String resolvedImagePath = ProfileImageHelper.resolve(_profileImagePath);
    final previousImagePath =
        ProfileImageHelper.resolve(widget.user.profileImagePath);
    final localImagePath =
        ProfileImageHelper.resolveLocalPath(_profileImagePath);
    final imageChanged =
        resolvedImagePath != previousImagePath && _profileImagePath.isNotEmpty;

    final updatedUser = widget.user.copyWith(
      name: name,
      email: email,
      city: _selectedRegion,
      profileImagePath: resolvedImagePath,
    );

    await _userSessionManager.saveUser(updatedUser);
    unawaited(
      _syncProfileChangesWithServer(
        updatedUser,
        imageChanged: imageChanged,
        localImagePath: localImagePath,
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSaving = false);
    Navigator.of(context).pop(updatedUser);
  }

  Future<void> _syncProfileChangesWithServer(
    UserModel localUser, {
    required bool imageChanged,
    required String localImagePath,
  }) async {
    var syncedUser = localUser;
    var resolvedImagePath = localUser.profileImagePath;

    if (imageChanged && localImagePath.isNotEmpty) {
      try {
        final remoteUrl =
            await _authRemoteDataSource.uploadProfileImage(localImagePath);
        if (remoteUrl != null && remoteUrl.isNotEmpty) {
          resolvedImagePath = remoteUrl;
          syncedUser = syncedUser.copyWith(profileImagePath: remoteUrl);
        }
      } catch (e) {
        debugPrint('uploadProfileImage failed: $e');
      }
    }

    try {
      final response = await _authRemoteDataSource.updateUserProfile(
        fullName: localUser.name,
        email: localUser.email,
        city: localUser.city,
        profileImagePath: resolvedImagePath,
        password: null,
      );
      final remoteUser = UserModel.fromApiResponse(response);
      final remoteImage =
          ProfileImageHelper.resolve(remoteUser.profileImagePath);
      if (remoteUser.hasCoreData || remoteImage.isNotEmpty) {
        syncedUser = syncedUser.copyWith(
          id: remoteUser.id.isNotEmpty ? remoteUser.id : syncedUser.id,
          name: remoteUser.name.isNotEmpty ? remoteUser.name : syncedUser.name,
          email:
              remoteUser.email.isNotEmpty ? remoteUser.email : syncedUser.email,
          city: remoteUser.city.isNotEmpty ? remoteUser.city : syncedUser.city,
          profileImagePath: remoteImage.isNotEmpty
              ? remoteImage
              : syncedUser.profileImagePath,
        );
      }
    } catch (e) {
      debugPrint('updateUserProfile failed: $e');
    }

    await _userSessionManager.saveUser(syncedUser);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  bool get _isDesktopPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  String _desktopFriendlyError(ImageSource source) {
    if (_isDesktopPlatform && source == ImageSource.camera) {
      return 'Camera is not supported on desktop right now.';
    }
    if (_isDesktopPlatform) {
      return 'Could not open the gallery picker right now.';
    }
    return 'Could not pick the image right now.';
  }
}

class _ImageSourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color color;

  const _ImageSourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color = const Color(0xFF2D2D2D),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F7F7),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
