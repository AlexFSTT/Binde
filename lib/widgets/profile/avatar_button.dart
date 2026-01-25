
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../screens/profile/profile_screen.dart';
import '../../services/profile_service.dart';

/// Widget pentru butonul avatar din header
class AvatarButton extends StatefulWidget {
  final double size;
  
  const AvatarButton({
    super.key,
    this.size = 36,
  });

  @override
  State<AvatarButton> createState() => _AvatarButtonState();
}

class _AvatarButtonState extends State<AvatarButton> {
  final _profileService = ProfileService();
  String? _avatarUrl;
  String _initials = 'U';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.getCurrentProfile();
    final user = supabase.auth.currentUser;
    
    if (mounted) {
      setState(() {
        _avatarUrl = profile?['avatar_url'];
        final fullName = profile?['full_name'] ?? 
                        user?.userMetadata?['full_name'] ?? 
                        '';
        _initials = _getInitials(fullName);
      });
    }
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
          );
          // Reîncarcă profilul dacă s-a modificat ceva
          if (result == true) {
            _loadProfile();
          }
        },
        child: CircleAvatar(
          radius: widget.size / 2,
          backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
          backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
          child: _avatarUrl == null
              ? Text(
                  _initials,
                  style: TextStyle(
                    fontSize: widget.size * 0.4,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Widget simplificat care se actualizează automat (folosind un key pentru refresh)
class AvatarButtonRefreshable extends StatelessWidget {
  final double size;
  final Key? refreshKey;

  const AvatarButtonRefreshable({
    super.key,
    this.size = 36,
    this.refreshKey,
  });

  @override
  Widget build(BuildContext context) {
    return AvatarButton(key: refreshKey, size: size);
  }
}