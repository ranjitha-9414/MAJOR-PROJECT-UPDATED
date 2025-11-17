import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rail_aid/screens/staff/complaint_detail.dart';

/// Staff complaints list view for a specific department.
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

  Future<void> _updateComplaintStatus(String id, String newStatus) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('complaints') ?? <String>[];

    final updated = raw.map((e) {
      try {
        final m = json.decode(e);
        if (m['id'] == id) {
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

  Future<void> _bulkUpdateStatus(String status) async {
    if (_selected.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('complaints') ?? <String>[];

    final updated = raw.map((e) {
      try {
        final m = json.decode(e);
        if (_selected.contains(m['id'].toString())) {
          m['status'] = status;
        }
        return json.encode(m);
      } catch (_) {
        return e;
      }
    }).toList();

    await prefs.setStringList('complaints', updated);
    _selected.clear();
    await _loadComplaints();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updated ${_selected.length} complaints')),
    );
  }

  // ---------- UI SECTION ----------
  Color _deptColor() {
    switch (widget.department) {
      case "Technical":
        return Colors.blue;
      case "Cleaning":
        return Colors.green;
      case "Safety":
        return Colors.red;
      case "Infrastructure":
        return Colors.orange;
      case "Misconduct":
        return Colors.purple;
      default:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _deptColor().withOpacity(0.05),
      appBar: AppBar(
        title: Text('${widget.department} Complaints'),
        backgroundColor: _deptColor(),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadComplaints),
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
              backgroundColor: _deptColor(),
              icon: const Icon(Icons.done),
              label: Text('${_selected.length} selected'),
              onPressed: _showBulkSheet,
            )
          : null,
    );
  }

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
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(child: Text('No complaints in ${widget.department}')),
      );
    }

    final complaint = filtered[index - 1];
    final id = complaint['id'];
    final status = complaint['status'];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Checkbox(
          value: _selected.contains(id.toString()),
          onChanged: (v) {
            setState(() {
              v == true ? _selected.add(id) : _selected.remove(id);
            });
          },
        ),
        title: Text(complaint['fullName'] ?? 'Unknown'),
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
            DropdownMenuItem(value: 'in-progress', child: Text('In-Progress')),
            DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
          ],
          onChanged: (val) async {
            if (val != null) {
              await _updateComplaintStatus(id, val);
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Updated to $val')));
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

  Widget _buildHeader() {
    return Card(
      color: _deptColor().withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _deptColor(),
                  radius: 28,
                  child: Text(
                    _staffName.isNotEmpty
                        ? _staffName[0].toUpperCase()
                        : 'S',
                    style: const TextStyle(fontSize: 22, color: Colors.white),
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
                      Text(_staffEmail, style: const TextStyle(color: Colors.grey)),
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
            const SizedBox(height: 12),
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
                          borderSide: BorderSide.none),
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
            ),
          ],
        ),
      ),
    );
  }

  // ---------- BOTTOM SHEET ----------
  Future<void> _showBulkSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => Navigator.pop(ctx, "open"),
              child: const ListTile(
                leading: Icon(Icons.circle_outlined, color: Colors.red),
                title: Text("Mark Open"),
              ),
            ),
            InkWell(
              onTap: () => Navigator.pop(ctx, "in-progress"),
              child: const ListTile(
                leading: Icon(Icons.sync, color: Colors.orange),
                title: Text("Mark In-Progress"),
              ),
            ),
            InkWell(
              onTap: () => Navigator.pop(ctx, "resolved"),
              child: const ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text("Mark Resolved"),
              ),
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
