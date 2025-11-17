class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String userType; // user, admin, staff
  final String? department;

  UserModel({required this.id, required this.name, required this.email, required this.phone, required this.userType, this.department});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'userType': userType,
        'department': department,
      };

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        phone: j['phone'] ?? '',
        userType: j['userType'] ?? 'user',
        department: j['department'],
      );
}
