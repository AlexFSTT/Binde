import 'package:flutter/material.dart';
import '../../../models/sports_news_model.dart';
import '../../../services/sports_service.dart';
import 'sports_news_detail_screen.dart';

class SportsNewsTab extends StatefulWidget {
  const SportsNewsTab({super.key});

  @override
  State<SportsNewsTab> createState() => _SportsNewsTabState();
}

class _SportsNewsTabState extends State<SportsNewsTab> {
  final SportsService _sportsService = SportsService();

  List<SportsNews> _news = [];
  String _selectedSport = 'all';
  bool _isLoading = true;
  String? _error;

  final List<Map<String, dynamic>> _sports = [
    {'id': 'all', 'name': 'Toate', 'icon': Icons.sports},
    {'id': 'football', 'name': 'Fotbal', 'icon': Icons.sports_soccer},
    {'id': 'f1', 'name': 'F1', 'icon': Icons.directions_car},
    {'id': 'tennis', 'name': 'Tenis', 'icon': Icons.sports_tennis},
  ];

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<SportsNews> news;
      if (_selectedSport == 'all') {
        news = await _sportsService.getAllNews();
      } else {
        news = await _sportsService.getNewsBySport(_selectedSport);
      }

      setState(() {
        _news = news;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Filtre sporturi
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _sports.length,
            itemBuilder: (context, index) {
              final sport = _sports[index];
              final isSelected = _selectedSport == sport['id'];

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: Icon(
                    sport['icon'] as IconData,
                    size: 18,
                    color: isSelected ? Colors.white : colorScheme.primary,
                  ),
                  label: Text(sport['name'] as String),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedSport = sport['id'] as String);
                    _loadNews();
                  },
                  selectedColor: colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : colorScheme.onSurface,
                  ),
                ),
              );
            },
          ),
        ),

        // Lista de știri
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorView()
                  : _news.isEmpty
                      ? _buildEmptyView()
                      : RefreshIndicator(
                          onRefresh: _loadNews,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _news.length,
                            itemBuilder: (context, index) {
                              return _buildNewsCard(_news[index], colorScheme);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error ?? 'Eroare necunoscută'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadNews, child: const Text('Încearcă din nou')),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.newspaper, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Nu există știri disponibile.'),
        ],
      ),
    );
  }

  Widget _buildNewsCard(SportsNews news, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SportsNewsDetailScreen(news: news),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon sport
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getSportColor(news.sportType).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getSportIcon(news.sportType),
                  color: _getSportColor(news.sportType),
                ),
              ),

              const SizedBox(width: 12),

              // Conținut
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sport + timp
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getSportColor(news.sportType).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            news.sportName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getSportColor(news.sportType),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          news.timeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Titlu
                    Text(
                      news.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (news.summary != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        news.summary!,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    if (news.source != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        news.source!,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getSportIcon(String sportType) {
    switch (sportType) {
      case 'football':
        return Icons.sports_soccer;
      case 'f1':
        return Icons.directions_car;
      case 'tennis':
        return Icons.sports_tennis;
      default:
        return Icons.sports;
    }
  }

  Color _getSportColor(String sportType) {
    switch (sportType) {
      case 'football':
        return Colors.green;
      case 'f1':
        return Colors.red;
      case 'tennis':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}