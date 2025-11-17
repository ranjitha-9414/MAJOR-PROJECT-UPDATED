import 'package:shared_preferences/shared_preferences.dart';

const _kCurrentUser = 'current_user';

Future<String?> getCurrentUser() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kCurrentUser);
}

Future<void> setCurrentUser(String email) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kCurrentUser, email);
}

Future<void> clearCurrentUser() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kCurrentUser);
}
