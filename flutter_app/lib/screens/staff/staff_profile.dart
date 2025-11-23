import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StaffProfile extends StatefulWidget {
  final String department;
  const StaffProfile({Key? key, required this.department}) : super(key: key);

  @override
  _StaffProfileState createState() => _StaffProfileState();
}

class _StaffProfileState extends State<StaffProfile>
    with TickerProviderStateMixin {
  String _staffName = 'Staff';
  String _staffEmail = '';

  late AnimationController headerController;
  late Animation<double> fadeAnim;
  late Animation<double> slideAnim;

  late AnimationController trainController;
  late Animation<double> trainSlide;

  @override
  void initState() {
    super.initState();
    _loadStaffInfo();

    headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: headerController,
      curve: Curves.easeOut,
    ));

    slideAnim = Tween<double>(begin: 40, end: 0).animate(CurvedAnimation(
      parent: headerController,
      curve: Curves.easeOutBack,
    ));

    // TRAIN ANIMATION
    trainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    trainSlide = Tween<double>(begin: -10, end: 10).animate(CurvedAnimation(
      parent: trainController,
      curve: Curves.easeInOut,
    ));

    headerController.forward();
  }

  @override
  void dispose() {
    headerController.dispose();
    trainController.dispose();
    super.dispose();
  }

  Future<void> _loadStaffInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString('current_user');
    if (current != null) {
      _staffEmail = current;

      final userRaw = prefs.getString('user_$current');
      if (userRaw != null) {
        try {
          final j = json.decode(userRaw) as Map<String, dynamic>;
          _staffName = j['name'] ?? 'Staff';
        } catch (_) {}
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Staff Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          )
        ],
      ),

      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadDeptComplaints(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final list = snap.data!;
          final total = list.length;
          final open = list.where((m) => (m['status'] ?? 'open') == 'open').length;
          final inprogress = list.where((m) => (m['status'] ?? '') == 'in-progress').length;
          final resolved = list.where((m) => (m['status'] ?? '') == 'resolved').length;

          return SingleChildScrollView(
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: headerController,
                  builder: (_, __) => Opacity(
                    opacity: fadeAnim.value,
                    child: Transform.translate(
                      offset: Offset(0, slideAnim.value),
                      child: _buildEnhancedHeader(),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Staff Badge
                _buildBadgeCard(),

                const SizedBox(height: 20),

                // Stats + donut
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statBox("Total", total, Colors.blue),
                          _statBox("Open", open, Colors.red),
                          _statBox("In Progress", inprogress, Colors.orange),
                          _statBox("Resolved", resolved, Colors.green),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed('/login'),
                  icon: const Icon(Icons.logout),
                  label: const Text("Logout"),
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------
  // 🔵 NEW ENHANCED ANIMATED HEADER WITH TRAIN & GLOW
  // ---------------------------------------------------------
  Widget _buildEnhancedHeader() {
    return Stack(
      children: [
        // Glow background
        Container(
          height: 240,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF004AAD), Color(0xFF1A73E8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade700.withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: 4,
                offset: const Offset(0, 6),
              )
            ],
          ),
        ),

        // Curved bottom clip
        Positioned.fill(
          child: ClipPath(
            clipper: HeaderClipper(),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF004AAD), Color(0xFF318BFC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),

        // Train Icon (moving)
        Positioned(
          right: 30,
          top: 40,
          child: AnimatedBuilder(
            animation: trainSlide,
            builder: (_, __) {
              return Transform.translate(
                offset: Offset(trainSlide.value, 0),
                child: const Icon(Icons.train, size: 40, color: Colors.white),
              );
            },
          ),
        ),

        // User Info
        Positioned.fill(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 42, color: Colors.blue),
              ),
              const SizedBox(height: 10),

              Text(
                _staffName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),

              Text(
                _staffEmail,
                style: const TextStyle(color: Colors.black),
              ),

              const SizedBox(height: 6),

              Text(
                "Department: ${widget.department}",
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // 🎖 Staff Badge
  // ---------------------------------------------------------
  Widget _buildBadgeCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.verified, color: Colors.blue, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Verified Railway Staff",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                  Text("Joined: 2025"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 📊 Statistic Boxes
  // ---------------------------------------------------------
  Widget _statBox(String label, int value, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 6),
        Text(
          "$value",
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _loadDeptComplaints() async {
    // Prefer Firestore when available; fall back to SharedPreferences
    try {
      final q = await FirebaseFirestore.instance
          .collection('complaints')
          .where('category', isEqualTo: widget.department)
          .limit(500)
          .get();

      final docs = q.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        final rawCreated = data['createdAt'];
        if (rawCreated is Timestamp) {
          data['createdAt'] = rawCreated.toDate().toIso8601String();
        } else if (rawCreated is DateTime) {
          data['createdAt'] = rawCreated.toIso8601String();
        } else if (rawCreated == null) {
          data['createdAt'] = DateTime.now().toIso8601String();
        }
        data['id'] = data['id'] ?? d.id;
        return data;
      }).toList();

      // sort newest first
      docs.sort((a, b) {
        try {
          final da = DateTime.parse(a['createdAt']);
          final db = DateTime.parse(b['createdAt']);
          return db.compareTo(da);
        } catch (_) {
          return 0;
        }
      });

      return docs.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Firestore load failed (profile): $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('complaints') ?? <String>[];

    return raw
        .map<Map<String, dynamic>>((e) {
          try {
            return json.decode(e);
          } catch (_) {
            return <String, dynamic>{};
          }
        })
        .where((m) => m.isNotEmpty && (m['category'] ?? '') == widget.department)
        .toList();
  }
}

// ---------------------------------------------------------
// 🔵 Beautiful Curved Header
// ---------------------------------------------------------
class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path();
    p.lineTo(0, size.height - 50);
    p.quadraticBezierTo(
        size.width / 2, size.height, size.width, size.height - 50);
    p.lineTo(size.width, 0);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(_) => false;
}
