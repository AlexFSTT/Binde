import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';

/// Renders a location message as a static map preview with tap to open Google Maps
class LocationBubble extends StatelessWidget {
  final String locationName;
  final double latitude;
  final double longitude;
  final bool isMine;
  final ColorScheme colorScheme;

  const LocationBubble({
    super.key,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.isMine,
    required this.colorScheme,
  });

  void _openInMaps() async {
    final url = LocationService.googleMapsUrl(latitude, longitude, label: locationName);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapUrl = LocationService.staticMapUrl(
      lat: latitude,
      lng: longitude,
      width: 400,
      height: 200,
      zoom: 15,
    );

    return GestureDetector(
      onTap: _openInMaps,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map preview
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Image.network(
              mapUrl,
              width: 250,
              height: 140,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: 250,
                  height: 140,
                  color: colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (context, error, stack) {
                return Container(
                  width: 250,
                  height: 140,
                  color: colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Icon(
                      Icons.map_outlined,
                      size: 40,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                );
              },
            ),
          ),

          // Location name + open button
          Container(
            width: 250,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.location_on,
                    size: 18, color: colorScheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    locationName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.open_in_new,
                    size: 16,
                    color: colorScheme.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}