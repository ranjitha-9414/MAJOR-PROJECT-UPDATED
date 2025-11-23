// lib/screens/staff/complaint_detail.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ComplaintDetail extends StatefulWidget {
  final Map<String, dynamic> complaintJson;
  const ComplaintDetail({Key? key, required this.complaintJson}) : super(key: key);

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
    // 1) Update Firestore if document exists (best-effort)
    try {
      final id = c['id']?.toString();
      if (id != null && id.isNotEmpty) {
        final docRef = FirebaseFirestore.instance.collection('complaints').doc(id);
        final snapshot = await docRef.get();
        if (snapshot.exists) {
          await docRef.update(c);
        } else {
          // If doc didn't exist in cloud, try to create it (safe)
          await docRef.set(c);
        }
      }
    } catch (e) {
      debugPrint('Firestore update/create failed: $e');
    }

    // 2) Update local SharedPreferences list
    try {
      final prefs = await SharedPreferences.getInstance();
      final listRaw = prefs.getStringList('complaints') ?? <String>[];
      final idx = listRaw.indexWhere((e) {
        try {
          final m = json.decode(e) as Map<String, dynamic>;
          return (m['id'] ?? '') == (c['id'] ?? '');
        } catch (_) {
          return false;
        }
      });
      if (idx >= 0) {
        listRaw[idx] = json.encode(c);
      } else {
        listRaw.insert(0, json.encode(c));
      }
      await prefs.setStringList('complaints', listRaw);
    } catch (e) {
      debugPrint('Local save failed: $e');
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    setState(() {});
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
          Text("$title: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
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
    final notes = (c['staffNotes'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    final classifyPhoto = (c['classifyPhotoBase64'] as String?) ?? (c['photoBase64'] as String?);
    final refPhotos = (c['referencePhotos'] as List<dynamic>?)?.cast<String>() ?? <String>[];

    return Scaffold(
      appBar: AppBar(
        title: Text('Complaint $id'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Allow staff to quickly clear current user (local) - this is optional
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('current_user');
              Navigator.pushReplacementNamed(context, '/login');
            },
            tooltip: 'Logout',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(radius: 32, backgroundColor: Colors.redAccent, child: const Icon(Icons.report, size: 35, color: Colors.white)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Chip(label: Text(status.toString().toUpperCase()), backgroundColor: _statusColor(status).withOpacity(0.15), labelStyle: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold))
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(_staffName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(_staffEmail, style: const TextStyle(color: Colors.grey)),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if ((classifyPhoto)?.isNotEmpty == true)
              GestureDetector(
                onTap: () => _openImageViewer(0, classifyPhoto, refPhotos),
                child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(base64Decode(classifyPhoto!), height: 220, width: double.infinity, fit: BoxFit.contain)),
              ),
            if (refPhotos.isNotEmpty) const SizedBox(height: 12),
            if (refPhotos.isNotEmpty)
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (ctx, i) => GestureDetector(
                    onTap: () => _openImageViewer(i + 1, classifyPhoto, refPhotos),
                    child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(refPhotos[i]), width: 140, height: 84, fit: BoxFit.cover)),
                  ),
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: refPhotos.length,
                ),
              ),
            const SizedBox(height: 18),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Complaint Details", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _infoRow("Train", train),
                  _infoRow("Phone", phone),
                  _infoRow("Gender", c['gender'] ?? ''),
                  _infoRow("Location", loc),
                  const SizedBox(height: 12),
                  // Classifier audit info (if available)
                  Builder(builder: (_) {
                    final cl = c['classifierLabel'] as String? ?? '';
                    final ccRaw = c['classifierConfidence'];
                    String classifierText = '';
                    if (cl.isNotEmpty) {
                      final cc = ccRaw is num ? ccRaw.toDouble() : double.tryParse(ccRaw?.toString() ?? '');
                      if (cc != null) classifierText = '$cl (${(cc * 100).toStringAsFixed(1)}%)'; else classifierText = cl;
                    }
                    return classifierText.isNotEmpty ? _infoRow('Classifier', classifierText) : const SizedBox.shrink();
                  }),
                  const SizedBox(height: 12),
                  const Text("Description", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(desc, style: const TextStyle(fontSize: 14)),
                ]),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: status == 'in-progress'
                      ? null
                      : () async {
                          c['status'] = 'in-progress';
                          await _saveChanges();
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
                        },
                  child: const Text('Mark Resolved'),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            if (notes.isNotEmpty)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Staff Notes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...notes.map((n) => Padding(padding: const EdgeInsets.only(bottom: 10.0), child: Text("• $n", style: const TextStyle(fontSize: 14)))).toList(),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openImageViewer(int startIndex, String? classifyPhoto, List<String> refPhotos) {
    final images = <String>[];
    if (classifyPhoto != null && classifyPhoto.isNotEmpty) images.add(classifyPhoto);
    images.addAll(refPhotos);

    if (images.isEmpty) return;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
        body: PageView.builder(
          controller: PageController(initialPage: startIndex),
          itemCount: images.length,
          itemBuilder: (ctx, i) => Center(child: InteractiveViewer(child: Image.memory(base64Decode(images[i]), fit: BoxFit.contain))),
        ),
      ),
    ));
  }
}
