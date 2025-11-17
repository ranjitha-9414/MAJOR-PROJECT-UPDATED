class Complaint {
  final String id;
  final String fullName;
  final String gender;
  final String trainNumber;
  final String category;
  final String description;
  final String phone;
  final String? photoBase64;
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
    this.location,
    this.address,
    this.status = 'open',
    required this.userEmail,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'gender': gender,
        'trainNumber': trainNumber,
        'category': category,
        'description': description,
        'phone': phone,
        'photoBase64': photoBase64,
        'location': location,
        'address': address,
        'status': status,
        'userEmail': userEmail,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Complaint.fromJson(Map<String, dynamic> j) => Complaint(
        id: j['id'] ?? j['docId'] ?? '',
        fullName: j['fullName'] ?? '',
        gender: j['gender'] ?? '',
        trainNumber: j['trainNumber'] ?? '',
        category: j['category'] ?? '',
        description: j['description'] ?? j['desc'] ?? '',
        phone: j['phone'] ?? '',
        photoBase64: j['photoBase64'],
        location: j['location'],
        address: j['address'],
        status: j['status'] ?? 'open',
        userEmail: j['userEmail'] ?? '',
        createdAt: j['createdAt'] != null ? DateTime.parse(j['createdAt']) : DateTime.now(),
      );
}
