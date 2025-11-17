import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

/// Reverse geocode lat/lng to a human readable address using Mapbox Geocoding API.
/// Set `MAPBOX_API_KEY` in `lib/config.dart`.
Future<String?> reverseGeocode(double lat, double lon) async {
  // Try Mapbox first when API key present, otherwise fall back to Nominatim.
  try {
    if (MAPBOX_API_KEY.isNotEmpty && MAPBOX_API_KEY != 'YOUR_MAPBOX_ACCESS_TOKEN') {
      try {
        final url = Uri.parse('https://api.mapbox.com/geocoding/v5/mapbox.places/\$lon,\$lat.json?access_token=\$MAPBOX_API_KEY&limit=1');
        final res = await http.get(url);
        if (res.statusCode == 200) {
          final Map<String, dynamic> j = json.decode(res.body) as Map<String, dynamic>;
          final features = j['features'] as List<dynamic>?;
          if (features != null && features.isNotEmpty) {
            final place = features.first['place_name'] as String?;
            if (place != null && place.isNotEmpty) return place;
          }
        }
      } catch (_) {
        // ignore and fall back
      }
    }

    // Fallback: use Nominatim (OpenStreetMap) which doesn't require a key for light usage.
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=\$lat&lon=\$lon&addressdetails=0');
      final res = await http.get(url, headers: {
        'User-Agent': 'RailAidApp/1.0 (contact@example.com)'
      });
      if (res.statusCode != 200) return null;
      final Map<String, dynamic> j = json.decode(res.body) as Map<String, dynamic>;
      final display = j['display_name'] as String?;
      return display;
    } catch (_) {
      return null;
    }
  } catch (_) {
    return null;
  }
}
