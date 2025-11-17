// Stub implementation used on platforms where browser geolocation is not available.
// A conditional import will substitute the web implementation when compiled to web.

Future<Map<String, double>?> getBrowserLocation() async {
  // Return null by default - caller should handle null as 'not available'
  return null;
}
