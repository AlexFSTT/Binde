/// Model pentru un eveniment sportiv live
class SportsEvent {
  final String id;
  final String title;
  final String? description;
  final String sportType;
  final String? streamUrl;
  final String? thumbnailUrl;
  final String? homeTeam;
  final String? awayTeam;
  final int homeScore;
  final int awayScore;
  final String eventStatus; // 'upcoming', 'live', 'finished'
  final DateTime startTime;
  final DateTime? endTime;
  final bool isLive;
  final int viewersCount;
  final DateTime createdAt;

  SportsEvent({
    required this.id,
    required this.title,
    this.description,
    required this.sportType,
    this.streamUrl,
    this.thumbnailUrl,
    this.homeTeam,
    this.awayTeam,
    this.homeScore = 0,
    this.awayScore = 0,
    this.eventStatus = 'upcoming',
    required this.startTime,
    this.endTime,
    this.isLive = false,
    this.viewersCount = 0,
    required this.createdAt,
  });

  factory SportsEvent.fromJson(Map<String, dynamic> json) {
    return SportsEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      sportType: json['sport_type'] as String,
      streamUrl: json['stream_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      homeTeam: json['home_team'] as String?,
      awayTeam: json['away_team'] as String?,
      homeScore: json['home_score'] as int? ?? 0,
      awayScore: json['away_score'] as int? ?? 0,
      eventStatus: json['event_status'] as String? ?? 'upcoming',
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      isLive: json['is_live'] as bool? ?? false,
      viewersCount: json['viewers_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'sport_type': sportType,
      'stream_url': streamUrl,
      'thumbnail_url': thumbnailUrl,
      'home_team': homeTeam,
      'away_team': awayTeam,
      'home_score': homeScore,
      'away_score': awayScore,
      'event_status': eventStatus,
      'start_time': startTime.toIso8601String(),
      'is_live': isLive,
    };
  }

  /// Numele complet al sportului
  String get sportName {
    switch (sportType) {
      case 'football':
        return 'Fotbal';
      case 'f1':
        return 'Formula 1';
      case 'tennis':
        return 'Tenis';
      default:
        return sportType;
    }
  }

  /// Scorul formatat
  String get scoreDisplay {
    if (homeTeam != null && awayTeam != null) {
      return '$homeScore - $awayScore';
    }
    return '';
  }

  /// Status formatat
  String get statusDisplay {
    switch (eventStatus) {
      case 'live':
        return '🔴 LIVE';
      case 'upcoming':
        return '⏰ În curând';
      case 'finished':
        return '✓ Terminat';
      default:
        return eventStatus;
    }
  }

  /// Ora de start formatată
  String get formattedStartTime {
    return '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
  }

  /// Vizualizări formatate
  String get formattedViewers {
    if (viewersCount >= 1000000) {
      return '${(viewersCount / 1000000).toStringAsFixed(1)}M';
    } else if (viewersCount >= 1000) {
      return '${(viewersCount / 1000).toStringAsFixed(1)}K';
    }
    return viewersCount.toString();
  }
}