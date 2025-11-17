// lib/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/user_dashboard.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/staff/staff_dashboard.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  Future<Widget> _resolveRoute() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      // Not logged in → go to login
      if (user == null) {
        return const _Redirect('/login');
      }

      // Fetch profile
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!snap.exists) {
        // User exists in Auth but not in Firestore → logout + go to login
        await FirebaseAuth.instance.signOut();
        return const _Redirect('/login');
      }

      final data = snap.data()!;
      final role = data['userType'] as String? ?? 'Passenger';
      final department = data['department'] as String?;

      // Route based on role
      if (role == 'Admin') return const _Redirect('/admin');
      if (role == 'Staff' && department != null) {
        return _Redirect('/staff/$department');
      }
      return const _Redirect('/user');

    } catch (e) {
      print("AuthGate ERROR: $e");
      return const _Redirect('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolveRoute(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data!;
      },
    );
  }
}

/// Redirection widget (safe for build)
class _Redirect extends StatelessWidget {
  final String route;
  const _Redirect(this.route, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, route);
    });

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
