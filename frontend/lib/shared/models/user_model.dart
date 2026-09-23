enum UserRole { CITIZEN, WORKER, ADMIN }

class UserModel {
  final int id;
  final int? workerId;
  final String? phone;
  final String? email;
  final String? fullName;
  final UserRole role;
  final String? token;
  final bool requiresFaceEnrollment;
  final bool isActive;

  UserModel({
    required this.id,
    this.workerId,
    this.phone,
    this.email,
    this.fullName,
    required this.role,
    this.token,
    this.requiresFaceEnrollment = false,
    this.isActive = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, {String? token}) {
    UserRole roleVal = UserRole.CITIZEN;
    final r = json['role']?.toString().toUpperCase();
    if (r == 'WORKER') roleVal = UserRole.WORKER;
    if (r == 'ADMIN') roleVal = UserRole.ADMIN;

    return UserModel(
      id: json['user_id'] ?? json['id'] ?? 0,
      workerId: json['worker_id'],
      phone: json['phone'],
      email: json['email'],
      fullName: json['full_name'],
      role: roleVal,
      token: token ?? json['access_token'],
      requiresFaceEnrollment: json['requires_face_enrollment'] ?? false,
      isActive: json['is_active'] ?? true,
    );
  }

  UserModel copyWith({
    int? id,
    int? workerId,
    String? phone,
    String? email,
    String? fullName,
    UserRole? role,
    String? token,
    bool? requiresFaceEnrollment,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      token: token ?? this.token,
      requiresFaceEnrollment: requiresFaceEnrollment ?? this.requiresFaceEnrollment,
      isActive: isActive ?? this.isActive,
    );
  }
}
