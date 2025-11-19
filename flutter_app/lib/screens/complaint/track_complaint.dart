// lib/screens/complaint/track_complaint.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/complaint.dart';

class TrackComplaintScreen extends StatefulWidget {
  const TrackComplaintScreen({Key? key}) : super(key: key);

  @override
  _TrackComplaintScreenState createState() => _TrackComplaintScreenState();
}

class _TrackComplaintScreenState extends State<TrackComplaintScreen> {
  final _idCtrl = TextEditingController();
  Complaint? _foundComplaint;
  bool _searching = false;
  String? _error;

  Future<void> _searchComplaint() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) {
      setState(() {
        _error = "Please enter Complaint ID";
        _foundComplaint = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
      _foundComplaint = null;
    });

    // 1) Try Firestore
    try {
      final doc = await FirebaseFirestore.instance.collection('complaints').doc(id).get();
      if (doc.exists) {
        final map = Map<String, dynamic>.from(doc.data()!);
        setState(() {
          _foundComplaint = Complaint.fromJson(map);
          _searching = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Firestore search failed: $e');
    }

    // 2) Fallback to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('complaints') ?? [];
      for (var item in list) {
        final obj = Complaint.fromJson(json.decode(item));
        if (obj.id == id) {
          setState(() {
            _foundComplaint = obj;
            _searching = false;
          });
          return;
        }
      }
      setState(() {
        _error = "No complaint found with ID $id";
        _searching = false;
      });
    } catch (e) {
      setState(() {
        _error = "Error searching complaints: $e";
        _searching = false;
      });
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF2F6FF),
      appBar: AppBar(
        title: const Text("Track Complaint"),
        backgroundColor: Colors.blue.shade700,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, "/settings"),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.search, size: 60, color: Colors.blue.shade800),
                    const SizedBox(height: 10),
                    Text(
                      "Track Your Complaint",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _idCtrl,
                      decoration: InputDecoration(
                        labelText: "Enter Complaint ID",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.blue.shade200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _searching ? null : _searchComplaint,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _searching
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                "Search",
                                style: TextStyle(fontSize: 16, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(fontSize: 15, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            if (_foundComplaint != null) _buildResultCard(_foundComplaint!),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(Complaint c) {
    Color statusColor = Colors.blue;
    switch (c.status.toLowerCase()) {
      case 'submitted':
        statusColor = Colors.orange;
        break;
      case 'in progress':
      case 'in-progress':
        statusColor = Colors.blue;
        break;
      case 'resolved':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
    }

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Complaint Details",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900)),
            const SizedBox(height: 15),
            _infoRow("Train Number", c.trainNumber),
            _infoRow("Category", c.category),
            _infoRow("Phone", c.phone),
            _infoRow("Location", c.location ?? "Not available"),
            const SizedBox(height: 10),
            Text("Description:",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            Text(c.description, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Status: ${c.status}",
                style: TextStyle(
                  color: statusColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
              width: 130,
              child: Text(
                "$title:",
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900),
              )),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
