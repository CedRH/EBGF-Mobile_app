import '../models/app_user.dart';
import '../models/audit_log_entry.dart';

/// In-memory stand-in for the data an admin panel needs: the list of all
/// users (for User Management) and a running history of actions (for the
/// Audit Log).
///
/// WHY A SEPARATE SERVICE FROM SessionService: SessionService only ever
/// knows about ONE user — whoever is currently logged in. Admin screens
/// need to see EVERYONE, so that's modeled here instead. When Firestore
/// is connected, `allUsers` becomes a stream from the `users` collection,
/// and `logAction()` becomes a write to an `audit_log` collection —
/// but every screen that already calls this service won't need to change.
class AdminMockData {
  AdminMockData._internal() {
    _seedInitialData();
  }
  static final AdminMockData instance = AdminMockData._internal();

  final List<AppUser> allUsers = [];
  final List<AuditLogEntry> auditLog = [];

  int _auditIdCounter = 0;

  void _seedInitialData() {
    allUsers.addAll([
      AppUser(
        id: 'u1',
        name: 'Admin User',
        email: 'admin@test.com',
        role: UserRole.admin,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
      AppUser(
        id: 'u2',
        name: 'Juan Dela Cruz',
        email: 'juan@test.com',
        role: UserRole.user,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      AppUser(
        id: 'u3',
        name: 'Maria Santos',
        email: 'maria@test.com',
        role: UserRole.user,
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
    ]);
  }

  void logAction({
    required AuditActionType action,
    required String performedBy,
    required String description,
  }) {
    _auditIdCounter++;
    auditLog.insert(
      0, // newest first
      AuditLogEntry(
        id: 'log_$_auditIdCounter',
        action: action,
        performedBy: performedBy,
        description: description,
        timestamp: DateTime.now(),
      ),
    );
  }

  void promoteUser(String userId) {
    final user = allUsers.firstWhere((u) => u.id == userId);
    user.role = UserRole.admin;
  }

  void demoteUser(String userId) {
    final user = allUsers.firstWhere((u) => u.id == userId);
    user.role = UserRole.user;
  }
}
