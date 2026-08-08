import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/audit_log_entry.dart';
import '../../services/admin_mock_data.dart';
import '../../services/session_service.dart';

/// Lets an admin promote a regular farm user to admin, or demote an
/// admin back to a regular user. Every change is confirmed with a
/// dialog first (promoting/demoting is a big deal — no accidental taps)
/// and recorded in the Audit Log so there's a trail of who changed what.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _data = AdminMockData.instance;

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
              setState(() {
                if (makingAdmin) {
                  _data.promoteUser(user.id);
                } else {
                  _data.demoteUser(user.id);
                }
              });
              _data.logAction(
                action: makingAdmin
                    ? AuditActionType.promoteUser
                    : AuditActionType.demoteUser,
                performedBy: SessionService.instance.currentUser?.email ?? 'unknown',
                description: '${user.name} (${user.email})',
              );
              Navigator.of(context).pop();
            },
            child: const Text('Confirm'),
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
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _data.allUsers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final user = _data.allUsers[index];
          final isSelf = user.id == currentUserId;

          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: user.isAdmin
                    ? const Color(0xFF6A1B9A)
                    : const Color(0xFF1565C0),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${user.email}\nRole: ${user.roleLabel}'),
              isThreeLine: true,
              trailing: isSelf
                  ? const Chip(label: Text('You'))
                  : TextButton(
                      onPressed: () => _confirmToggleRole(user),
                      child: Text(user.isAdmin ? 'Demote' : 'Promote'),
                    ),
            ),
          );
        },
      ),
    );
  }
}
