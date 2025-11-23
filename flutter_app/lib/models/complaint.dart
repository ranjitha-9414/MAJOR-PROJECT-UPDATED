// lib/models/complaint.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Complaint {
  final String id;
  final String fullName;
  final String gender;
  final String trainNumber;
  final String category;
  final String description;
  final String phone;
  final String? photoBase64;
  final String? classifyPhotoBase64;
  final List<String>? referencePhotos;
  final String? classifierLabel;
  final double? classifierConfidence;
  final String? location;
  final String? address;
  final String status;
  final String userEmail;
  final DateTime createdAt;

  Complaint({
    required this.id,
    required this.fullName,
    required this.gender,
    required this.trainNumber,
    required this.category,
    required this.description,
    required this.phone,
    this.photoBase64,
    this.classifyPhotoBase64,
    this.referencePhotos,
    this.classifierLabel,
    this.classifierConfidence,
    this.location,
    this.address,
    this.status = 'open',
    required this.userEmail,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // ---------- JSON TO MODEL ----------
  factory Complaint.fromJson(Map<String, dynamic> j) {
    // createdAt can be String (ISO), Timestamp, int (ms), or DateTime
    DateTime created;
    final raw = j['createdAt'];
    if (raw == null) {
      created = DateTime.now();
    } else if (raw is Timestamp) {
      created = raw.toDate();
    } else if (raw is DateTime) {
      created = raw;
    } else if (raw is int) {
      // unix millis
      created = DateTime.fromMillisecondsSinceEpoch(raw);
    } else if (raw is String) {
      try {
        created = DateTime.parse(raw);
      } catch (_) {
        created = DateTime.now();
      }
    } else {
      created = DateTime.now();
    }

    return Complaint(
      id: j['id'] ?? j['docId'] ?? '',
      fullName: j['fullName'] ?? '',
      gender: j['gender'] ?? '',
      trainNumber: j['trainNumber'] ?? '',
      category: j['category'] ?? '',
      description: j['description'] ?? j['desc'] ?? '',
      phone: j['phone'] ?? '',
      photoBase64: j['photoBase64'],
      classifyPhotoBase64: j['classifyPhotoBase64'] ?? j['photoBase64'],
      referencePhotos: (j['referencePhotos'] as List<dynamic>?)?.cast<String>() ?? <String>[],
      classifierLabel: j['classifierLabel'] as String?,
      classifierConfidence: j['classifierConfidence'] is num ? (j['classifierConfidence'] as num).toDouble() : double.tryParse(j['classifierConfidence']?.toString() ?? ''),
      location: j['location'],
      address: j['address'],
      status: j['status'] ?? 'open',
      userEmail: j['userEmail'] ?? '',
      createdAt: created,
    );
  }

  // ---------- MODEL TO JSON ----------
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'gender': gender,
      'trainNumber': trainNumber,
      'category': category,
      'description': description,
      'phone': phone,
      // Keep legacy `photoBase64` for backwards compatibility but prefer `classifyPhotoBase64`.
      'photoBase64': classifyPhotoBase64 ?? photoBase64,
      'classifyPhotoBase64': classifyPhotoBase64 ?? photoBase64,
      'referencePhotos': referencePhotos ?? <String>[],
      // Classifier audit fields
      'classifierLabel': classifierLabel,
      'classifierConfidence': classifierConfidence,
      'location': location,
      'address': address,
      'status': status,
      'userEmail': userEmail,
      // Keep ISO string for local storage compatibility
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
