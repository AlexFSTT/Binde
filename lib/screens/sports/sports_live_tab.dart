import 'package:flutter/material.dart';
import '../../../models/sports_event_model.dart';
import '../../../services/sports_service.dart';
import 'sports_live_player_screen.dart';

class SportsLiveTab extends StatefulWidget {
  const SportsLiveTab({super.key});

  @override
  State<SportsLiveTab> createState() => _SportsLiveTabState();
}

class _SportsLiveTabState extends State<SportsLiveTab> {
  final SportsService _sportsService = SportsService();

  List<SportsEvent> _events = [];
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
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<SportsEvent> events;
      if (_selectedSport == 'all') {
        events = await _sportsService.getAllEvents();
      } else {
        events = await _sportsService.getEventsBySport(_selectedSport);
      }

      setState(() {
        _events = events;
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

    // Separă evenimentele în categorii
    final liveEvents = _events.where((e) => e.isLive).toList();
    final upcomingEvents = _events.where((e) => e.eventStatus == 'upcoming').toList();
    final finishedEvents = _events.where((e) => e.eventStatus == 'finished').toList();

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
                    _loadEvents();
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

        // Lista evenimente
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorView()
                  : _events.isEmpty
                      ? _buildEmptyView()
                      : RefreshIndicator(
                          onRefresh: _loadEvents,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // LIVE
                              if (liveEvents.isNotEmpty) ...[
                                _buildSectionHeader('🔴 LIVE ACUM', Colors.red),
                                ...liveEvents.map((e) => _buildEventCard(e, colorScheme)),
                                const SizedBox(height: 16),
                              ],

                              // UPCOMING
                              if (upcomingEvents.isNotEmpty) ...[
                                _buildSectionHeader('⏰ În curând', Colors.orange),
                                ...upcomingEvents.map((e) => _buildEventCard(e, colorScheme)),
                                const SizedBox(height: 16),
                              ],

                              // FINISHED
                              if (finishedEvents.isNotEmpty) ...[
                                _buildSectionHeader('✓ Încheiate', Colors.grey),
                                ...finishedEvents.map((e) => _buildEventCard(e, colorScheme)),
                              ],
                            ],
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
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
          ElevatedButton(onPressed: _loadEvents, child: const Text('Încearcă din nou')),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.live_tv, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Nu există evenimente disponibile.'),
        ],
      ),
    );
  }

  Widget _buildEventCard(SportsEvent event, ColorScheme colorScheme) {
    final sportColor = _getSportColor(event.sportType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: event.isLive && event.streamUrl != null && event.streamUrl!.isNotEmpty
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SportsLivePlayerScreen(event: event),
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header cu sport și status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sportColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getSportIcon(event.sportType), size: 14, color: sportColor),
                        const SizedBox(width: 4),
                        Text(
                          event.sportName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: sportColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (event.isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      event.statusDisplay,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Titlu / Echipe
              if (event.homeTeam != null && event.awayTeam != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.homeTeam!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        event.scoreDisplay,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        event.awayTeam!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              if (event.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  event.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Footer
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    event.formattedStartTime,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const Spacer(),
                  if (event.isLive && event.streamUrl != null && event.streamUrl!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Urmărește',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
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