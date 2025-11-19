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

class _ComplaintAcknowledgementState
    extends State<ComplaintAcknowledgement> {
  @override
  void initState() {
    super.initState();

    // Auto-copy complaint ID after screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = widget.complaintJson['id'] ?? '';
      if (id.toString().isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: id.toString()));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complaint ID copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
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
    final location = j['location'] ?? 'Not provided';
    final desc = j['description'] ?? '';
    final photo = j['photoBase64'];

    return Scaffold(
      backgroundColor: const Color(0xffEAF3FF),

      appBar: AppBar(
        title: const Text("Acknowledgement"),
        backgroundColor: Colors.blue.shade800,
        elevation: 1,
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            _successHeader(),

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
                      _complaintIdRow(id),

                      const Divider(height: 20),

                      _info("Passenger Name", name),
                      _info("Train Number", train),
                      _info("Department", dept),
                      _info("Phone Number", phone),
                      _info("Location", location),

                      const SizedBox(height: 12),

                      const Text("Description",
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 6),
                      Text(desc),

                      if (photo != null && photo.toString().isNotEmpty)
                        _photoPreview(photo),
                    ],
                  ),
                ),
              ),
            ),

            _backToHomeButton(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // SUCCESS HEADER
  // -------------------------------------------------------
  Widget _successHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade900,
            Colors.blue.shade600,
            Colors.blue.shade300
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        children: const [
          Icon(Icons.check_circle, color: Colors.white, size: 70),
          SizedBox(height: 12),
          Text(
            "Complaint Submitted Successfully",
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // COMPLAINT ID ROW (copy button)
  // -------------------------------------------------------
  Widget _complaintIdRow(String id) {
    return Row(
      children: [
        const Text(
          "Complaint ID: ",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        Expanded(
          child: SelectableText(
            id,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: id));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Complaint ID Copied")),
            );
          },
        )
      ],
    );
  }

  // -------------------------------------------------------
  // INFO ROW HELPER
  // -------------------------------------------------------
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

  // -------------------------------------------------------
  // PHOTO PREVIEW
  // -------------------------------------------------------
  Widget _photoPreview(String base64Image) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Text(
          "Attached Photo",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            base64Decode(base64Image),
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------
  // BACK TO HOME BUTTON
  // -------------------------------------------------------
  Widget _backToHomeButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade800,
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
    );
  }
}
