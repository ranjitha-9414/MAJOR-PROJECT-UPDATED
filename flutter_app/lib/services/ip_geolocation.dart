import 'dart:convert';
import 'package:http/http.dart' as http;

/// Try to obtain an approximate location from the client's IP address.
/// Uses ipapi.co (no key, rate-limited). Returns null on failure.
Future<Map<String, dynamic>?> getIpLocation() async {
  try {
    final url = Uri.parse('https://ipapi.co/json/');
    final res = await http.get(url);
    if (res.statusCode != 200) return null;
    final Map<String, dynamic> j = json.decode(res.body) as Map<String, dynamic>;
    final lat = j['latitude'];
    final lon = j['longitude'];
    final city = j['city'];
    final region = j['region'];
    final country = j['country_name'];
    if (lat == null || lon == null) return null;
    final addressParts = [city, region, country].where((e) => e != null && (e as String).isNotEmpty).toList();
    final address = addressParts.isNotEmpty ? addressParts.join(', ') : null;
    return {'lat': (lat as num).toDouble(), 'lng': (lon as num).toDouble(), 'address': address};
  } catch (_) {
    return null;
  }
}
