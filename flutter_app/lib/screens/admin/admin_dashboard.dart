import 'package:flutter/material.dart';
import 'package:rail_aid/screens/admin/admin_profile.dart';
import 'package:rail_aid/screens/admin/admin_analysis.dart';
import 'package:rail_aid/screens/admin/admin_performance.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [const AdminProfile(), const AdminAnalysis(), const AdminPerformance()];
    return Scaffold(
      body: pages[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analysis'),
          BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Staff Perf'),
        ],
      ),
    );
  }
}
