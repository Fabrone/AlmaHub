/// User model for role-based access control
class AppUser {
  final String uid;
  final String email;
  final String fullName;
  final String role; // Admin, HR, Supervisor, Employee
  final DateTime createdAt;
  final DateTime? updatedAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create AppUser from Firestore document
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      role: map['role'] ?? 'Employee',
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: map['updatedAt']?.toDate(),
    );
  }

  /// Convert AppUser to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'role': role,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Check if user has admin role
  bool get isAdmin => role == 'Admin';

  /// Check if user has HR role
  bool get isHR => role == 'HR';

  /// Check if user has Supervisor role
  bool get isSupervisor => role == 'Supervisor';

  /// Check if user has Accountant role
  bool get isAccountant => role == 'Accountant';

  /// Check if user has Employee role
  bool get isEmployee => role == 'Employee';

  /// Copy with method for updating user
  AppUser copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Available user roles in the system
class UserRoles {
  static const String admin = 'Admin';
  static const String hr = 'HR';
  static const String supervisor = 'Supervisor';
  static const String accountant = 'Accountant';
  static const String employee = 'Employee';

  static List<String> get allRoles => [admin, hr, supervisor, accountant, employee];

  static bool isValidRole(String role) {
    return allRoles.contains(role);
  }
}