// lib/screens/complaint/new_complaint.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/geolocation_stub.dart' if (dart.library.html) '../../services/geolocation_web.dart';
import '../../utils/validators.dart';
import '../../services/ip_geolocation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/complaint.dart';
import 'acknowledgement.dart';

class NewComplaintScreen extends StatefulWidget {
  const NewComplaintScreen({Key? key}) : super(key: key);

  @override
  _NewComplaintScreenState createState() => _NewComplaintScreenState();
}

class _NewComplaintScreenState extends State<NewComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _trainCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  String _gender = 'Male';
  String _department = 'Technical';
  String? _photoBase64;
  bool _submitting = false;

  final _departments = ['Technical', 'Cleaning', 'Infrastructure', 'Safety', 'Misconduct', 'Other'];

  @override
  void dispose() {
    _descCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _trainCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0D47A1);
    const lightBlue = Color(0xFFE3F2FD);

    return Scaffold(
      backgroundColor: lightBlue,
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        title: const Text('File Complaint', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Container(
            decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: const [
                Icon(Icons.train, color: Colors.white, size: 36),
                SizedBox(width: 12),
                Expanded(
                  child: Text('RailAid', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(_nameCtrl, 'Full name', validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                    const SizedBox(height: 12),
                    _buildDropdown<String>(
                      value: _gender,
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      label: 'Gender',
                      onChanged: (v) => setState(() => _gender = v ?? _gender),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(_trainCtrl, 'Train number', validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                    const SizedBox(height: 12),
                    _buildDropdown<String>(
                      value: _department,
                      items: _departments.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      label: 'Department',
                      onChanged: (v) => setState(() => _department = v ?? _department),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Upload Image'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 76, 142, 240), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        ),
                        const SizedBox(width: 12),
                        if (_photoBase64 != null) _imagePreview(_photoBase64!) else const Text('No image', style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(_phoneCtrl, 'Phone number', keyboardType: TextInputType.phone, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                    const SizedBox(height: 12),

                    Row(children: [
                      Expanded(
                        child: _buildTextField(_locationCtrl, 'Location (lat, lng)', readOnly: true, hint: 'Press Locate'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _getLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text('Locate'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 107, 161, 242), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _buildTextField(_descCtrl, 'Complaint description', minLines: 3, maxLines: 6, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 222, 34, 228), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        child: _submitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color.fromARGB(255, 247, 246, 246)))
                            : const Text('Submit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePreview(String base64Str) {
    try {
      final bytes = base64.decode(base64Str);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(bytes, width: 64, height: 64, fit: BoxFit.cover),
      );
    } catch (_) {
      return const Text('Preview unavailable', style: TextStyle(color: Colors.black54));
    }
  }

  Widget _buildTextField(TextEditingController ctrl, String label,
      {String? Function(String?)? validator, TextInputType? keyboardType, bool readOnly = false, String? hint, int minLines = 1, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      readOnly: readOnly,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDropdown<T>({required T value, required List<DropdownMenuItem<T>> items, required String label, required void Function(T?)? onChanged}) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? x = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      setState(() => _photoBase64 = base64.encode(bytes));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image pick failed: $e')));
    }
  }

  Future<void> _getLocation() async {
    try {
      if (!kIsWeb) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied.')));
            return;
          }
        }
        if (permission == LocationPermission.deniedForever) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied.')));
          return;
        }
      }

      if (kIsWeb) {
        final loc = await getBrowserLocation();
        if (loc != null) {
          final lat = loc['lat']!;
          final lng = loc['lng']!;
          _locationCtrl.text = '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location obtained (browser): ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}')));
          setState(() {});
        } else {
          final ipLoc = await getIpLocation();
          if (ipLoc != null) {
            final lat = ipLoc['lat'] as double;
            final lng = ipLoc['lng'] as double;
            _locationCtrl.text = '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Using approximate location from IP')));
            setState(() {});
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Browser geolocation unavailable or permission denied.')));
          }
        }
      } else {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        final lat = pos.latitude;
        final lng = pos.longitude;
        _locationCtrl.text = '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location obtained (device): ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}')));
        setState(() {});
      }
    } on MissingPluginException catch (_) {
      await _showLocationFailureDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
    }
  }

  Future<void> _showLocationFailureDialog() async {
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location unavailable'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Geolocation is unavailable or permission was denied.'),
              const SizedBox(height: 8),
              const Text('Steps to enable (browser):'),
              const Text('- Allow location permission in the browser address bar.'),
              const Text('- Ensure the app is served over HTTPS or localhost.'),
              const SizedBox(height: 12),
              const Text('Or enter location manually (lat, lng):'),
              Row(children: [Expanded(child: TextField(controller: latCtrl, decoration: const InputDecoration(hintText: 'Latitude'))), const SizedBox(width:8), Expanded(child: TextField(controller: lngCtrl, decoration: const InputDecoration(hintText: 'Longitude')))]),
              const SizedBox(height: 8),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final lat = latCtrl.text.trim();
              final lng = lngCtrl.text.trim();
              if (lat.isNotEmpty && lng.isNotEmpty) {
                _locationCtrl.text = '$lat, $lng';
                Navigator.of(ctx).pop();
                setState(() {});
                return;
              }
            },
            child: const Text('Use manual')),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final phone = _phoneCtrl.text.trim();
    if (!isValidPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid phone number')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm complaint'),
        content: Text('Submit complaint for ${_nameCtrl.text.trim()}\nTrain: ${_trainCtrl.text.trim()}\nDepartment: $_department'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Submit')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);

    final prefs = await SharedPreferences.getInstance();
    final listRaw = prefs.getStringList('complaints') ?? <String>[];
    final id = await _generateComplaintId(_department);
    final complaint = Complaint(
      id: id,
      fullName: _nameCtrl.text.trim(),
      gender: _gender,
      trainNumber: _trainCtrl.text.trim(),
      category: _department,
      description: _descCtrl.text.trim(),
      phone: normalizePhone(phone),
      photoBase64: _photoBase64,
      location: _locationCtrl.text.isNotEmpty ? _locationCtrl.text : null,
      userEmail: 'local',
    );

    // 1) Try to save to Firestore (best-effort). If it fails, we still persist locally.
    bool savedToFirestore = false;
    try {
      final doc = FirebaseFirestore.instance.collection('complaints').doc(complaint.id);
      await doc.set(complaint.toJson());
      savedToFirestore = true;
    } catch (e) {
      // Firestore not available or offline - fallback will handle local saving
      debugPrint('Firestore save failed: $e');
    }

    // 2) Always save locally as a fallback / offline replica
    try {
      listRaw.insert(0, json.encode(complaint.toJson()));
      await prefs.setStringList('complaints', listRaw);
    } catch (e) {
      debugPrint('Local save failed: $e');
    }

    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(savedToFirestore ? 'Complaint submitted (synced to cloud)' : 'Complaint saved locally (offline)')),
    );

    // Navigate to acknowledgement page
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComplaintAcknowledgement(complaintJson: complaint.toJson())));
  }

  Future<String> _generateComplaintId(String department) async {
    const map = {
      'Technical': 'TEC',
      'Cleaning': 'CLN',
      'Infrastructure': 'INF',
      'Safety': 'SAF',
      'Misconduct': 'MIS',
      'Other': 'OTH',
    };
    final code = map[department] ?? 'OTH';
    final prefs = await SharedPreferences.getInstance();
    final listRaw = prefs.getStringList('complaints') ?? <String>[];
    var maxNum = 0;
    for (final e in listRaw) {
      try {
        final m = json.decode(e) as Map<String, dynamic>;
        final existingId = (m['id'] ?? '').toString();
        final prefix = 'RWC$code';
        if (existingId.startsWith(prefix)) {
          final suffix = existingId.substring(prefix.length);
          final num = int.tryParse(suffix) ?? 0;
          if (num > maxNum) maxNum = num;
        }
      } catch (_) {}
    }
    final next = maxNum + 1;
    final suffixStr = next.toString().padLeft(5, '0');
    return 'RWC${code}$suffixStr';
  }
}
