import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/session.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Short splash then decide where to route based on saved session
    Future.delayed(const Duration(milliseconds: 800), () async {
      final current = await getCurrentUser();
      if (current == null) {
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userRaw = prefs.getString('user_$current');
      if (userRaw == null || userRaw.isEmpty) {
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      try {
        final Map<String, dynamic> userMap = jsonDecode(userRaw) as Map<String, dynamic>;
        final role = (userMap['role'] ?? userMap['type'] ?? userMap['roleType'])?.toString().toLowerCase();
        final isAdmin = (userMap['isAdmin'] ?? userMap['admin']) == true || role == 'admin';
        if (isAdmin) {
          Navigator.of(context).pushReplacementNamed('/admin');
          return;
        }

        if (role == 'staff' || userMap.containsKey('department')) {
          final dept = (userMap['department'] ?? 'Technical').toString();
          Navigator.of(context).pushReplacementNamed('/staff/$dept');
          return;
        }
      } catch (e) {
        // ignore json parse errors and fallback to heuristics
        final raw = userRaw.toLowerCase();
        if (raw.contains('admin')) {
          Navigator.of(context).pushReplacementNamed('/admin');
          return;
        }
        if (raw.contains('staff')) {
          final deptMatch = RegExp(r'"department"\s*:\s*"([A-Za-z0-9 _-]+)"').firstMatch(userRaw);
          final dept = deptMatch?.group(1) ?? 'Technical';
          Navigator.of(context).pushReplacementNamed('/staff/$dept');
          return;
        }
      }

      Navigator.of(context).pushReplacementNamed('/user');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 56,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(Icons.train, size: 56, color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 12),
            const Text('RailAid', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
