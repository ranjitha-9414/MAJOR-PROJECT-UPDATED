// lib/screens/complaint/new_complaint.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  String _department = 'Click Classify button to show category';
  String? _classifyPhotoBase64;
  List<String> _referencePhotos = <String>[];
  bool _submitting = false;
  int? _expandedImageIndex;

  final _departments = ['Technical', 'Cleaning', 'Infrastructure', 'Safety', 'Misconduct', 'Overcrowd', 'Other'];

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
                    _buildTextField(_trainCtrl, 'Train number', keyboardType: TextInputType.text, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                    const SizedBox(height: 12),
                    // Department is now determined automatically by the classifier
                    Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                const Icon(Icons.shield, color: Colors.black54),
                                const SizedBox(width: 12),
                                Expanded(child: Text('Department (automated): $_department', style: const TextStyle(fontWeight: FontWeight.w600))),
                              ],
                            ),
                          ),
                    const SizedBox(height: 12),

                    // (Classify button moved below the description)

                    const SizedBox(height: 12),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _showImageSourceOptions(true),
                              icon: const Icon(Icons.photo_camera),
                              label: const Text('Upload image for classify'),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 76, 142, 240), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () => _showImageSourceOptions(false),
                              child: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Thumbnails area: classify thumbnail + references
                        Row(children: [
                          if (_classifyPhotoBase64 != null)
                            GestureDetector(
                              onTap: () => setState(() => _expandedImageIndex = _expandedImageIndex == 0 ? null : 0),
                              child: Stack(
                                children: [
                                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(_classifyPhotoBase64!), width: 140, height: 84, fit: BoxFit.cover)),
                                  Positioned(
                                    right: 6,
                                    top: 6,
                                    child: Material(
                                      color: Colors.black45,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        onTap: () => setState(() => _expandedImageIndex = _expandedImageIndex == 0 ? null : 0),
                                        customBorder: const CircleBorder(),
                                        child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove_red_eye, color: Colors.white, size: 18)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            const Text('No classify image', style: TextStyle(color: Colors.black54)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _referencePhotos.isNotEmpty
                                ? SizedBox(
                                    height: 84,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemBuilder: (ctx, i) => Stack(
                                        children: [
                                          GestureDetector(
                                            onTap: () => setState(() => _expandedImageIndex = _expandedImageIndex == i + 1 ? null : i + 1),
                                            child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(_referencePhotos[i]), width: 140, height: 84, fit: BoxFit.cover)),
                                          ),
                                          Positioned(
                                            top: 4,
                                            left: 4,
                                            child: GestureDetector(
                                              onTap: () => setState(() => _referencePhotos.removeAt(i)),
                                              child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: Colors.white)),
                                            ),
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Material(
                                              color: Colors.black45,
                                              shape: const CircleBorder(),
                                              child: InkWell(
                                                onTap: () => setState(() => _expandedImageIndex = _expandedImageIndex == i + 1 ? null : i + 1),
                                                customBorder: const CircleBorder(),
                                                child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove_red_eye, color: Colors.white, size: 16)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                                      itemCount: _referencePhotos.length,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        // Inline expanded preview (same-page) if any
                        if (_expandedImageIndex != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: GestureDetector(
                              onTap: () => setState(() => _expandedImageIndex = null),
                              child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(base64Decode(_expandedImageIndex == 0 ? _classifyPhotoBase64! : _referencePhotos[_expandedImageIndex! - 1]), height: 220, width: double.infinity, fit: BoxFit.contain)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(_phoneCtrl, 'Phone number', keyboardType: TextInputType.phone, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                    const SizedBox(height: 12),

                    Row(children: [
                      Expanded(
                        child: _buildTextField(_locationCtrl, 'Location (lat, lng)', readOnly: true, hint: 'Press Locate', validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
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
                    const SizedBox(height: 12),
                    // Classify button placed after image+description and before submit
                    Center(
                      child: Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _classifying ? null : _runClassifier,
                            icon: _classifying
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.analytics),
                            label: const Text('Classify'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 58, 123, 213), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                          ),
                          const SizedBox(height: 8),
                          if (_showSteps)
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,2))]),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _statusRow(_stepStarted, 'Classification started using yolov8'),
                                  const SizedBox(height: 8),
                                  _statusRow(_stepGetting, 'Getting category'),
                                  const SizedBox(height: 8),
                                  _statusRow(_stepFound, 'Classification found'),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (_submitting || !_classified) ? null : _submit,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 222, 34, 228), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        child: _submitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color.fromARGB(255, 247, 246, 246)))
                            : !_classified
                                ? const Text('Submit (Run Classify)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
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

  Widget _statusRow(bool done, String label) {
    return Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: done
              ? Container(key: const ValueKey('done'), padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.green.shade600, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 16))
              : Container(key: const ValueKey('pending'), padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), shape: BoxShape.circle), child: Icon(Icons.hourglass_top, color: Colors.grey.shade600, size: 14)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(color: done ? Colors.black87 : Colors.black54, fontSize: 13, fontWeight: done ? FontWeight.w600 : FontWeight.normal))),
      ],
    );
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

  Future<void> _showImageSourceOptions(bool isClassify) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Use Camera'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImageFrom(ImageSource.camera, isClassify);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImageFrom(ImageSource.gallery, isClassify);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFrom(ImageSource source, bool isClassify) async {
    try {
      final picker = ImagePicker();
      final XFile? x = await picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final b64 = base64.encode(bytes);
      setState(() {
        if (isClassify) {
          _classifyPhotoBase64 = b64;
        } else {
          _referencePhotos.add(b64);
        }
      });
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

    // Ensure classify image is present (classifier requires both image + text)
    if (_classifyPhotoBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload an image — required for automatic classification')));
      return;
    }

    // Ensure location is provided
    if (_locationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide location (use Locate) — required')));
      return;
    }

    // Confirm submission after automatic classification will be run below
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm complaint'),
        content: Text('Submit complaint for ${_nameCtrl.text.trim()}\nTrain: ${_trainCtrl.text.trim()}\nDepartment will be assigned automatically'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Submit')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);

    // Must classify before submitting
    if (!_classified) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please run classification before submitting')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final listRaw = prefs.getStringList('complaints') ?? <String>[];
    final id = await _generateComplaintId(_department);

    // Use Firebase authenticated user email if available (since you chose option A)
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final userEmail = firebaseUser?.email ?? prefs.getString('current_user') ?? 'local';

    final complaint = Complaint(
      id: id,
      fullName: _nameCtrl.text.trim(),
      gender: _gender,
      trainNumber: _trainCtrl.text.trim(),
      category: _department,
      description: _descCtrl.text.trim(),
      phone: normalizePhone(phone),
      photoBase64: _classifyPhotoBase64,
      classifyPhotoBase64: _classifyPhotoBase64,
      referencePhotos: _referencePhotos,
      classifierLabel: _classifierLabel,
      classifierConfidence: _classifierConfidence,
      location: _locationCtrl.text.isNotEmpty ? _locationCtrl.text : null,
      userEmail: userEmail,
    );

    // 1) Try to save to Firestore (best-effort).
    bool savedToFirestore = false;
    try {
      final docRef = FirebaseFirestore.instance.collection('complaints').doc(complaint.id);

      // Build cloud map and set server timestamp for createdAt to keep uniform type
      final cloudMap = Map<String, dynamic>.from(complaint.toJson());
      // Remove createdAt string and set server timestamp instead
      cloudMap['createdAt'] = FieldValue.serverTimestamp();
      // ensure userEmail is correct (authenticated)
      cloudMap['userEmail'] = userEmail;

      await docRef.set(cloudMap);
      savedToFirestore = true;
    } catch (e) {
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

    // Navigate to acknowledgement page. Use pushReplacement so when the user
    // closes the acknowledgement they return to the dashboard (the original
    // NewComplaint route is replaced) which allows the dashboard to reload
    // and show the newly saved complaint immediately.
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ComplaintAcknowledgement(complaintJson: complaint.toJson())));
  }

  bool _classified = false;
  bool _classifying = false;
  bool _stepStarted = false;
  bool _stepGetting = false;
  bool _stepFound = false;
  bool _showSteps = false;
  String? _classifierLabel;
  double? _classifierConfidence;

  Future<void> _runClassifier() async {
    if (_classifyPhotoBase64 == null || _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide both image and description before classification')));
      return;
    }
    setState(() {
      _classifying = true;
      _showSteps = true;
      _stepStarted = false;
      _stepGetting = false;
      _stepFound = false;
    });

    try {
      // Step 1: mark started and show it briefly
      setState(() => _stepStarted = true);
      await Future.delayed(const Duration(milliseconds: 350));
      // Step 2: getting
      setState(() => _stepGetting = true);

      final envBackend = const String.fromEnvironment('BACKEND_URL', defaultValue: '');
      final backendBase = envBackend.isNotEmpty ? envBackend : (kIsWeb ? 'http://127.0.0.1:3000' : 'http://10.0.2.2:3000');
      final classifyUri = Uri.parse('$backendBase/api/classify');
      final payload = json.encode({'description': _descCtrl.text.trim(), 'photoBase64': _classifyPhotoBase64});

      final resp = await http.post(classifyUri, headers: {'Content-Type': 'application/json'}, body: payload).timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final classification = body['classification'];
        String predicted = '';
        double conf = 0.0;
        if (classification is Map) {
          if (classification.containsKey('category') && classification['category'] != null) {
            predicted = classification['category'].toString();
          } else if (classification.containsKey('label') && classification['label'] != null) {
            predicted = classification['label'].toString();
          } else if (classification.containsKey('raw')) {
            final raw = classification['raw'];
            if (raw is Map) {
              final fd = raw['final_decision'] ?? raw['ensemble'] ?? raw;
              if (fd is Map && fd.containsKey('label')) predicted = fd['label'].toString();
            }
          }
          conf = double.tryParse(classification['confidence']?.toString() ?? '') ?? 0.0;
        }
        if (predicted.isNotEmpty) {
          final mapped = _mapToAppDepartment(predicted);
          setState(() {
            _department = mapped;
            _classified = true;
            _stepFound = true;
            _classifierLabel = predicted;
            _classifierConfidence = conf;
          });
          // let user see final state briefly
          await Future.delayed(const Duration(milliseconds: 600));
          setState(() {
            _showSteps = false;
            _stepStarted = false;
            _stepGetting = false;
            _stepFound = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto-assigned department: $mapped (${(conf*100).toStringAsFixed(1)}%)')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Classifier returned no category')));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Classifier failed: ${resp.statusCode}')));
      }
    } catch (e) {
      debugPrint('Classifier call failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Classifier call failed')));
    } finally {
      // ensure UI resets
      await Future.delayed(const Duration(milliseconds: 250));
      setState(() {
        _classifying = false;
        // hide steps if still visible
        _showSteps = false;
        _stepStarted = false;
        _stepGetting = false;
        _stepFound = false;
      });
    }
  }

  String _mapToAppDepartment(String cls) {
    final low = cls.toLowerCase();
    if (low.contains('clean')) return 'Cleaning';
    if (low.contains('tech') || low.contains('technical')) return 'Technical';
    if (low.contains('infrastruct') || low.contains('infrastructure')) return 'Infrastructure';
    if (low.contains('safety')) return 'Safety';
    if (low.contains('misconduct') || low.contains('misbehav')) return 'Misconduct';
    if (low.contains('crowd') || low.contains('overcrowd') || low.contains('overcrowding')) return 'Overcrowd';
    return 'Other';
  }

  Future<String> _generateComplaintId(String department) async {
    const map = {
      'Technical': 'TEC',
      'Cleaning': 'CLN',
      'Infrastructure': 'INF',
      'Safety': 'SAF',
      'Misconduct': 'MIS',
      'Overcrowd': 'OVR',
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
