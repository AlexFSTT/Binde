import 'package:flutter/material.dart';
import '../../models/game_model.dart';
import '../../services/game_service.dart';
import 'game_detail_screen.dart';

class GamesListScreen extends StatefulWidget {
  const GamesListScreen({super.key});

  @override
  State<GamesListScreen> createState() => _GamesListScreenState();
}

class _GamesListScreenState extends State<GamesListScreen> {
  final GameService _gameService = GameService();

  List<Game> _games = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _gameService.getGames(),
        _gameService.getCategories(),
      ]);

      setState(() {
        _games = results[0] as List<Game>;
        _categories = results[1] as List<String>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Game> get _filteredGames {
    if (_selectedCategory == null) {
      return _games;
    }
    return _games.where((g) => g.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Games'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Clasament - în curând!')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _games.isEmpty
                  ? _buildEmptyView()
                  : _buildGamesList(colorScheme),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Eroare la încărcare', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_error ?? 'Eroare necunoscută', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Încearcă din nou'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_esports_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text('Nu există jocuri disponibile.'),
        ],
      ),
    );
  }

  Widget _buildGamesList(ColorScheme colorScheme) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // Filtre categorii
          if (_categories.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('Toate'),
                      selected: _selectedCategory == null,
                      onSelected: (selected) {
                        setState(() => _selectedCategory = null);
                      },
                    ),
                  ),
                  ..._categories.map((category) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category),
                          selected: _selectedCategory == category,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = selected ? category : null;
                            });
                          },
                        ),
                      )),
                ],
              ),
            ),

          // Grid de jocuri
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _filteredGames.length,
              itemBuilder: (context, index) {
                final game = _filteredGames[index];
                return _buildGameCard(game, colorScheme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(Game game, ColorScheme colorScheme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameDetailScreen(game: game),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagine joc
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: _getCategoryColor(game.category).withValues(alpha: 0.2),
                child: Center(
                  child: Icon(
                    _getCategoryIcon(game.category),
                    size: 50,
                    color: _getCategoryColor(game.category),
                  ),
                ),
              ),
            ),

            // Detalii joc
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Categorie
                    if (game.category != null)
                      Text(
                        game.category!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getCategoryColor(game.category),
                        ),
                      ),

                    const SizedBox(height: 4),

                    // Nume
                    Text(
                      game.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const Spacer(),

                    // Buton Play
                    Row(
                      children: [
                        Icon(
                          Icons.play_arrow,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Joacă',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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