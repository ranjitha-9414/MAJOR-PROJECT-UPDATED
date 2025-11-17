import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ComplaintAcknowledgement extends StatefulWidget {
  final Map<String, dynamic> complaintJson;
  const ComplaintAcknowledgement({
    Key? key,
    required this.complaintJson,
  }) : super(key: key);

  @override
  State<ComplaintAcknowledgement> createState() =>
      _ComplaintAcknowledgementState();
}

class _ComplaintAcknowledgementState extends State<ComplaintAcknowledgement> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = widget.complaintJson['id'] ?? '';
      if (id.toString().isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: id.toString()));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complaint ID copied to clipboard')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.complaintJson;

    final id = j['id'] ?? '';
    final name = j['fullName'] ?? '';
    final train = j['trainNumber'] ?? '';
    final dept = j['category'] ?? '';
    final phone = j['phone'] ?? '';
    final location = j['location'] ?? '';
    final desc = j['description'] ?? '';
    final photo = j['photoBase64'];

    return Scaffold(
      backgroundColor: const Color(0xffEAF3FF),

      appBar: AppBar(
        title: const Text("Acknowledgement"),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blueAccent],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: const [
                  Icon(Icons.check_circle, color: Colors.white, size: 70),
                  SizedBox(height: 10),
                  Text(
                    "Complaint Submitted Successfully",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // MAIN CARD
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Complaint ID Row
                      Row(
                        children: [
                          const Text(
                            "Complaint ID: ",
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          Expanded(
                            child: SelectableText(
                              id,
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.black87),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: id.toString()));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Complaint ID Copied")),
                              );
                            },
                          )
                        ],
                      ),
                      const Divider(height: 20),

                      _info("Passenger Name", name),
                      _info("Train Number", train),
                      _info("Department", dept),
                      _info("Phone Number", phone),
                      _info("Location", location),

                      const SizedBox(height: 12),
                      const Text(
                        "Description",
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(desc),

                      // PHOTO SECTION
                      if (photo != null && photo.toString().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          "Attached Photo",
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            base64Decode(photo),
                            height: 170,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // BACK TO HOME BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.home, color: Colors.white),
                  label: const Text(
                    "Back to Home",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
