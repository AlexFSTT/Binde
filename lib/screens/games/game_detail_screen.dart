import 'package:flutter/material.dart';
import '../../models/game_model.dart';

class GameDetailScreen extends StatelessWidget {
  final Game game;

  const GameDetailScreen({
    super.key,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categoryColor = _getCategoryColor(game.category);

    return Scaffold(
      appBar: AppBar(
        title: Text(game.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header cu icon
            Container(
              width: double.infinity,
              height: 200,
              color: categoryColor.withValues(alpha: 0.2),
              child: Center(
                child: Icon(
                  _getCategoryIcon(game.category),
                  size: 100,
                  color: categoryColor,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categorie
                  if (game.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        game.category!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: categoryColor,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Nume joc
                  Text(
                    game.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),

                  const SizedBox(height: 12),

                  // Descriere
                  if (game.description != null)
                    Text(
                      game.description!,
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Mesaj "Coming Soon"
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.construction,
                          size: 48,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'În dezvoltare',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Acest joc va fi disponibil în curând!\nRevino mai târziu pentru a juca.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Buton Play (dezactivat)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: null, // Dezactivat
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Joacă (În curând)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: colorScheme.primary.withValues(alpha: 0.3),
                        disabledForegroundColor: Colors.white70,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Buton Notificare
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Vei fi notificat când ${game.name} va fi disponibil!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.notifications_active),
                      label: const Text('Notifică-mă când e gata'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'quiz':
        return Icons.quiz;
      case 'puzzle':
        return Icons.extension;
      case 'words':
        return Icons.abc;
      case 'arcade':
        return Icons.videogame_asset;
      default:
        return Icons.sports_esports;
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'quiz':
        return Colors.orange;
      case 'puzzle':
        return Colors.blue;
      case 'words':
        return Colors.green;
      case 'arcade':
        return Colors.purple;
      default:
        return Colors.indigo;
    }
  }
}
