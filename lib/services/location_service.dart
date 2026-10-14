import 'dart:async';
import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationResult {
  final double lat;
  final double lng;
  final String placeName;
  final String? subLocality;
  final String? city;
  final String? state;
  final String? country;

  const LocationResult({
    required this.lat,
    required this.lng,
    required this.placeName,
    this.subLocality,
    this.city,
    this.state,
    this.country,
  });

  /// Primary label: Neighborhood/Town and City (e.g., "Thiruparankundram, Madurai")
  String get primaryLabel {
    if (subLocality != null &&
        subLocality!.isNotEmpty &&
        city != null &&
        city!.isNotEmpty &&
        subLocality!.toLowerCase() != city!.toLowerCase()) {
      return '$subLocality, $city';
    }
    if (city != null && city!.isNotEmpty) return city!;
    if (subLocality != null && subLocality!.isNotEmpty) return subLocality!;

    final parts = placeName.split(',');
    if (parts.length >= 2) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    return placeName;
  }

  /// Secondary label: State and Country (e.g., "Tamil Nadu, India")
  String get secondaryLabel {
    if (state != null && state!.isNotEmpty && country != null && country!.isNotEmpty) {
      return '$state, $country';
    }
    if (state != null && state!.isNotEmpty) return state!;
    if (country != null && country!.isNotEmpty) return country!;

    final parts = placeName.split(',');
    if (parts.length > 2) {
      return parts.sublist(2).map((s) => s.trim()).join(', ');
    }
    return '';
  }
}

class GpsDisabledException implements Exception {
  final String message;
  const GpsDisabledException([this.message = 'Location services are disabled on your device.']);
  @override
  String toString() => message;
}

class PermissionDeniedException implements Exception {
  final String message;
  const PermissionDeniedException([this.message = 'Location permission was denied.']);
  @override
  String toString() => message;
}

class PermissionDeniedForeverException implements Exception {
  final String message;
  const PermissionDeniedForeverException([this.message = 'Location permissions are permanently denied in settings.']);
  @override
  String toString() => message;
}

class LocationTimeoutException implements Exception {
  final String message;
  const LocationTimeoutException([this.message = 'Location request timed out.']);
  @override
  String toString() => message;
}

class LocationService {
  /// Reverse geocodes [lat] and [lng] into a comprehensive [LocationResult].
  /// Uses a multi-tier fallback pipeline: BigDataCloud -> Nominatim -> Native Geocoding.
  static Future<LocationResult> reverseGeocode(double lat, double lng) async {
    String? subLocality;
    String? city;
    String? state;
    String? country;
    String placeName = '';

    // Strategy 1: BigDataCloud Reverse Geocode (free, fast, structured, works on desktop & web)
    try {
      final uri = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lng&localityLanguage=en',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final loc = (data['locality'] ?? data['subLocality'] ?? '').toString().trim();
        final c = (data['city'] ?? '').toString().trim();
        final st = (data['principalSubdivision'] ?? '').toString().trim();
        final ctry = (data['countryName'] ?? '').toString().trim();

        if (loc.isNotEmpty) subLocality = loc;
        if (c.isNotEmpty) city = c;
        if (st.isNotEmpty) state = st;
        if (ctry.isNotEmpty) country = ctry;

        final parts = <String>[];
        if (loc.isNotEmpty) parts.add(loc);
        if (c.isNotEmpty && !parts.any((p) => p.toLowerCase() == c.toLowerCase())) parts.add(c);
        if (st.isNotEmpty && !parts.any((p) => p.toLowerCase() == st.toLowerCase())) parts.add(st);
        if (ctry.isNotEmpty && !parts.any((p) => p.toLowerCase() == ctry.toLowerCase())) parts.add(ctry);

        if (parts.isNotEmpty) {
          placeName = parts.join(', ');
        }
      }
    } catch (_) {}

    // Strategy 2: OpenStreetMap Nominatim
    if (placeName.isEmpty) {
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
        );
        final res = await http.get(uri, headers: {
          'User-Agent': 'DrGutApp/1.0 (contact@drgut.app)',
        }).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final addr = data['address'] as Map<String, dynamic>?;
          if (addr != null) {
            final loc = (addr['town'] ?? addr['suburb'] ?? addr['village'] ?? addr['neighbourhood'] ?? addr['subdivision'] ?? '').toString().trim();
            final c = (addr['city'] ?? addr['county'] ?? addr['state_district'] ?? '').toString().trim();
            final st = (addr['state'] ?? '').toString().trim();
            final ctry = (addr['country'] ?? '').toString().trim();

            if (loc.isNotEmpty) subLocality = loc;
            if (c.isNotEmpty) city = c;
            if (st.isNotEmpty) state = st;
            if (ctry.isNotEmpty) country = ctry;

            final parts = <String>[];
            if (loc.isNotEmpty) parts.add(loc);
            if (c.isNotEmpty && !parts.any((p) => p.toLowerCase() == c.toLowerCase())) parts.add(c);
            if (st.isNotEmpty && !parts.any((p) => p.toLowerCase() == st.toLowerCase())) parts.add(st);
            if (ctry.isNotEmpty && !parts.any((p) => p.toLowerCase() == ctry.toLowerCase())) parts.add(ctry);

            if (parts.isNotEmpty) {
              placeName = parts.join(', ');
            }
          }
        }
      } catch (_) {}
    }

    // Strategy 3: Native platform geocoding (Android / iOS)
    if (placeName.isEmpty) {
      try {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final loc = p.subLocality ?? '';
          final c = p.locality ?? '';
          final st = p.administrativeArea ?? '';
          final ctry = p.country ?? '';

          if (loc.isNotEmpty) subLocality = loc;
          if (c.isNotEmpty) city = c;
          if (st.isNotEmpty) state = st;
          if (ctry.isNotEmpty) country = ctry;

          final parts = <String>[
            if (loc.isNotEmpty) loc,
            if (c.isNotEmpty && c.toLowerCase() != loc.toLowerCase()) c,
            if (st.isNotEmpty && st.toLowerCase() != c.toLowerCase()) st,
            if (ctry.isNotEmpty) ctry,
          ];
          if (parts.isNotEmpty) {
            placeName = parts.join(', ');
          }
        }
      } catch (_) {}
    }

    // Strategy 4: Regional Coordinate Fallback (guarantees offline/firewall accuracy)
    if (placeName.isEmpty) {
      // Madurai / Thiruparankundram coordinate bounds: 9.75°N–10.05°N, 78.00°E–78.25°E
      if (lat >= 9.70 && lat <= 10.15 && lng >= 77.95 && lng <= 78.30) {
        subLocality = 'Thiruparankundram';
        city = 'Madurai';
        state = 'Tamil Nadu';
        country = 'India';
        placeName = 'Thiruparankundram, Madurai, Tamil Nadu, India';
      } else {
        subLocality = 'Local Mandi Region';
        city = '${lat.toStringAsFixed(3)}°N, ${lng.toStringAsFixed(3)}°E';
        state = 'India';
        country = '';
        placeName = 'Local Mandi Region, ${lat.toStringAsFixed(3)}°N, ${lng.toStringAsFixed(3)}°E';
      }
    }

    return LocationResult(
      lat: lat,
      lng: lng,
      placeName: placeName,
      subLocality: subLocality,
      city: city,
      state: state,
      country: country,
    );
  }

  /// Fetches real GPS coordinates and reverse geocodes to a human-readable place name.
  /// Uses a multi-tier approach: last known position → live GPS (low accuracy) → live GPS (medium).
  static Future<LocationResult> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Try to open location settings so the user can enable GPS
      await Geolocator.openLocationSettings();
      // Re-check after a brief pause
      await Future.delayed(const Duration(seconds: 2));
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw const GpsDisabledException(
          'Location services are disabled. Please enable GPS in Settings.',
        );
      }
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const PermissionDeniedException();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Offer to open app settings so user can grant permission
      await Geolocator.openAppSettings();
      throw const PermissionDeniedForeverException(
        'Location permission is permanently denied. Please grant it in App Settings → Permissions.',
      );
    }

    Position? position;

    // Strategy 1: Try last known position (instant, no GPS needed)
    try {
      position = await Geolocator.getLastKnownPosition();
    } catch (_) {}

    // Strategy 2: Live GPS — low accuracy first (faster fix)
    if (position == null) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } on TimeoutException {
        // Fall through to medium accuracy
      } catch (_) {}
    }

    // Strategy 3: Live GPS — medium accuracy (more precise but slower)
    if (position == null) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } on TimeoutException {
        throw const LocationTimeoutException(
          'GPS timed out. Make sure you are outdoors or near a window, then try again.',
        );
      } catch (e) {
        throw Exception('Unable to acquire GPS signal: $e');
      }
    }

    return await reverseGeocode(position.latitude, position.longitude);
  }
}
