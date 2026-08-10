import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/app_user.dart';
import '../../models/audit_log_entry.dart';
import '../../services/audit_log_service.dart';
import '../../services/session_service.dart';
import '../../services/user_service.dart';

/// Lets an admin promote a regular farm user to admin, demote an
/// admin back to a regular user.
///
/// CHANGE FROM BEFORE: this screen used to read from `AdminMockData
/// .instance.allUsers` (a hardcoded in-memory list). It now listens
/// LIVE to the `users` collection in Firestore via a StreamBuilder, so
/// any promote/demote — from this device or any other admin's device —
/// shows up immediately everywhere, and the list always reflects
/// whoever has actually signed up.
///
/// ASSUMPTIONS (matches AppUser.toMap()/fromMap() already in the
/// codebase):
///  - Collection name is `users`.
///  - Each user's Firestore DOCUMENT ID is their Firebase Auth uid.
///  - Fields on each doc: name, email, role ('admin' | 'user'),
///    createdAt (ISO 8601 string, same shape AppUser.toMap() produces).
/// If your AuthService.signUp writes the profile doc differently
/// (different collection name, createdAt as a Timestamp instead of a
/// String, etc.), let me know and I'll adjust this to match exactly.
///
/// The confirm dialog + audit logging behavior is unchanged — every
/// change still asks for confirmation first and still gets recorded
/// via AdminMockData.instance.logAction() so it shows up in Audit Log.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final CollectionReference<Map<String, dynamic>> _usersRef =
      FirebaseFirestore.instance.collection('users');

  // Tracks which user row currently has a promote/demote/delete write in
  // flight, so we can disable that row's button and show a spinner
  // instead of letting the admin double-tap while Firestore is busy.
  String? _pendingUserId;

  Future<void> _toggleRole(AppUser user, bool makingAdmin) async {
    setState(() => _pendingUserId = user.id);
    try {
      await _usersRef.doc(user.id).update({
        'role': makingAdmin ? 'admin' : 'user',
      });

      await AuditLogService.instance.logAction(
        action: makingAdmin
            ? AuditActionType.promoteUser
            : AuditActionType.demoteUser,
        performedBy: SessionService.instance.currentUser?.email ?? 'unknown',
        description: '${user.name} (${user.email})',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update role: $e')),
      );
    } finally {
      if (mounted) setState(() => _pendingUserId = null);
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    setState(() => _pendingUserId = user.id);
    try {
      await UserService.instance.deleteUser(user.id);

      await AuditLogService.instance.logAction(
        action: AuditActionType.deleteUser,
        performedBy: SessionService.instance.currentUser?.email ?? 'unknown',
        description: '${user.name} (${user.email})',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name} removed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete user: $e')),
      );
    } finally {
      if (mounted) setState(() => _pendingUserId = null);
    }
  }

  void _confirmToggleRole(AppUser user) {
    final makingAdmin = user.role == UserRole.user;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(makingAdmin ? 'Promote to Admin?' : 'Demote to Farm User?'),
        content: Text(
          makingAdmin
              ? '${user.name} will gain full admin access, including managing users and records.'
              : '${user.name} will lose admin access and become a regular farm user.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _toggleRole(user, makingAdmin);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteUser(AppUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove User?'),
        content: Text(
          'This removes ${user.name} (${user.email}) from the app. '
          'They will no longer be able to sign in. This cannot be undone '
          'from here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteUser(user);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SessionService.instance.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _usersRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load users: ${snapshot.error}'),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No users yet.'));
          }

          final users = docs.map((doc) {
            // doc.id (the real Firestore/Auth uid) always wins over
            // whatever 'id' field might be stored inside the doc, so
            // promote/demote always targets the correct document.
            final data = {...doc.data(), 'id': doc.id};
            return AppUser.fromMap(data);
          }).toList();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = users[index];
              final isSelf = user.id == currentUserId;
              final isPending = _pendingUserId == user.id;

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar + name
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: user.isAdmin
                                    ? const Color(0xFF6A1B9A)
                                    : const Color(0xFF1565C0),
                                child: Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 24),
                                  child: Text(
                                    user.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Email
                          Text(
                            user.email,
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 0.5),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.black87),
                                    children: [
                                      const TextSpan(
                                        text: 'Role: ',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      TextSpan(text: user.roleLabel),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (isSelf)
                                const Chip(label: Text('You'))
                              else if (isPending)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                OutlinedButton(
                                  onPressed: () => _confirmToggleRole(user),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 4),
                                    minimumSize: const Size(0, 32),
                                  ),
                                  child: Text(
                                    user.isAdmin ? 'Demote' : 'Promote',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      // X button, top-right corner
                      if (!isSelf && !isPending)
                        Positioned(
                          top: -8,
                          right: -8,
                          child: IconButton(
                            iconSize: 18,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.close, color: Colors.red),
                            tooltip: 'Remove user',
                            onPressed: () => _confirmDeleteUser(user),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
