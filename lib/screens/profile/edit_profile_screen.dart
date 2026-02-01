import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/profile_service.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();
  final _imagePicker = ImagePicker();

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController(); // ✅ ADĂUGAT
  final _bioController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose(); // ✅ ADĂUGAT
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    final profile = await _profileService.getCurrentProfile();

    if (profile != null) {
      _nameController.text = profile['full_name'] ?? '';
      _usernameController.text = profile['username'] ?? ''; // ✅ ADĂUGAT
      _bioController.text = profile['bio'] ?? '';
      _avatarUrl = profile['avatar_url'];
    } else {
      final user = supabase.auth.currentUser;
      _nameController.text = user?.userMetadata?['full_name'] ?? '';
    }

    setState(() => _isLoading = false);
  }

  Future<void> _pickAndUploadImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Cameră'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            if (_avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Șterge avatar', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, null),
              ),
          ],
        ),
      ),
    );

    if (source == null && _avatarUrl != null) {
      await _deleteAvatar();
      return;
    }

    if (source == null) return;

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingAvatar = true);

      final result = await _profileService.uploadAvatar(pickedFile.path);

      setState(() => _isUploadingAvatar = false);

      if (result.isSuccess) {
        setState(() => _avatarUrl = result.message);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar actualizat!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingAvatar = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eroare: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAvatar() async {
    setState(() => _isUploadingAvatar = true);

    final result = await _profileService.deleteAvatar();

    setState(() {
      _isUploadingAvatar = false;
      if (result.isSuccess) {
        _avatarUrl = null;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.isSuccess ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // ✅ ACTUALIZAT: Include username
    final result = await _profileService.updateProfile(
      fullName: _nameController.text.trim(),
      username: _usernameController.text.trim(), // ✅ ADĂUGAT
      bio: _bioController.text.trim(),
    );

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.isSuccess ? context.tr('profile_updated') : result.message),
          backgroundColor: result.isSuccess ? Colors.green : Colors.red,
        ),
      );

      if (result.isSuccess) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('edit_profile')),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('save')),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Avatar
                    Center(
                      child: Stack(
                        children: [
                          _isUploadingAvatar
                              ? CircleAvatar(
                                  radius: 60,
                                  backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
                                  child: const CircularProgressIndicator(),
                                )
                              : CircleAvatar(
                                  radius: 60,
                                  backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
                                  backgroundImage: _avatarUrl != null
                                      ? NetworkImage(_avatarUrl!)
                                      : null,
                                  child: _avatarUrl == null
                                      ? Text(
                                          _getInitials(_nameController.text),
                                          style: TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                          ),
                                        )
                                      : null,
                                ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: _isUploadingAvatar ? null : _pickAndUploadImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Apasă pe cameră pentru a schimba',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ✅ USERNAME FIELD (NOU!)
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        hintText: 'Alege un username unic',
                        prefixText: '@',
                        prefixIcon: const Icon(Icons.alternate_email),
                        helperText: 'Acest username va apărea în Swirls',
                        helperMaxLines: 2,
                      ),
                      maxLength: 30,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Username-ul este obligatoriu';
                        }
                        if (value.trim().length < 3) {
                          return 'Username-ul trebuie să aibă cel puțin 3 caractere';
                        }
                        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                          return 'Username-ul poate conține doar litere, cifre și _';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Nume
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: context.tr('full_name'),
                        prefixIcon: const Icon(Icons.person_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.tr('name_required');
                        }
                        if (value.trim().length < 2) {
                          return context.tr('name_min_length');
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),

                    const SizedBox(height: 20),

                    // Bio
                    TextFormField(
                      controller: _bioController,
                      maxLines: 4,
                      maxLength: 200,
                      decoration: InputDecoration(
                        labelText: context.tr('bio'),
                        hintText: context.tr('bio_hint'),
                        prefixIcon: const Icon(Icons.info_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Info email (readonly)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('email'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                Text(
                                  supabase.auth.currentUser?.email ?? 'N/A',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.lock_outlined,
                            size: 16,
                            color: colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      context.tr('email_cannot_change'),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}