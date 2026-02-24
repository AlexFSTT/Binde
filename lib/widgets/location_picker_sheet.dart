import 'dart:async';
import 'package:flutter/material.dart';
import '../services/location_service.dart';

/// Reusable bottom sheet for picking a location via Google Places + GPS
/// Returns a [ResolvedLocation] or null if dismissed
class LocationPickerSheet extends StatefulWidget {
  final bool citiesOnly;
  final String? title;

  const LocationPickerSheet({
    super.key,
    this.citiesOnly = false,
    this.title,
  });

  /// Show the picker as a modal bottom sheet. Returns selected location or null.
  static Future<ResolvedLocation?> show(
    BuildContext context, {
    bool citiesOnly = false,
    String? title,
  }) {
    return showModalBottomSheet<ResolvedLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationPickerSheet(
        citiesOnly: citiesOnly,
        title: title,
      ),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<PlaceResult> _results = [];
  bool _isSearching = false;
  bool _isLoadingGps = false;
  bool _isResolvingPlace = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      final results = await LocationService.searchPlaces(
        query.trim(),
        citiesOnly: widget.citiesOnly,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _selectPlace(PlaceResult place) async {
    setState(() => _isResolvingPlace = true);
    final resolved = await LocationService.getPlaceDetails(place);
    if (mounted) {
      setState(() => _isResolvingPlace = false);
      if (resolved != null) {
        Navigator.pop(context, resolved);
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoadingGps = true);
    final location = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() => _isLoadingGps = false);
      if (location != null) {
        Navigator.pop(context, location);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get current location')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.title ?? 'Choose Location',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: widget.citiesOnly
                      ? 'Search city...'
                      : 'Search location...',
                  prefixIcon: const Icon(Icons.search, size: 22),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _results = []);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Use current location button
            if (!widget.citiesOnly)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isLoadingGps
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.my_location, color: cs.primary, size: 22),
                  ),
                  title: const Text('Use current location',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('Share your live GPS location',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.5))),
                  onTap: _isLoadingGps ? null : _useCurrentLocation,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

            // Loading / results
            if (_isSearching || _isResolvingPlace)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_results.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final place = _results[index];
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          widget.citiesOnly
                              ? Icons.location_city
                              : Icons.place_outlined,
                          color: cs.onSurface.withValues(alpha: 0.6),
                          size: 22,
                        ),
                      ),
                      title: Text(
                        place.mainText ?? place.description,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: place.secondaryText != null
                          ? Text(
                              place.secondaryText!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      cs.onSurface.withValues(alpha: 0.5)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onTap: () => _selectPlace(place),
                    );
                  },
                ),
              )
            else if (_searchController.text.length >= 2)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No results found',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ),

            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}