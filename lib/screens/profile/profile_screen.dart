import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../main.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final colorScheme = Theme.of(context).colorScheme;
    final authService = AuthService();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilul meu'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 50,
              backgroundColor: colorScheme.primary,
              child: Text(
                _getInitials(user?.userMetadata?['full_name'] ?? user?.email ?? 'U'),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Nume
            Text(
              user?.userMetadata?['full_name'] ?? 'Utilizator',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 4),
            
            // Email
            Text(
              user?.email ?? '',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Opțiuni profil
            _buildProfileOption(
              context,
              icon: Icons.edit,
              title: 'Editează profilul',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Editare profil - în curând!')),
                );
              },
            ),
            
            _buildProfileOption(
              context,
              icon: Icons.notifications_outlined,
              title: 'Notificări',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Setări notificări - în curând!')),
                );
              },
            ),
            
            _buildProfileOption(
              context,
              icon: Icons.dark_mode_outlined,
              title: 'Temă',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Schimbare temă - în curând!')),
                );
              },
            ),
            
            _buildProfileOption(
              context,
              icon: Icons.help_outline,
              title: 'Ajutor & Suport',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ajutor - în curând!')),
                );
              },
            ),
            
            _buildProfileOption(
              context,
              icon: Icons.info_outline,
              title: 'Despre aplicație',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Binde',
                  applicationVersion: '1.0.0',
                  applicationIcon: Icon(
                    Icons.rocket_launch,
                    size: 48,
                    color: colorScheme.primary,
                  ),
                  children: [
                    const Text('Dezvoltat de echipa Binde by AfterLife.Dev'),
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
                  // Confirmă logout
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Deconectare'),
                      content: const Text('Ești sigur că vrei să te deconectezi?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Anulează'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Deconectează-mă'),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirm == true) {
                    await authService.signOut();
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
                label: const Text('Deconectează-te'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfileOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListTile(
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(title),
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