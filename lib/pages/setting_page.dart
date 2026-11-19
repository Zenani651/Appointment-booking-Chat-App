import 'package:chat_app/components/my_button.dart';
import 'package:chat_app/components/my_textfields.dart';
import 'package:chat_app/components/user_avatar.dart';
import 'package:chat_app/pages/business_profile_edit_page.dart';
import 'package:chat_app/services/auth/auth.dart';
import 'package:chat_app/services/chat/chat_service.dart';
import 'package:chat_app/services/profile/profile_service.dart';
import 'package:chat_app/themes/theme_provider.dart';
import 'package:chat_app/utils/roles.dart';
import 'package:chat_app/utils/validators.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _authService = AuthService();
  final _profileService = ProfileService();
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = _authService.getCurrentUser()?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveName() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _authService.updateDisplayName(_nameController.text);
      _toast('Display name updated');
    } catch (_) {
      _toast('Could not update your name.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickPhoto() async {
    try {
      // Resized and compressed by the picker itself.
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 70,
      );
      if (file == null) return; // user cancelled

      setState(() => _isUploadingPhoto = true);
      await _profileService.uploadPhoto(file);
      _toast('Profile photo updated');
    } on ProfileFailure catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not update your photo.');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _isUploadingPhoto = true);
    try {
      await _profileService.removePhoto();
      _toast('Profile photo removed');
    } catch (_) {
      _toast('Could not remove your photo.');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = _authService.getCurrentUser();
    final avatarName =
        (user?.displayName?.trim().isNotEmpty ?? false)
            ? user!.displayName!
            : (user?.email ?? '?');

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.grey,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Profile photo
          if (user != null) ...[
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _isUploadingPhoto ? null : _pickPhoto,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    UserAvatar(uid: user.uid, name: avatarName, radius: 48),
                    if (_isUploadingPhoto) const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _isUploadingPhoto ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Change photo'),
                ),
                TextButton(
                  onPressed: _isUploadingPhoto ? null : _removePhoto,
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],

          // Dark mode
          // Business accounts: edit the public business profile.
          if (user != null)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: ChatService().getUserStream(user.uid),
              builder: (context, snap) {
                final data = snap.data?.data();
                if (data == null || !isBusinessUser(data)) {
                  return const SizedBox.shrink();
                }
                return Container(
                  margin: const EdgeInsets.fromLTRB(25, 16, 25, 0),
                  decoration: BoxDecoration(
                    color: scheme.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: const Text('Business profile'),
                    subtitle: const Text('Description, hours, phone, address'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => const BusinessProfileEditPage(),
                          ),
                        ),
                  ),
                );
              },
            ),
          Container(
            decoration: BoxDecoration(
              color: scheme.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(25),
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Dark Mode"),
                Switch(
                  value: Provider.of<ThemeProvider>(context).isDarkMode,
                  onChanged: (value) {
                    Provider.of<ThemeProvider>(
                      context,
                      listen: false,
                    ).toggleTheme();
                  },
                ),
              ],
            ),
          ),

          // Display name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Text(
              'Display name',
              style: TextStyle(color: scheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Form(
            key: _formKey,
            child: MyTextfields(
              hintText: 'Your name',
              obscureText: false,
              controller: _nameController,
              validator: Validators.displayName,
              onSubmitted: (_) => _saveName(),
            ),
          ),
          const SizedBox(height: 16),
          MyButton(text: 'Save name', onTap: _saveName, isLoading: _isSaving),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
