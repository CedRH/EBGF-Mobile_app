import 'package:flutter/material.dart';
import 'scan_screen.dart';
import 'records_screen.dart';
import 'login_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import '../models/farm_record.dart';
import '../models/audit_log_entry.dart';
import '../services/session_service.dart';
import '../services/records_service.dart';
import '../services/audit_log_service.dart';

/// Home screen after login.
///
/// CHANGE FROM BEFORE: no longer holds `_records` as local State, and no
/// longer owns delete/edit logic for records. RecordsService.instance is
/// now the single source of truth (Firestore-backed), so RecordsScreen
/// reads/writes it directly instead of needing callbacks handed down
/// from here. HomeScreen only still owns `_addRecord` because that's the
/// one mutation that originates on this screen (via ScanScreen).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String get _performedBy =>
      SessionService.instance.currentUser?.email ?? 'unknown';

  Future<void> _addRecord(FarmRecord record) async {
    await RecordsService.instance.addRecord(record);
    await AuditLogService.instance.logAction(
      action: AuditActionType.createRecord,
      performedBy: _performedBy,
      description: 'Tag #${record.tagNumber}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.instance.currentUser;
    final isAdmin = SessionService.instance.isAdmin;
    final userEmail = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farm Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () {
              SessionService.instance.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Signed in as $userEmail',
              style: const TextStyle(color: Colors.black54),
            ),
            Text(
              isAdmin ? 'Role: Admin' : 'Role: Farm User',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _HomeTile(
                    icon: Icons.camera_alt,
                    label: 'Scan Tag / Add Record',
                    color: const Color(0xFF2E7D32),
                    onTap: () async {
                      final newRecord =
                          await Navigator.of(context).push<FarmRecord>(
                        MaterialPageRoute(
                          builder: (_) => ScanScreen(createdBy: userEmail),
                        ),
                      );
                      if (newRecord != null) await _addRecord(newRecord);
                    },
                  ),
                  _HomeTile(
                    icon: Icons.list_alt,
                    label: 'View Records',
                    color: const Color(0xFF1565C0),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RecordsScreen(isAdmin: isAdmin),
                        ),
                      );
                    },
                  ),
                  if (isAdmin)
                    _HomeTile(
                      icon: Icons.admin_panel_settings,
                      label: 'Admin Dashboard',
                      color: const Color(0xFF6A1B9A),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AdminDashboardScreen(),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HomeTile({
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
