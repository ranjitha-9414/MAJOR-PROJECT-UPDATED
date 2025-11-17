import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Conditional platform helper: uses dart:io on native, and a web shim on web.
import 'platform_helpers_io.dart' if (dart.library.html) 'platform_helpers_web.dart';

class ApiService {
  // Platform-aware base URL. Change via constructor or env override.
  String baseUrl = _defaultBaseUrl();
  bool offlineMode = false;

  ApiService({String? base, this.offlineMode = false}) {
    if (base != null) baseUrl = base;
  }

  static String _defaultBaseUrl() {
    // Default localhost for web and desktop. For Android emulator use 10.0.2.2,
    // but dart:io is not available on web; use the `isAndroidDevice` shim which
    // resolves to true only on native Android.
    if (kDebugMode && isAndroidDevice) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  void setOffline(bool v) => offlineMode = v;

  Future<Map<String, dynamic>> safeGet(String path) async {
    if (offlineMode) return Future.value({'offline': true});
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      final body = response.body;
      try {
        return json.decode(body) as Map<String, dynamic>;
      } catch (e) {
        return {'raw': body, 'statusCode': response.statusCode};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> safePost(String path, Map data) async {
    if (offlineMode) return Future.value({'offline': true});
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await http.post(uri, headers: {'content-type': 'application/json'}, body: json.encode(data)).timeout(const Duration(seconds: 20));
      final body = response.body;
      try {
        return json.decode(body) as Map<String, dynamic>;
      } catch (e) {
        return {'raw': body, 'statusCode': response.statusCode};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
