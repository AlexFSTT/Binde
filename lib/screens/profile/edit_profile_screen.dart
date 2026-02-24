import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/profile_service.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/location_picker_sheet.dart';
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

  // Controlere de bază
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();

  // Controlere noi
  final _birthCityController = TextEditingController();
  final _currentCityController = TextEditingController();
  double? _birthCityLat;
  double? _birthCityLng;
  double? _currentCityLat;
  double? _currentCityLng;
  final _jobTitleController = TextEditingController();
  final _jobCompanyController = TextEditingController();
  final _relationshipPartnerController = TextEditingController();
  final _religionController = TextEditingController();
  final _languagesController = TextEditingController();
  final _websiteController = TextEditingController();
  final _schoolController = TextEditingController();
  final _favoriteSportsController = TextEditingController();
  final _favoriteTeamsController = TextEditingController();
  final _favoriteGamesController = TextEditingController();
  final _phoneController = TextEditingController();

  // Dropdowns
  String? _gender;
  String? _relationshipStatus;
  String _contactVisibility = 'friends';
  DateTime? _birthDate;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isUploadingCover = false;
  String? _avatarUrl;
  String? _coverUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _birthCityController.dispose();
    _currentCityController.dispose();
    _jobTitleController.dispose();
    _jobCompanyController.dispose();
    _relationshipPartnerController.dispose();
    _religionController.dispose();
    _languagesController.dispose();
    _websiteController.dispose();
    _schoolController.dispose();
    _favoriteSportsController.dispose();
    _favoriteTeamsController.dispose();
    _favoriteGamesController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    final profile = await _profileService.getCurrentProfile();

    if (profile != null) {
      _nameController.text = profile['full_name'] ?? '';
      _usernameController.text = profile['username'] ?? '';
      _bioController.text = profile['bio'] ?? '';
      _avatarUrl = profile['avatar_url'];
      _coverUrl = profile['cover_url'];
      _birthCityController.text = profile['birth_city'] ?? '';
      _currentCityController.text = profile['current_city'] ?? '';
      _birthCityLat = (profile['birth_city_lat'] as num?)?.toDouble();
      _birthCityLng = (profile['birth_city_lng'] as num?)?.toDouble();
      _currentCityLat = (profile['current_city_lat'] as num?)?.toDouble();
      _currentCityLng = (profile['current_city_lng'] as num?)?.toDouble();
      _jobTitleController.text = profile['job_title'] ?? '';
      _jobCompanyController.text = profile['job_company'] ?? '';
      _relationshipPartnerController.text = profile['relationship_partner'] ?? '';
      _religionController.text = profile['religion'] ?? '';
      _languagesController.text = profile['languages'] ?? '';
      _websiteController.text = profile['website'] ?? '';
      _schoolController.text = profile['school'] ?? '';
      _favoriteSportsController.text = profile['favorite_sports'] ?? '';
      _favoriteTeamsController.text = profile['favorite_teams'] ?? '';
      _favoriteGamesController.text = profile['favorite_games'] ?? '';
      _phoneController.text = profile['phone'] ?? '';
      _gender = profile['gender'];
      _relationshipStatus = profile['relationship_status'];
      _contactVisibility = profile['contact_visibility'] ?? 'friends';
      if (profile['birth_date'] != null) {
        _birthDate = DateTime.tryParse(profile['birth_date']);
      }
    } else {
      final user = supabase.auth.currentUser;
      _nameController.text = user?.userMetadata?['full_name'] ?? '';
    }

    setState(() => _isLoading = false);
  }

  // =====================================================
  // IMAGE UPLOADS
  // =====================================================

  Future<void> _pickAndUploadAvatar() async {
    final source = await _showImageSourceSheet();
    if (source == null && _avatarUrl != null) {
      await _deleteAvatar();
      return;
    }
    if (source == null) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: source, maxWidth: 512, maxHeight: 512, imageQuality: 75,
      );
      if (picked == null) return;

      setState(() => _isUploadingAvatar = true);
      final result = await _profileService.uploadAvatar(picked.path);
      setState(() => _isUploadingAvatar = false);

      if (!mounted) return;
      if (result.isSuccess) {
        setState(() => _avatarUrl = result.message);
        _showSnack(context.tr('avatar_updated'), true);
      } else {
        _showSnack(result.message, false);
      }
    } catch (e) {
      setState(() => _isUploadingAvatar = false);
      _showSnack('Error: $e', false);
    }
  }

  Future<void> _pickAndUploadCover() async {
    final source = await _showImageSourceSheet(showDelete: _coverUrl != null);
    if (source == null && _coverUrl != null) {
      await _deleteCover();
      return;
    }
    if (source == null) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: source, maxWidth: 1920, maxHeight: 1080, imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingCover = true);
      final result = await _profileService.uploadCover(picked.path);
      setState(() => _isUploadingCover = false);

      if (!mounted) return;
      if (result.isSuccess) {
        setState(() => _coverUrl = result.message);
        _showSnack(context.tr('cover_updated'), true);
      } else {
        _showSnack(result.message, false);
      }
    } catch (e) {
      setState(() => _isUploadingCover = false);
      _showSnack('Error: $e', false);
    }
  }

  Future<ImageSource?> _showImageSourceSheet({bool showDelete = false}) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(context.tr('camera')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(context.tr('gallery')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            if (showDelete)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(context.tr('delete'), style: const TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, null),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAvatar() async {
    setState(() => _isUploadingAvatar = true);
    final result = await _profileService.deleteAvatar();
    setState(() {
      _isUploadingAvatar = false;
      if (result.isSuccess) _avatarUrl = null;
    });
    _showSnack(result.message, result.isSuccess);
  }

  Future<void> _deleteCover() async {
    setState(() => _isUploadingCover = true);
    final result = await _profileService.deleteCover();
    setState(() {
      _isUploadingCover = false;
      if (result.isSuccess) _coverUrl = null;
    });
    _showSnack(result.message, result.isSuccess);
  }

  void _showSnack(String msg, bool success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? Colors.green : Colors.red),
    );
  }

  // =====================================================
  // SAVE
  // =====================================================

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final result = await _profileService.updateProfile(
      username: _usernameController.text.trim(),
      fullName: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      birthCity: _birthCityController.text.trim().isEmpty ? null : _birthCityController.text.trim(),
      birthCityLat: _birthCityLat,
      birthCityLng: _birthCityLng,
      birthDate: _birthDate?.toIso8601String().split('T').first,
      gender: _gender,
      currentCity: _currentCityController.text.trim().isEmpty ? null : _currentCityController.text.trim(),
      currentCityLat: _currentCityLat,
      currentCityLng: _currentCityLng,
      jobTitle: _jobTitleController.text.trim().isEmpty ? null : _jobTitleController.text.trim(),
      jobCompany: _jobCompanyController.text.trim().isEmpty ? null : _jobCompanyController.text.trim(),
      relationshipStatus: _relationshipStatus,
      relationshipPartner: _relationshipPartnerController.text.trim().isEmpty ? null : _relationshipPartnerController.text.trim(),
      religion: _religionController.text.trim().isEmpty ? null : _religionController.text.trim(),
      languages: _languagesController.text.trim().isEmpty ? null : _languagesController.text.trim(),
      website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      school: _schoolController.text.trim().isEmpty ? null : _schoolController.text.trim(),
      favoriteSports: _favoriteSportsController.text.trim().isEmpty ? null : _favoriteSportsController.text.trim(),
      favoriteTeams: _favoriteTeamsController.text.trim().isEmpty ? null : _favoriteTeamsController.text.trim(),
      favoriteGames: _favoriteGamesController.text.trim().isEmpty ? null : _favoriteGamesController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      contactVisibility: _contactVisibility,
    );

    setState(() => _isSaving = false);

    if (mounted) {
      _showSnack(
        result.isSuccess ? context.tr('profile_updated') : result.message,
        result.isSuccess,
      );
      if (result.isSuccess) Navigator.pop(context, true);
    }
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('edit_profile')),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(context.tr('save')),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ====== COVER + AVATAR ======
                    _buildCoverAndAvatar(cs),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),

                          // ====== BASIC INFO ======
                          _sectionTitle(context.tr('section_basic_info'), cs),
                          const SizedBox(height: 12),
                          _buildUsernameField(),
                          const SizedBox(height: 14),
                          _buildNameField(cs),
                          const SizedBox(height: 14),
                          _buildBioField(cs),
                          const SizedBox(height: 14),
                          _buildDropdown('Gender', _gender, ['Male', 'Female'], (v) => setState(() => _gender = v), cs),
                          const SizedBox(height: 14),
                          _buildDatePicker(cs),
                          const SizedBox(height: 14),
                          _buildEmailReadonly(cs),

                          const SizedBox(height: 28),

                          // ====== LOCATION ======
                          _sectionTitle(context.tr('section_location'), cs),
                          const SizedBox(height: 12),
                          _buildLocationField(
                            controller: _currentCityController,
                            label: context.tr('current_city'),
                            icon: Icons.location_on_outlined,
                            onPick: () => _pickCity(isBirth: false),
                            onClear: () => setState(() {
                              _currentCityController.clear();
                              _currentCityLat = null;
                              _currentCityLng = null;
                            }),
                          ),
                          const SizedBox(height: 14),
                          _buildLocationField(
                            controller: _birthCityController,
                            label: context.tr('hometown'),
                            icon: Icons.home_outlined,
                            onPick: () => _pickCity(isBirth: true),
                            onClear: () => setState(() {
                              _birthCityController.clear();
                              _birthCityLat = null;
                              _birthCityLng = null;
                            }),
                          ),

                          const SizedBox(height: 28),

                          // ====== WORK & EDUCATION ======
                          _sectionTitle(context.tr('section_work_education'), cs),
                          const SizedBox(height: 12),
                          _buildField(_jobTitleController, context.tr('job_title'), Icons.work_outline),
                          const SizedBox(height: 14),
                          _buildField(_jobCompanyController, context.tr('company'), Icons.business_outlined),
                          const SizedBox(height: 14),
                          _buildField(_schoolController, context.tr('school_university'), Icons.school_outlined),

                          const SizedBox(height: 28),

                          // ====== RELATIONSHIP ======
                          _sectionTitle(context.tr('section_relationship'), cs),
                          const SizedBox(height: 12),
                          _buildDropdown('Relationship status', _relationshipStatus, [
                            'Single', 'In a relationship', 'Engaged', 'Married',
                            'Complicated', 'Divorced', 'Widowed',
                          ], (v) => setState(() => _relationshipStatus = v), cs),
                          if (_relationshipStatus != null && _relationshipStatus != 'Single') ...[
                            const SizedBox(height: 14),
                            _buildField(_relationshipPartnerController, context.tr('partner_name'), Icons.favorite_outline),
                          ],

                          const SizedBox(height: 28),

                          // ====== ABOUT YOU ======
                          _sectionTitle(context.tr('section_about_you'), cs),
                          const SizedBox(height: 12),
                          _buildField(_religionController, context.tr('religion'), Icons.church_outlined),
                          const SizedBox(height: 14),
                          _buildField(_languagesController, context.tr('languages_spoken'), Icons.translate),

                          const SizedBox(height: 28),

                          // ====== INTERESTS ======
                          _sectionTitle(context.tr('section_interests'), cs),
                          const SizedBox(height: 12),
                          _buildField(_favoriteSportsController, context.tr('favorite_sports'), Icons.sports_soccer_outlined),
                          const SizedBox(height: 14),
                          _buildField(_favoriteTeamsController, context.tr('favorite_teams'), Icons.shield_outlined),
                          const SizedBox(height: 14),
                          _buildField(_favoriteGamesController, context.tr('favorite_video_games'), Icons.sports_esports_outlined),

                          const SizedBox(height: 28),

                          // ====== CONTACT & LINKS ======
                          _sectionTitle(context.tr('section_contact_links'), cs),
                          const SizedBox(height: 12),
                          _buildField(_phoneController, context.tr('phone_number'), Icons.phone_outlined),
                          const SizedBox(height: 14),
                          _buildField(_websiteController, context.tr('website_blog'), Icons.link),
                          const SizedBox(height: 14),
                          _buildDropdown('Contact visibility', _contactVisibility, [
                            'public', 'friends', 'private',
                          ], (v) => setState(() => _contactVisibility = v ?? 'friends'), cs),
                          const SizedBox(height: 6),
                          Text(
                            context.tr('contact_visibility_hint'),
                            style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.4)),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // =====================================================
  // COVER + AVATAR HEADER
  // =====================================================

  Widget _buildCoverAndAvatar(ColorScheme cs) {
    return SizedBox(
      height: 240,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Cover photo
          GestureDetector(
            onTap: _isUploadingCover ? null : _pickAndUploadCover,
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
              ),
              child: _isUploadingCover
                  ? const Center(child: CircularProgressIndicator())
                  : _coverUrl != null
                      ? Image.network(_coverUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildCoverPlaceholder(cs))
                      : _buildCoverPlaceholder(cs),
            ),
          ),
          // Camera icon pe cover
          Positioned(
            bottom: 68,
            right: 12,
            child: GestureDetector(
              onTap: _isUploadingCover ? null : _pickAndUploadCover,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
                ),
                child: Icon(Icons.camera_alt, size: 18, color: cs.onSurface.withValues(alpha: 0.7)),
              ),
            ),
          ),
          // Avatar
          Positioned(
            bottom: 0,
            left: 16,
            child: GestureDetector(
              onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surface, width: 4),
                ),
                child: _isUploadingAvatar
                    ? CircleAvatar(
                        radius: 46,
                        backgroundColor: cs.primaryContainer,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : CircleAvatar(
                        radius: 46,
                        backgroundColor: cs.primaryContainer,
                        backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                        child: _avatarUrl == null
                            ? Text(
                                _getInitials(_nameController.text),
                                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
                              )
                            : null,
                      ),
              ),
            ),
          ),
          // Camera icon pe avatar
          Positioned(
            bottom: 2,
            left: 78,
            child: GestureDetector(
              onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surface, width: 2),
                ),
                child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverPlaceholder(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 36, color: cs.onSurface.withValues(alpha: 0.25)),
          const SizedBox(height: 4),
          Text(context.tr('add_cover_photo'), style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  // =====================================================
  // FIELD HELPERS
  // =====================================================

  Widget _sectionTitle(String title, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: cs.outline.withValues(alpha: 0.1)),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface.withValues(alpha: 0.8))),
      ],
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        isDense: true,
      ),
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return GestureDetector(
      onTap: onPick,
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: onClear,
                  )
                : const Icon(Icons.search, size: 18),
            isDense: true,
          ),
        ),
      ),
    );
  }

  Future<void> _pickCity({required bool isBirth}) async {
    final location = await LocationPickerSheet.show(
      context,
      citiesOnly: true,
      title: isBirth ? context.tr('hometown') : context.tr('current_city'),
    );
    if (location != null && mounted) {
      setState(() {
        if (isBirth) {
          _birthCityController.text = location.name;
          _birthCityLat = location.latitude;
          _birthCityLng = location.longitude;
        } else {
          _currentCityController.text = location.name;
          _currentCityLat = location.latitude;
          _currentCityLng = location.longitude;
        }
      });
    }
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      decoration: InputDecoration(
        labelText: context.tr('username'),
        hintText: context.tr('username_hint'),
        prefixText: '@',
        prefixIcon: Icon(Icons.alternate_email),
      ),
      maxLength: 30,
      validator: (value) {
        if (value == null || value.trim().isEmpty) return context.tr('username_required');
        if (value.trim().length < 3) return context.tr('username_min_length');
        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) return context.tr('username_invalid');
        return null;
      },
    );
  }

  Widget _buildNameField(ColorScheme cs) {
    return TextFormField(
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: context.tr('full_name'),
        prefixIcon: const Icon(Icons.person_outlined),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return context.tr('name_required');
        if (value.trim().length < 2) return context.tr('name_min_length');
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildBioField(ColorScheme cs) {
    return TextFormField(
      controller: _bioController,
      maxLines: 3,
      maxLength: 200,
      decoration: InputDecoration(
        labelText: context.tr('bio'),
        hintText: context.tr('bio_hint'),
        prefixIcon: const Icon(Icons.info_outlined),
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged, ColorScheme cs) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
      ),
      items: [
        DropdownMenuItem<String>(value: null, child: Text('Not set', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)))),
        ...items.map((item) => DropdownMenuItem(value: item, child: Text(item))),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildDatePicker(ColorScheme cs) {
    return InkWell(
      onTap: _pickBirthDate,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.tr('birth_date'),
          prefixIcon: Icon(Icons.cake_outlined),
          isDense: true,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _birthDate != null
                    ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                    : context.tr('not_set'),
                style: TextStyle(
                  color: _birthDate != null ? cs.onSurface : cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
            if (_birthDate != null)
              GestureDetector(
                onTap: () => setState(() => _birthDate = null),
                child: Icon(Icons.close, size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailReadonly(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.email_outlined, color: cs.onSurface.withValues(alpha: 0.4), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('email'), style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4))),
                Text(supabase.auth.currentUser?.email ?? 'N/A', style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
          Icon(Icons.lock_outlined, size: 14, color: cs.onSurface.withValues(alpha: 0.25)),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }
}