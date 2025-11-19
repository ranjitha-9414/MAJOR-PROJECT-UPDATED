// lib/screens/staff/staff_complaints.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rail_aid/screens/staff/complaint_detail.dart';

class StaffComplaints extends StatefulWidget {
  final String department;

  const StaffComplaints({Key? key, required this.department}) : super(key: key);

  @override
  _StaffComplaintsState createState() => _StaffComplaintsState();
}

class _StaffComplaintsState extends State<StaffComplaints> {
  List<Map<String, dynamic>> _complaints = [];
  bool _loading = true;
  String _staffName = 'Staff';
  String _staffEmail = '';
  String _searchQuery = '';
  String _statusFilter = 'all';
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  // ---------------------------------------------------------------------------
  // LOAD COMPLAINTS (Firebase → fallback local)
  // ---------------------------------------------------------------------------
  Future<void> _loadComplaints() async {
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString('current_user');

    if (current != null) {
      _staffEmail = current;
      final raw = prefs.getString('user_$current');

      if (raw != null) {
        try {
          final j = json.decode(raw);
          _staffName = j["name"] ?? current;
        } catch (_) {
          _staffName = current;
        }
      }
    }

    // Try FIRESTORE first
    try {
      final q = await FirebaseFirestore.instance
          .collection('complaints')
          .where('category', isEqualTo: widget.department)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final docs = q.docs.map((d) => {...d.data(), 'id': d.id}).toList();

      setState(() {
        _complaints = docs.cast<Map<String, dynamic>>();
        _loading = false;
      });

      return;
    } catch (e) {
      debugPrint('⚠ Firestore load failed: $e');
    }

    // LOCAL fallback
    final rawList = prefs.getStringList('complaints') ?? <String>[];

    final list = rawList.map((e) {
      try {
        return json.decode(e) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((m) => m.isNotEmpty && (m['category'] ?? '') == widget.department).toList();

    setState(() {
      _complaints = list;
      _loading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // UPDATE STATUS (single)
  // ---------------------------------------------------------------------------
  Future<void> _updateComplaintStatus(String id, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('complaints')
          .doc(id)
          .update({'status': newStatus});
    } catch (e) {
      debugPrint('⚠ Cloud update failed: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('complaints') ?? <String>[];

    final updated = raw.map((e) {
      try {
        final m = json.decode(e);
        if ((m['id'] ?? '') == id) {
          m['status'] = newStatus;
        }
        return json.encode(m);
      } catch (_) {
        return e;
      }
    }).toList();

    await prefs.setStringList('complaints', updated);
    await _loadComplaints();
  }

  // ---------------------------------------------------------------------------
  // BULK UPDATE STATUS
  // ---------------------------------------------------------------------------
  Future<void> _bulkUpdateStatus(String status) async {
    if (_selected.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('complaints') ?? <String>[];

    try {
      for (final id in _selected) {
        await FirebaseFirestore.instance
            .collection('complaints')
            .doc(id)
            .update({'status': status});
      }
    } catch (e) {
      debugPrint('⚠ Bulk cloud update failed: $e');
    }

    final updated = raw.map((e) {
      try {
        final m = json.decode(e);
        if (_selected.contains((m['id'] ?? '').toString())) {
          m['status'] = status;
        }
        return json.encode(m);
      } catch (_) {
        return e;
      }
    }).toList();

    await prefs.setStringList('complaints', updated);
    final count = _selected.length;

    _selected.clear();
    await _loadComplaints();

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Updated $count complaints')));
  }

  // ---------------------------------------------------------------------------
  // DEPARTMENT COLORS (Enhanced Modern Styling)
  // ---------------------------------------------------------------------------
  Color _deptPrimary() {
    switch (widget.department) {
      case "Technical":
        return Colors.blue.shade700;
      case "Cleaning":
        return Colors.green.shade700;
      case "Safety":
        return Colors.red.shade700;
      case "Infrastructure":
        return Colors.orange.shade700;
      case "Misconduct":
        return Colors.purple.shade700;
      default:
        return Colors.teal.shade700;
    }
  }

  Color _deptLight() => _deptPrimary().withOpacity(0.10);

  IconData _deptIcon() {
    switch (widget.department) {
      case "Technical":
        return Icons.engineering;
      case "Cleaning":
        return Icons.cleaning_services;
      case "Safety":
        return Icons.security;
      case "Infrastructure":
        return Icons.construction;
      case "Misconduct":
        return Icons.report_problem;
      default:
        return Icons.category;
    }
  }

  // ---------------------------------------------------------------------------
  // UI BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _deptLight(),
      appBar: AppBar(
        backgroundColor: _deptPrimary(),
        title: Row(
          children: [
            Icon(_deptIcon(), color: Colors.white),
            const SizedBox(width: 8),
            Text('${widget.department} Dept'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadComplaints,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadComplaints,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: (_complaints.isEmpty ? 1 : _complaints.length + 1),
                itemBuilder: _buildListItem,
              ),
            ),

      floatingActionButton: _selected.isNotEmpty
          ? FloatingActionButton.extended(
              backgroundColor: _deptPrimary(),
              icon: const Icon(Icons.done),
              label: Text('${_selected.length} selected'),
              onPressed: _showBulkSheet,
            )
          : null,
    );
  }

  // HEADER CARD
  Widget _buildHeader() {
    return Card(
      color: _deptLight(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _deptPrimary(),
                  radius: 28,
                  child: Text(
                    _staffName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hello, $_staffName',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(_staffEmail,
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                Text(
                  '${_complaints.length}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                )
              ],
            ),
            const SizedBox(height: 14),

            // Search + Filter
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search complaint...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text("All")),
                    DropdownMenuItem(value: 'open', child: Text("Open")),
                    DropdownMenuItem(
                        value: 'in-progress', child: Text("In-Progress")),
                    DropdownMenuItem(value: 'resolved', child: Text("Resolved")),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v!),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // LIST ITEMS
  Widget _buildListItem(BuildContext context, int index) {
    if (index == 0) return _buildHeader();

    final filtered = _complaints.where((m) {
      final status = (m['status'] ?? '').toString();
      if (_statusFilter != 'all' && status != _statusFilter) return false;

      if (_searchQuery.isEmpty) return true;

      final q = _searchQuery.toLowerCase();
      return m.values.any((v) => v.toString().toLowerCase().contains(q));
    }).toList();

    if (filtered.isEmpty) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Text(
            'No complaints in ${widget.department}',
            style: TextStyle(color: _deptPrimary(), fontSize: 16),
          ),
        ),
      );
    }

    final complaint = filtered[index - 1];
    final id = complaint['id'];
    final status = complaint['status'] ?? 'open';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Checkbox(
          value: _selected.contains(id.toString()),
          activeColor: _deptPrimary(),
          onChanged: (v) {
            setState(() {
              v == true ? _selected.add(id) : _selected.remove(id);
            });
          },
        ),
        title: Text(complaint['fullName'] ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          (complaint['description'] ?? '')
              .toString()
              .replaceAll("\n", " "),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: DropdownButton<String>(
          value: status,
          underline: const SizedBox(),
          items: const [
            DropdownMenuItem(value: 'open', child: Text('Open')),
            DropdownMenuItem(
                value: 'in-progress', child: Text('In-Progress')),
            DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
          ],
          onChanged: (val) async {
            if (val != null) {
              await _updateComplaintStatus(id, val);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Updated to $val')));
            }
          },
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    ComplaintDetail(complaintJson: complaint)),
          );
          _loadComplaints();
        },
      ),
    );
  }

  // BULK ACTION SHEET
  Future<void> _showBulkSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.circle_outlined, color: Colors.red),
              title: const Text("Mark Open"),
              onTap: () => Navigator.pop(ctx, "open"),
            ),
            ListTile(
              leading: const Icon(Icons.sync, color: Colors.orange),
              title: const Text("Mark In-Progress"),
              onTap: () => Navigator.pop(ctx, "in-progress"),
            ),
            ListTile(
              leading:
                  const Icon(Icons.check_circle, color: Colors.green),
              title: const Text("Mark Resolved"),
              onTap: () => Navigator.pop(ctx, "resolved"),
            ),
          ],
        ),
      ),
    );

    if (choice != null) {
      await _bulkUpdateStatus(choice);
    }
  }
}
