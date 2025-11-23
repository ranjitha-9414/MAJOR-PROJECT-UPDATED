import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPerformance extends StatelessWidget {
  const AdminPerformance({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Staff Performance',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          )
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _loadComplaints(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final complaints = snap.data!;
            final departments = [
              'Technical',
              'Cleaning',
              'Infrastructure',
              'Safety',
              'Misconduct',
              'Overcrowd',
              'Other'
            ];

            // Overall statuses
            final resolved =
                complaints.where((m) => m['status'] == 'resolved').length;
            final inProgress =
                complaints.where((m) => m['status'] == 'in-progress').length;
            final open =
                complaints.where((m) => m['status'] == 'open').length;

            final totalAll = resolved + inProgress + open;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),

                  /// ---------------- Overall Donuts ----------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SingleDonut(
                        label: 'Resolved',
                        value: resolved,
                        total: totalAll,
                        color: Colors.green,
                      ),
                      SingleDonut(
                        label: 'In-Progress',
                        value: inProgress,
                        total: totalAll,
                        color: Colors.orange,
                      ),
                      SingleDonut(
                        label: 'Open',
                        value: open,
                        total: totalAll,
                        color: Colors.red,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  /// ---------------- Dept Chart Bars ----------------
                  StatusByDeptCharts(
                    complaints: complaints,
                    departments: departments,
                  ),
                  const SizedBox(height: 20),

                  /// ---------------- Dept Donuts ----------------
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: departments.length,
                    itemBuilder: (context, i) {
                      final dept = departments[i];
                      final deptList = complaints
                          .where((m) => m['category'] == dept)
                          .toList();

                      final total = deptList.length;
                      final resolved = deptList
                          .where((m) => m['status'] == 'resolved')
                          .length;
                      final open = deptList
                          .where((m) => m['status'] == 'open')
                          .length;
                      final inProgress = deptList
                          .where((m) => m['status'] == 'in-progress')
                          .length;

                      // Weighted scoring
                      const double weight = 0.5;
                      final score = (resolved + inProgress * weight);
                      final percent = total == 0
                          ? 0
                          : ((score / total) * 100).round();

                      Color chipColor() {
                        if (percent >= 75) return Colors.green;
                        if (percent >= 40) return Colors.orange;
                        return Colors.red;
                      }

                      return Card(
                        child: ListTile(
                          leading: PieDonut(
                            resolved: resolved,
                            inProgress: inProgress,
                            open: open,
                          ),
                          title: Text(dept),
                          subtitle: Text(
                            'Resolved: $resolved • In-Progress: $inProgress • Open: $open • Total: $total',
                          ),
                          trailing: Chip(
                            label: Text('$percent%'),
                            backgroundColor: chipColor(),
                            labelStyle:
                                const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadComplaints() async {
    // Prefer Firestore, fallback to SharedPreferences
    try {
      final q = await FirebaseFirestore.instance.collection('complaints').limit(500).get();
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
      debugPrint('Firestore load failed (admin performance): $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('complaints') ?? [];

    final list = raw.map<Map<String, dynamic>>((e) {
      try {
        return json.decode(e) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).toList();

    // sort by createdAt desc
    list.sort((a, b) {
      try {
        final da = DateTime.parse(a['createdAt'] ?? DateTime.now().toIso8601String());
        final db = DateTime.parse(b['createdAt'] ?? DateTime.now().toIso8601String());
        return db.compareTo(da);
      } catch (_) {
        return 0;
      }
    });

    return list;
  }
}

/// ======================================================================
/// PIE DONUT (Dept-level)
/// ======================================================================

class PieDonut extends StatelessWidget {
  final int resolved;
  final int inProgress;
  final int open;
  final double size;

  const PieDonut({
    Key? key,
    required this.resolved,
    required this.inProgress,
    required this.open,
    this.size = 56,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final total = (resolved + inProgress + open).toDouble();

    final scorePercent = total == 0
        ? 0
        : (((resolved + inProgress * 0.5) / total) * 100).round();

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _PiePainter(
              resolved: resolved.toDouble(),
              inProgress: inProgress.toDouble(),
              open: open.toDouble(),
            ),
          ),
        ),
        Text(
          '$scorePercent%',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        )
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  final double resolved;
  final double inProgress;
  final double open;

  _PiePainter({
    required this.resolved,
    required this.inProgress,
    required this.open,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = resolved + inProgress + open;

    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final strokeWidth = radius * 0.45;

    final bg = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, bg);

    if (total <= 0) return;

    double start = -math.pi / 2;

    void drawArc(double value, Color color) {
      if (value <= 0) return;

      final sweep = (value / total) * math.pi * 2;

      final p = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        start,
        sweep,
        false,
        p,
      );

      start += sweep;
    }

    drawArc(resolved, Colors.green);
    drawArc(inProgress, Colors.orange);
    drawArc(open, Colors.red);
  }

  @override
  bool shouldRepaint(_) => true;
}

/// ======================================================================
/// SINGLE DONUT (Overall)
/// ======================================================================

class SingleDonut extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;
  final double size;

  const SingleDonut({
    Key? key,
    required this.label,
    required this.value,
    required this.total,
    required this.color,
    this.size = 80,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : value / total;
    final percentText = total == 0 ? '0%' : '${(pct * 100).round()}%';

    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _SingleDonutPainter(pct, color),
          ),
        ),
        const SizedBox(height: 6),
        Text(label),
        Text(
          percentText,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _SingleDonutPainter extends CustomPainter {
  final double pct;
  final Color color;

  _SingleDonutPainter(this.pct, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final strokeWidth = radius * 0.4;

    // Background circle
    final bg = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, bg);

    if (pct <= 0) return;

    final sweep = pct * math.pi * 2;

    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2,
      sweep,
      false,
      p,
    );
  }

  @override
  bool shouldRepaint(_) => true;
}

/// ======================================================================
/// STATUS BY DEPARTMENT CHARTS
/// ======================================================================

class StatusByDeptCharts extends StatelessWidget {
  final List<Map<String, dynamic>> complaints;
  final List<String> departments;

  const StatusByDeptCharts({
    Key? key,
    required this.complaints,
    required this.departments,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final stats = departments.map((dept) {
      final list =
          complaints.where((m) => m['category'] == dept).toList();

      final total = list.length;

      final resolved =
          list.where((m) => m['status'] == 'resolved').length;
      final inProgress =
          list.where((m) => m['status'] == 'in-progress').length;
      final open = list.where((m) => m['status'] == 'open').length;

      return {
        'dept': dept,
        'resolvedPct': total == 0 ? 0 : ((resolved / total) * 100).round(),
        'inProgressPct':
            total == 0 ? 0 : ((inProgress / total) * 100).round(),
        'openPct': total == 0 ? 0 : ((open / total) * 100).round(),
      };
    }).toList();

    Widget buildChart(String title, String key, Color color) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),

          ...stats.map((s) {
            final pct = (s[key] as int).clamp(0, 100);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(s['dept'].toString()),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: pct / 100,
                          child: Container(
                            height: 16,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$pct%',
                      textAlign: TextAlign.right,
                    ),
                  )
                ],
              ),
            );
          })
        ],
      );
    }

    return Column(
      children: [
        buildChart('Open % by Department', 'openPct', Colors.red),
        const SizedBox(height: 16),
        buildChart(
            'In-Progress % by Department', 'inProgressPct', Colors.orange),
        const SizedBox(height: 16),
        buildChart('Resolved % by Department', 'resolvedPct', Colors.green),
      ],
    );
  }
}
