enum UserRole { patient, doctor, admin }

class UserModel {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final String? phoneNumber;
  final String? profileImageUrl;
  final String status; // For doctors: 'Pending' or 'Verified'

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.phoneNumber,
    this.profileImageUrl,
    this.status = 'active', 
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'],
      email: json['email'],
      name: json['name'],
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
        orElse: () => UserRole.patient,
      ),
      phoneNumber: json['phoneNumber'],
      profileImageUrl: json['profileImageUrl'],
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role.toString().split('.').last,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'status': status,
    };
  }
}
