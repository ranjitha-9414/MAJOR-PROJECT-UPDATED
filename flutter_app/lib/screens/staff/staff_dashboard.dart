import 'package:flutter/material.dart';
import 'package:rail_aid/screens/staff/staff_complaints.dart';
import 'package:rail_aid/screens/staff/staff_profile.dart';

class StaffDashboard extends StatefulWidget {
  final String department;
  const StaffDashboard({Key? key, required this.department}) : super(key: key);

  @override
  _StaffDashboardState createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [StaffComplaints(department: widget.department), StaffProfile(department: widget.department)];
    return Scaffold(
      body: pages[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Complaints'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
