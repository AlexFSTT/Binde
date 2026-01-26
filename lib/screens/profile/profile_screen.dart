import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../providers/settings_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _authService = AuthService();
  final _profileService = ProfileService();

  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final profile = await _profileService.getCurrentProfile();
    setState(() {
      _profile = profile;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);

    final fullName = _profile?['full_name'] ?? 
                     user?.userMetadata?['full_name'] ?? 
                     'Utilizator';
    final bio = _profile?['bio'];
    final avatarUrl = _profile?['avatar_url'];
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('my_profile')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? Text(
                              _getInitials(fullName),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            )
                          : null,
                    ),

                    const SizedBox(height: 16),

                    // Nume
                    Text(
                      fullName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),

                    const SizedBox(height: 4),

                    // Email
                    Text(
                      email,
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),

                    // Bio
                    if (bio != null && bio.toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          bio.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.8),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Opțiuni profil
                    _buildProfileOption(
                      context,
                      icon: Icons.edit,
                      title: context.tr('edit_profile'),
                      onTap: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditProfileScreen(),
                          ),
                        );
                        if (result == true) {
                          _loadProfile();
                        }
                      },
                    ),

                    _buildProfileOption(
                      context,
                      icon: Icons.notifications_outlined,
                      title: context.tr('notifications'),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.tr('coming_soon'))),
                        );
                      },
                    ),

                    _buildProfileOption(
                      context,
                      icon: Icons.language,
                      title: context.tr('language'),
                      subtitle: settings.languageCode == null 
                          ? '${context.currentLanguage} (${context.tr('theme_auto').toLowerCase()})'
                          : context.currentLanguage,
                      onTap: () => _showLanguageDialog(context),
                    ),

                    _buildProfileOption(
                      context,
                      icon: Icons.dark_mode_outlined,
                      title: context.tr('theme'),
                      subtitle: _getThemeSubtitle(settings.themeMode),
                      onTap: () => _showThemeDialog(context),
                    ),

                    _buildProfileOption(
                      context,
                      icon: Icons.help_outline,
                      title: context.tr('help_support'),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.tr('coming_soon'))),
                        );
                      },
                    ),

                    _buildProfileOption(
                      context,
                      icon: Icons.info_outline,
                      title: context.tr('about_app'),
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'Binde',
                          applicationVersion: '1.2.0',
                          applicationIcon: Icon(
                            Icons.rocket_launch,
                            size: 48,
                            color: colorScheme.primary,
                          ),
                          children: const [
                            Text(
                              'Aplicația ta all-in-one pentru chat, învățare, video-uri, shopping, sporturi și jocuri.',
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    const Divider(),

                    const SizedBox(height: 16),

                    // Buton logout
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(context.tr('logout')),
                              content: Text(context.tr('logout_confirm')),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: Text(context.tr('cancel')),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(context.tr('logout_button')),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await _authService.signOut();
                            if (context.mounted) {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.logout),
                        label: Text(context.tr('logout')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurface.withValues(alpha: 0.5),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  String _getThemeSubtitle(ThemeModeOption mode) {
    switch (mode) {
      case ThemeModeOption.system:
        return context.tr('theme_auto');
      case ThemeModeOption.light:
        return context.tr('theme_light');
      case ThemeModeOption.dark:
        return context.tr('theme_dark');
    }
  }

  void _showLanguageDialog(BuildContext context) {
    final settings = ref.read(settingsProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.translate),
              title: Text(context.tr('theme_auto')),
              subtitle: const Text('Detectează automat'),
              trailing: settings.languageCode == null 
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setLanguage(null);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Text('🇷🇴', style: TextStyle(fontSize: 24)),
              title: const Text('Română'),
              trailing: settings.languageCode == 'ro'
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setLanguage('ro');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
              title: const Text('English'),
              trailing: settings.languageCode == 'en'
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setLanguage('en');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final settings = ref.read(settingsProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('theme')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: Text(context.tr('theme_auto')),
              subtitle: Text(context.tr('theme_system')),
              trailing: settings.themeMode == ThemeModeOption.system
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setThemeMode(ThemeModeOption.system);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: Text(context.tr('theme_light')),
              trailing: settings.themeMode == ThemeModeOption.light
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setThemeMode(ThemeModeOption.light);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: Text(context.tr('theme_dark')),
              trailing: settings.themeMode == ThemeModeOption.dark
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setThemeMode(ThemeModeOption.dark);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }
}
