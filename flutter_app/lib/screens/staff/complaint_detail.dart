import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ComplaintDetail extends StatefulWidget {
  final Map<String, dynamic> complaintJson;
  const ComplaintDetail({Key? key, required this.complaintJson})
      : super(key: key);

  @override
  _ComplaintDetailState createState() => _ComplaintDetailState();
}

class _ComplaintDetailState extends State<ComplaintDetail> {
  late Map<String, dynamic> c;
  String _staffName = 'Staff';
  String _staffEmail = '';

  @override
  void initState() {
    super.initState();
    c = Map<String, dynamic>.from(widget.complaintJson);
    _loadStaffInfo();
  }

  Future<void> _loadStaffInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString('current_user');
    if (current != null) {
      final userRaw = prefs.getString('user_$current');
      if (userRaw != null) {
        try {
          final j = json.decode(userRaw) as Map<String, dynamic>;
          _staffName = j['name'] ?? current;
        } catch (_) {
          _staffName = current;
        }
      } else {
        _staffName = current;
      }
      _staffEmail = current;
      setState(() {});
    }
  }

  Future<void> _saveChanges() async {
    final prefs = await SharedPreferences.getInstance();
    final listRaw = prefs.getStringList('complaints') ?? <String>[];
    final idx = listRaw.indexWhere((e) {
      try {
        final m = json.decode(e) as Map<String, dynamic>;
        return m['id'] == c['id'];
      } catch (_) {
        return false;
      }
    });

    if (idx >= 0) {
      listRaw[idx] = json.encode(c);
      await prefs.setStringList('complaints', listRaw);
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Saved')));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.redAccent;
      case 'in-progress':
        return Colors.orangeAccent;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _infoRow(String title, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$title: ",
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = c['id'] ?? '';
    final title = c['fullName'] ?? 'Complaint';
    final status = c['status'] ?? 'open';
    final phone = c['phone'] ?? '';
    final train = c['trainNumber'] ?? '';
    final desc = c['description'] ?? '';
    final loc = c['location'] ?? '';
    final notes =
        (c['staffNotes'] as List<dynamic>?)?.cast<String>() ?? <String>[];

    return Scaffold(
      appBar: AppBar(
        title: Text('Complaint $id'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            /// --------------------
            /// HEADER CARD
            /// --------------------
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.redAccent,
                      child: const Icon(Icons.report,
                          size: 35, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Chip(
                              label: Text(status.toUpperCase()),
                              backgroundColor:
                                  _statusColor(status).withOpacity(0.15),
                              labelStyle: TextStyle(
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.bold),
                            )
                          ]),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_staffName,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(_staffEmail,
                            style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            /// --------------------
            /// PHOTO (if any)
            /// --------------------
            if ((c['photoBase64'] as String?)?.isNotEmpty == true)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(c['photoBase64']),
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

            const SizedBox(height: 18),

            /// --------------------
            /// DETAILS CARD
            /// --------------------
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Complaint Details",
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      _infoRow("Train", train),
                      _infoRow("Phone", phone),
                      _infoRow("Gender", c['gender'] ?? ''),
                      _infoRow("Location", loc),

                      const SizedBox(height: 12),
                      const Text("Description",
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(desc, style: const TextStyle(fontSize: 14)),
                    ]),
              ),
            ),

            const SizedBox(height: 18),

            /// --------------------
            /// ACTION BUTTONS
            /// --------------------
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: status == 'in-progress'
                        ? null
                        : () async {
                            c['status'] = 'in-progress';
                            await _saveChanges();
                            setState(() {});
                          },
                    child: const Text('Mark In-Progress'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: status == 'resolved'
                        ? null
                        : () async {
                            c['status'] = 'resolved';
                            await _saveChanges();
                            setState(() {});
                          },
                    child: const Text('Mark Resolved'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            /// --------------------
            /// STAFF NOTES
            /// --------------------
            if (notes.isNotEmpty)
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Staff Notes",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        ...notes
                            .map((n) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 10.0),
                                  child: Text(
                                    "• $n",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ))
                            .toList(),
                      ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
