import 'package:flutter/material.dart';
import '../../../models/sports_news_model.dart';

class SportsNewsDetailScreen extends StatelessWidget {
  final SportsNews news;

  const SportsNewsDetailScreen({
    super.key,
    required this.news,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sportColor = _getSportColor(news.sportType);

    return Scaffold(
      appBar: AppBar(
        title: Text(news.sportName),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Distribuire - în curând!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header cu sport
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: sportColor.withValues(alpha: 0.1),
              child: Column(
                children: [
                  Icon(
                    _getSportIcon(news.sportType),
                    size: 60,
                    color: sportColor,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sportColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      news.sportName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timp și sursă
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        news.timeAgo,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      if (news.source != null) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.source,
                          size: 14,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          news.source!,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Titlu
                  Text(
                    news.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),

                  const SizedBox(height: 16),

                  // Summary
                  if (news.summary != null)
                    Text(
                      news.summary!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),

                  const SizedBox(height: 24),

                  const Divider(),

                  const SizedBox(height: 24),

                  // Conținut
                  if (news.content != null)
                    Text(
                      news.content!,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.7,
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Center(
                        child: Text('Conținutul complet va fi disponibil în curând.'),
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