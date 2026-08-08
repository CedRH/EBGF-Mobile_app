import 'package:flutter/material.dart';
import '../../services/admin_mock_data.dart';
import '../../models/audit_log_entry.dart';

/// Read-only history of admin/user actions — logins, record edits,
/// promotions, field-label changes, etc. Each entry is color-coded and
/// icon-coded based on its AuditActionType (see audit_log_entry.dart)
/// so an admin can scan the list and immediately spot, say, all the
/// deletions (red) without reading every line.
class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = AdminMockData.instance.auditLog;

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log')),
      body: entries.isEmpty
          ? const Center(
              child: Text(
                  'No activity yet. Actions will appear here as they happen.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: entry.action.color.withOpacity(0.15),
                      child: Icon(entry.action.icon, color: entry.action.color),
                    ),
                    title: Text(
                      entry.action.label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${entry.description}\n'
                      'by ${entry.performedBy} • ${_formatTimestamp(entry.timestamp)}',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
