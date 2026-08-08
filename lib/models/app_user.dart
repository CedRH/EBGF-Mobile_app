/// Represents the currently logged-in person using the app.
///
/// `role` decides what they can see/do — right now only two roles exist,
/// but this enum makes it easy to add more later (e.g. `moderator`)
/// without breaking anything that already checks `role == UserRole.admin`.
enum UserRole { admin, user }

class AppUser {
  final String id;
  final String name;
  final String email;
  UserRole role; // not final -> allows promote/demote to update it in place
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  bool get isAdmin => role == UserRole.admin;

  /// Friendly label used in the UI (e.g. "Admin" / "Farm User").
  String get roleLabel => role == UserRole.admin ? 'Admin' : 'Farm User';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      role: (map['role'] as String) == 'admin' ? UserRole.admin : UserRole.user,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
