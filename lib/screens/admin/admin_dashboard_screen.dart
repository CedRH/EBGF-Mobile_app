import 'package:flutter/material.dart';
import 'user_management_screen.dart';
import 'audit_log_screen.dart';
import 'analytics_screen.dart';
import 'tags_editor_screen.dart';

/// The admin's home base — a hub of 4 tiles leading to the actual admin
/// features. Kept as a separate screen (instead of cramming buttons into
/// the regular HomeScreen) so the admin-only tools have room to grow
/// without cluttering the screen every regular farm user sees.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _AdminTile(
              icon: Icons.people_alt_outlined,
              label: 'User Management',
              color: const Color(0xFF6A1B9A),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserManagementScreen()),
              ),
            ),
            _AdminTile(
              icon: Icons.history,
              label: 'Audit Log',
              color: const Color(0xFF1565C0),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AuditLogScreen()),
              ),
            ),
            _AdminTile(
              icon: Icons.bar_chart,
              label: 'Analytics',
              color: const Color(0xFF2E7D32),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
              ),
            ),
            _AdminTile(
              icon: Icons.label_outline,
              label: 'Tags Editor',
              color: const Color(0xFFC62828),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TagsEditorScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AdminTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
