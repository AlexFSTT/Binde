import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';

/// A place result from Google Places Autocomplete
class PlaceResult {
  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;

  PlaceResult({
    required this.placeId,
    required this.description,
    this.mainText,
    this.secondaryText,
  });
}

/// A resolved location with coordinates
class ResolvedLocation {
  final String name;
  final double latitude;
  final double longitude;
  final String? address;

  ResolvedLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

class LocationService {
  static String get _apiKey => AppConstants.googleMapsApiKey;

  // ============ GPS ============

  /// Check and request location permissions, then get current position
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permission denied');
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permission permanently denied');
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Error getting position: $e');
      return null;
    }
  }

  // ============ GOOGLE PLACES AUTOCOMPLETE ============

  /// Search places by query (for cities use types=(cities))
  static Future<List<PlaceResult>> searchPlaces(
    String query, {
    bool citiesOnly = false,
  }) async {
    if (query.trim().isEmpty || _apiKey.isEmpty) return [];

    final types = citiesOnly ? '&types=(cities)' : '';
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(query)}'
      '$types'
      '&key=$_apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      if (data['status'] != 'OK') return [];

      return (data['predictions'] as List).map((p) {
        final structured = p['structured_formatting'] ?? {};
        return PlaceResult(
          placeId: p['place_id'] as String,
          description: p['description'] as String,
          mainText: structured['main_text'] as String?,
          secondaryText: structured['secondary_text'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('Places autocomplete error: $e');
      return [];
    }
  }

  /// Get coordinates for a place ID
  static Future<ResolvedLocation?> getPlaceDetails(PlaceResult place) async {
    if (_apiKey.isEmpty) return null;

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=${place.placeId}'
      '&fields=geometry,formatted_address,name'
      '&key=$_apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      if (data['status'] != 'OK') return null;

      final result = data['result'];
      final loc = result['geometry']['location'];

      return ResolvedLocation(
        name: place.description,
        latitude: (loc['lat'] as num).toDouble(),
        longitude: (loc['lng'] as num).toDouble(),
        address: result['formatted_address'] as String?,
      );
    } catch (e) {
      debugPrint('Place details error: $e');
      return null;
    }
  }

  /// Reverse geocode: lat/lng → address name
  static Future<String?> reverseGeocode(double lat, double lng) async {
    if (_apiKey.isEmpty) return null;

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=$lat,$lng'
      '&key=$_apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      if (data['status'] != 'OK' || (data['results'] as List).isEmpty) {
        return null;
      }

      return data['results'][0]['formatted_address'] as String?;
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
      return null;
    }
  }

  /// Get current location as a ResolvedLocation
  static Future<ResolvedLocation?> getCurrentLocation() async {
    final position = await getCurrentPosition();
    if (position == null) return null;

    final address =
        await reverseGeocode(position.latitude, position.longitude);

    return ResolvedLocation(
      name: address ?? '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
      latitude: position.latitude,
      longitude: position.longitude,
      address: address,
    );
  }

  // ============ STATIC MAP URL ============

  /// Generate Google Static Maps URL for preview
  static String staticMapUrl({
    required double lat,
    required double lng,
    int width = 400,
    int height = 200,
    int zoom = 15,
  }) {
    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?center=$lat,$lng'
        '&zoom=$zoom'
        '&size=${width}x$height'
        '&scale=2'
        '&markers=color:red%7C$lat,$lng'
        '&key=$_apiKey';
  }

  /// Google Maps URL for opening in external app
  static String googleMapsUrl(double lat, double lng, {String? label}) {
    final q = label != null ? Uri.encodeComponent(label) : '$lat,$lng';
    return 'https://www.google.com/maps/search/?api=1&query=$q&center=$lat,$lng';
  }
}