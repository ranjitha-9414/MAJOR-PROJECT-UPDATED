import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/* ----------------------------------------------------------
   RAILWAY THEME COLORS
---------------------------------------------------------- */
class RailColors {
  static const blue = Color(0xFF0057A5); // IRCTC Blue
  static const lightBlue = Color(0xFF2FA6FF);
  static const accent = Color(0xFF0EA58A);
  static const danger = Color(0xFFE53935);
  static const warning = Color(0xFFF4A300);
  static const success = Color(0xFF1DB954);
}

/* ----------------------------------------------------------
   Admin Profile Screen
---------------------------------------------------------- */
class AdminProfile extends StatefulWidget {
  const AdminProfile({Key? key}) : super(key: key);

  @override
  State<AdminProfile> createState() => _AdminProfileState();
}

class _AdminProfileState extends State<AdminProfile> {
  String _adminName = 'Admin User';
  String _adminEmail = 'admin@example.com';

  int _total = 0;
  int _open = 0;
  int _inProgress = 0;
  int _resolved = 0;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAdmin();
    _loadComplaintStats();
  }

  Future<void> _loadAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    final c = prefs.getString("current_user") ?? "Admin";
    setState(() {
      _adminName = c;
      _adminEmail = "$c@railway.gov";
    });
  }

  Future<void> _loadComplaintStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList("complaints") ?? [];

    final list =
        raw.map((e) => json.decode(e) as Map<String, dynamic>).toList();

    setState(() {
      _total = list.length;
      _open = list.where((c) => c["status"] == "open").length;
      _inProgress = list.where((c) => c["status"] == "in-progress").length;
      _resolved = list.where((c) => c["status"] == "resolved").length;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("current_user");
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                /* ----------------------------------------------------------
                   SliverAppBar with LOGOUT Button
                ---------------------------------------------------------- */
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 190,
                  backgroundColor: RailColors.blue,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      tooltip: "Logout",
                      onPressed: _logout,
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                    title: const Text(
                      "Admin Dashboard",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    background: Stack(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [RailColors.blue, RailColors.lightBlue],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 20,
                          bottom: 20,
                          child: Icon(
                            Icons.train,
                            size: 70,
                            color: Colors.white54,
                          ),
                        )
                      ],
                    ),
                  ),
                ),

                /* ------------------ MAIN CONTENT ------------------ */
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _profileCard(),
                        const SizedBox(height: 20),

                        _kpiCards(),
                        const SizedBox(height: 20),

                        const Text("Complaint Status Breakdown",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),

                        _statusDonut(),
                        const SizedBox(height: 20),

                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _exportCsv,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: RailColors.blue,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.download, color: Colors.white),
                            label: const Text("Export Complaints CSV",
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /* ----------------------------------------------------------
     PROFILE CARD
  ---------------------------------------------------------- */
  Widget _profileCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: RailColors.blue,
              child: const Icon(Icons.admin_panel_settings,
                  size: 40, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_adminName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(_adminEmail,
                        style:
                            const TextStyle(color: Colors.black54, fontSize: 14))
                  ]),
            )
          ],
        ),
      ),
    );
  }

  /* ----------------------------------------------------------
     KPI CARDS
  ---------------------------------------------------------- */
  Widget _kpiCards() {
    return Row(
      children: [
        Expanded(child: _kpi("Total", _total, RailColors.blue)),
        const SizedBox(width: 10),
        Expanded(child: _kpi("Open", _open, RailColors.danger)),
        const SizedBox(width: 10),
        Expanded(child: _kpi("In Progress", _inProgress, RailColors.warning)),
        const SizedBox(width: 10),
        Expanded(child: _kpi("Resolved", _resolved, RailColors.success)),
      ],
    );
  }

  Widget _kpi(String title, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.3)),
      ),
      child: Column(
        children: [
          Text(title.toUpperCase(),
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 12)),
          const SizedBox(height: 6),
          Text("$value",
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  /* ----------------------------------------------------------
     DONUT CHART
  ---------------------------------------------------------- */
  Widget _statusDonut() {
    final Map<String, double> values = {
      "Open": _open.toDouble(),
      "In-Progress": _inProgress.toDouble(),
      "Resolved": _resolved.toDouble(),
    };

    final colors = [
      RailColors.danger,
      RailColors.warning,
      RailColors.success,
    ];

    return Center(
      child: SizedBox(
        width: 220,
        height: 220,
        child: CustomPaint(
          painter: _DonutPainter(values: values, colors: colors),
        ),
      ),
    );
  }

  /* ----------------------------------------------------------
     CSV EXPORT (Clipboard Copy)
  ---------------------------------------------------------- */
  Future<void> _exportCsv() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('complaints') ?? [];

    final rows = [
      ["id", "name", "train", "category", "status"]
    ];

    for (final r in raw) {
      final j = json.decode(r);
      rows.add([
        j["id"] ?? "",
        j["fullName"] ?? "",
        j["trainNumber"] ?? "",
        j["category"] ?? "",
        j["status"] ?? "",
      ]);
    }

    final csv =
        rows.map((r) => r.map((c) => '"$c"').join(",")).join("\n");

    await Clipboard.setData(ClipboardData(text: csv));

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("CSV copied to clipboard")));
  }
}

/* ----------------------------------------------------------
   DONUT PAINTER
---------------------------------------------------------- */
class _DonutPainter extends CustomPainter {
  final Map<String, double> values;
  final List<Color> colors;

  _DonutPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.values.fold(0.0, (a, b) => a + b);
    if (total == 0) return;

    double startRadian = -math.pi / 2;
    final center = size.center(Offset.zero);
    final radius = size.width / 2.2;
    final strokeWidth = 32.0;

    for (int i = 0; i < values.length; i++) {
      final sweep = (values.values.elementAt(i) / total) * 2 * math.pi;
      final paint = Paint()
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = colors[i];

      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startRadian,
          sweep,
          false,
          paint);

      startRadian += sweep;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
