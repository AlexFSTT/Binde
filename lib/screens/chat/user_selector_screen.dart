import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../services/chat_service.dart';
import 'chat_detail_screen.dart';

/// Model simplu pentru un utilizator din lista de selectare
class UserProfile {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final String? bio;

  UserProfile({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.bio,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Unknown User',
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
    );
  }
}

/// Ecran pentru selectarea unui utilizator cu care să începi o conversație
class UserSelectorScreen extends StatefulWidget {
  const UserSelectorScreen({super.key});

  @override
  State<UserSelectorScreen> createState() => _UserSelectorScreenState();
}

class _UserSelectorScreenState extends State<UserSelectorScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ChatService _chatService = ChatService();
  
  List<UserProfile> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  /// Încarcă toți utilizatorii din Supabase (minus utilizatorul curent)
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Căutăm toți utilizatorii din tabela profiles, EXCEPTÂND utilizatorul curent
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url, bio')
          .neq('id', currentUserId)
          .order('full_name', ascending: true);

      final users = (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Începe o conversație cu utilizatorul selectat
  Future<void> _startConversation(UserProfile user) async {
    // Afișăm un indicator de loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Găsim sau creăm conversația cu acest utilizator
      final conversation = await _chatService.getOrCreateConversation(user.id);
      
      // Închidem loading-ul
      if (mounted) {
        Navigator.pop(context);
      }

      // Navigăm la ecranul de chat
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              conversation: conversation,
            ),
          ),
        );
      }
    } catch (e) {
      // Închidem loading-ul
      if (mounted) {
        Navigator.pop(context);
      }

      // Afișăm eroarea
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('error')}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('new_message')),
      ),
      body: _buildBody(colorScheme),
    );
  }

  /// Construiește corpul ecranului în funcție de stare
  Widget _buildBody(ColorScheme colorScheme) {
    // Dacă se încarcă, afișăm un indicator de loading
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Dacă există o eroare, afișăm mesajul de eroare
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('error_loading'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh),
              label: Text(context.tr('retry')),
            ),
          ],
        ),
      );
    }

    // Dacă nu există utilizatori, afișăm un mesaj informativ
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('no_users'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('no_users_message'),
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Afișăm lista de utilizatori
    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return _buildUserItem(user, colorScheme);
      },
    );
  }

  /// Construiește un item din lista de utilizatori
  Widget _buildUserItem(UserProfile user, ColorScheme colorScheme) {
    return ListTile(
      // Avatar-ul utilizatorului
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: colorScheme.primaryContainer,
        backgroundImage: user.avatarUrl != null
            ? NetworkImage(user.avatarUrl!)
            : null,
        child: user.avatarUrl == null
            ? Text(
                user.fullName[0].toUpperCase(),
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
            : null,
      ),
      // Numele utilizatorului
      title: Text(
        user.fullName,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      // Bio-ul utilizatorului (dacă există)
      subtitle: user.bio != null
          ? Text(
              user.bio!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            )
          : null,
      // Iconița pentru a începe chat-ul
      trailing: Icon(
        Icons.chat_bubble_outline,
        color: colorScheme.primary,
      ),
      // La tap, începem conversația
      onTap: () => _startConversation(user),
    );
  }
}