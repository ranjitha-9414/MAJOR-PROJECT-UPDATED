// lib/screens/user_dashboard.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'chatbot_placeholder.dart';
import 'package:rail_aid/screens/user/profile_user.dart';
import 'package:rail_aid/models/complaint.dart';

/// ---------------------------------------------------------------
/// MAIN DASHBOARD WRAPPER
/// ---------------------------------------------------------------
class UserDashboard extends StatefulWidget {
  const UserDashboard({Key? key}) : super(key: key);

  @override
  _UserDashboardState createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _currentIndex = 0;

  List<Widget> get _pages => [
        const UserHome(),
        const ProfileUser(),
        const ChatbotPlaceholder(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.redAccent,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chatbot'),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------
/// PASSENGER HOME PAGE WITH PREMIUM ANIMATIONS
/// ---------------------------------------------------------------
class UserHome extends StatefulWidget {
  const UserHome({Key? key}) : super(key: key);
  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> with TickerProviderStateMixin {
  String _name = 'Guest';
  List<Complaint> _complaints = [];
  bool _showWelcomeBanner = false;

  // Animation Controllers
  late AnimationController headerGlowCtrl;
  late AnimationController cloudCtrl;
  late AnimationController cardSlideCtrl;
  late AnimationController trainCtrl;

  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadData();

    /// HEADER GLOW
    headerGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    /// CLOUD FLOAT
    cloudCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    /// CARDS SLIDE UP
    cardSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    /// TRAIN SLIDE
    trainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    headerGlowCtrl.dispose();
    cloudCtrl.dispose();
    cardSlideCtrl.dispose();
    trainCtrl.dispose();
    super.dispose();
  }

  /// Load local data and then try to sync with Firestore
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString("current_user");

    if (current != null) {
      final raw = prefs.getString("user_$current");

      if (raw != null) {
        try {
          final j = jsonDecode(raw);
          setState(() => _name = j["name"] ?? "User");
        } catch (_) {
          setState(() => _name = current.split("@").first);
        }
      } else {
        setState(() => _name = current.split("@").first);
      }
    }

    // Load local complaints first (fast)
    final list = prefs.getStringList("complaints") ?? [];
    final localComplaints = <Complaint>[];
    for (final s in list) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        localComplaints.add(Complaint.fromJson(m));
      } catch (_) {}
    }

    setState(() => _complaints = localComplaints);

    // Check whether we should show the welcome banner once (set by login)
    try {
      final prefs = await SharedPreferences.getInstance();
      final show = prefs.getBool('show_welcome') ?? false;
      if (show) {
        setState(() => _showWelcomeBanner = true);
        // Clear the flag so it only shows once per login
        await prefs.remove('show_welcome');
        // hide banner after a short delay so it doesn't block interaction
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _showWelcomeBanner = false);
        });
      }
    } catch (_) {}

    // Then try to sync (merge) from Firestore in background
    _syncFromFirestoreAndMerge();
  }

  /// Fetch cloud complaints for current user and merge with local list.
  /// Merge strategy: use unique id; prefer the one with latest createdAt.
  Future<void> _syncFromFirestoreAndMerge() async {
    setState(() => _syncing = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _syncing = false);
        return;
      }
      final userEmail = user.email ?? user.uid;

      // Attempt to read cloud documents for this user (best-effort)
      QuerySnapshot q;
      try {
        q = await FirebaseFirestore.instance
            .collection('complaints')
            .where('userEmail', isEqualTo: userEmail)
            .orderBy('createdAt', descending: true)
            .limit(200)
            .get();
      } catch (e) {
        // If Firestore throws (index required or other), log and fallback to local only.
        debugPrint('Firestore query failed (will fallback to local): $e');
        setState(() => _syncing = false);
        return;
      }

      // Build map from local complaints
      final Map<String, Complaint> merged = {
        for (final c in _complaints) c.id: c,
      };

      // Convert firestore docs to Complaint and merge
      for (final d in q.docs) {
        final data = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
        // ensure id and createdAt are in consistent format for fromJson
        data['id'] = data['id'] ?? d.id;
        final createdAtRaw = data['createdAt'];
        if (createdAtRaw is Timestamp) {
          data['createdAt'] = createdAtRaw.toDate().toIso8601String();
        } else if (createdAtRaw is DateTime) {
          data['createdAt'] = createdAtRaw.toIso8601String();
        } else if (createdAtRaw == null) {
          // fallback to now
          data['createdAt'] = DateTime.now().toIso8601String();
        } // otherwise assume already a string

        try {
          final cloudC = Complaint.fromJson(data);
          final existing = merged[cloudC.id];
          if (existing == null) {
            merged[cloudC.id] = cloudC;
          } else {
            // prefer newer by createdAt
            DateTime existingDt = existing.createdAt;
            DateTime cloudDt = cloudC.createdAt;
            if (cloudDt.isAfter(existingDt)) {
              merged[cloudC.id] = cloudC;
            }
          }
        } catch (e) {
          // ignore malformed doc
          debugPrint('Failed to parse cloud complaint ${d.id}: $e');
        }
      }

      // Convert merged map to sorted list (newest first)
      final mergedList = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Persist merged list to SharedPreferences
      await _saveLocalComplaints(mergedList);

      setState(() {
        _complaints = mergedList;
      });
    } catch (e) {
      debugPrint('Sync failed: $e');
      // keep local-only data if sync fails
    } finally {
      setState(() => _syncing = false);
    }
  }

  Future<void> _saveLocalComplaints(List<Complaint> list) async {
    final prefs = await SharedPreferences.getInstance();
    final sl = list.map((c) => json.encode(c.toJson())).toList();
    await prefs.setStringList('complaints', sl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffD4EAFF),
      body: Stack(
        children: [
          /// BACKGROUND
          Positioned.fill(
            child: AnimatedBuilder(
              animation: cloudCtrl,
              builder: (_, __) => CustomPaint(
                painter: RailwayBackground(
                  cloudShift: cloudCtrl.value * 200,
                  trainShift: trainCtrl.value * 500,
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: cardSlideCtrl,
                curve: Curves.easeIn,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  /// HEADER WITH GLOW
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AnimatedBuilder(
                      animation: headerGlowCtrl,
                      builder: (_, child) {
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(
                                    0.3 + headerGlowCtrl.value * 0.2),
                                blurRadius: 20 + headerGlowCtrl.value * 10,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.train,
                                  size: 40, color: Colors.redAccent),
                              SizedBox(width: 10),
                              Text(
                                "Passenger Dashboard",
                                style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 15),

                  /// USER CARD (Slide animation) - show only once after login
                  if (_showWelcomeBanner)
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: cardSlideCtrl,
                        curve: Curves.easeOut,
                      )),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                                blurRadius: 12,
                                color: Colors.black26,
                                offset: Offset(0, 4))
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Hello, $_name 👋",
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w600),
                            ),

                            /// Settings button spin
                            RotationTransition(
                              turns: Tween<double>(begin: 0, end: 1).animate(
                                CurvedAnimation(
                                    parent: trainCtrl, curve: Curves.linear),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.settings),
                                onPressed: () =>
                                    Navigator.of(context).pushNamed('/settings'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  /// QUICK ACTION BUTTONS FLOAT
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: PremiumQuickAction(
                            label: "New Complaint",
                            color: Colors.redAccent,
                            icon: Icons.report_problem,
                            delay: 100,
                            onTap: () async {
                              await Navigator.pushNamed(
                                  context, '/complaint/new');
                              // After returning, reload local + try sync
                              await _loadData();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: PremiumQuickAction(
                            label: "Track Complaint",
                            color: Colors.blueAccent,
                            icon: Icons.search,
                            delay: 250,
                            onTap: () =>
                                Navigator.pushNamed(context, '/complaint/track'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// TOTAL COMPLAINTS WITH SHINE
                  ShineCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Complaints",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        Row(
                          children: [
                            Text(
                              "${_complaints.length}",
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent),
                            ),
                            const SizedBox(width: 12),
                            if (_syncing)
                              const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                          ],
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// RECENT COMPLAINTS SLIDE-UP
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "Recent Complaints",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Expanded(
                    child: _complaints.isEmpty
                        ? const Center(
                            child: Text("No complaints yet",
                                style: TextStyle(fontSize: 16)))
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _complaints.length.clamp(0, 5),
                            itemBuilder: (context, i) {
                              final c = _complaints[i];

                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.4),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: cardSlideCtrl,
                                  curve: Interval(i * 0.1, 1,
                                      curve: Curves.easeOut),
                                )),
                                child: Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 4,
                                  child: ListTile(
                                    leading: const Icon(Icons.report,
                                        color: Colors.redAccent),
                                    title: Text("${c.id} — ${c.category}"),
                                    subtitle: Text(
                                      c.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: BounceStatus(status: c.status),
                                    onTap: () {
                                      // open detailed view if you have one (not included here)
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------
/// PREMIUM QUICK ACTION BUTTON
/// ---------------------------------------------------------------
class PremiumQuickAction extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int delay;

  const PremiumQuickAction({
    Key? key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.delay,
  }) : super(key: key);

  @override
  State<PremiumQuickAction> createState() => _PremiumQuickActionState();
}

class _PremiumQuickActionState extends State<PremiumQuickAction>
    with TickerProviderStateMixin {
  late AnimationController floatCtrl;

  @override
  void initState() {
    super.initState();
    floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
  }

  @override
  void dispose() {
    floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: floatCtrl,
        curve: Interval(widget.delay / 500, 1, curve: Curves.elasticOut),
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  blurRadius: 6, color: Colors.black26, offset: Offset(0, 3))
            ],
          ),
          child: Column(
            children: [
              Icon(widget.icon, color: Colors.white, size: 30),
              const SizedBox(height: 8),
              Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------
/// SHINING CARD WIDGET (Premium Glass Glow)
/// ---------------------------------------------------------------
class ShineCard extends StatelessWidget {
  final Widget child;

  const ShineCard({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(seconds: 3),
      builder: (context, value, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Colors.white.withOpacity(0.9),
                Colors.white.withOpacity(0.7),
              ],
              stops: [0, value, 1],
            ),
            boxShadow: const [
              BoxShadow(
                  blurRadius: 8, color: Colors.black26, offset: Offset(0, 3))
            ],
          ),
          child: child,
        );
      },
    );
  }
}

/// ---------------------------------------------------------------
/// STATUS BOUNCE ANIMATION (for list items)
/// ---------------------------------------------------------------
class BounceStatus extends StatefulWidget {
  final String status;
  const BounceStatus({Key? key, required this.status}) : super(key: key);

  @override
  State<BounceStatus> createState() => _BounceStatusState();
}

class _BounceStatusState extends State<BounceStatus>
    with TickerProviderStateMixin {
  late AnimationController bounceCtrl;

  @override
  void initState() {
    super.initState();
    bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    bounceCtrl.dispose();
    super.dispose();
  }

  Color get statusColor {
    switch (widget.status) {
      case 'open':
        return Colors.redAccent;
      case 'in-progress':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale:
          Tween(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: bounceCtrl, curve: Curves.easeInOut)),
      child: Text(
        widget.status,
        style: TextStyle(fontSize: 12, color: statusColor),
      ),
    );
  }
}

/// ---------------------------------------------------------------
/// BACKGROUND PAINTER WITH CLOUD + TRAIN ANIMATION
/// ---------------------------------------------------------------
class RailwayBackground extends CustomPainter {
  final double cloudShift;
  final double trainShift;

  RailwayBackground({
    required this.cloudShift,
    required this.trainShift,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();

    /// Sky
    p.color = const Color(0xffC8E4FF);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), p);

    /// Hills
    p.color = const Color(0xff7ED957);
    final hill = Path()
      ..moveTo(0, size.height * .18)
      ..quadraticBezierTo(size.width * .4, size.height * .1,
          size.width, size.height * .18)
      ..lineTo(size.width, 0)
      ..lineTo(0, 0);
    canvas.drawPath(hill, p);

    /// Clouds
    p.color = Colors.white.withOpacity(0.8);
    canvas.drawCircle(Offset(60 + cloudShift % size.width, 60), 25, p);
    canvas.drawCircle(Offset(160 + cloudShift % size.width, 40), 20, p);

    /// Moving Train (simple bar)
    p.color = Colors.redAccent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH((trainShift % (size.width + 200)) - 200,
            size.height * 0.22, 200, 35),
        const Radius.circular(12),
      ),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
