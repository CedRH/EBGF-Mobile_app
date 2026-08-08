import 'package:flutter/material.dart';
import 'scan_screen.dart';
import 'records_screen.dart';
import 'login_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import '../models/farm_record.dart';
import '../models/audit_log_entry.dart';
import '../services/session_service.dart';
import '../services/admin_mock_data.dart';

/// Home screen after login.
///
/// CHANGE FROM BEFORE: no longer takes `userEmail`/`isAdmin` as
/// constructor params — it reads the logged-in user straight from
/// [SessionService]. This is what "fixes" the fragile param-passing:
/// no matter how many screens deep you navigate, any screen can just
/// ask SessionService who's logged in, instead of needing every route
/// in between to remember to forward `isAdmin` along.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // In-memory store for now so the UI is fully testable without a backend.
  // Swap this for a Firestore stream once your backend is connected —
  // see the setup guide for exactly where this plugs in.
  final List<FarmRecord> _records = [];

  String get _performedBy => SessionService.instance.currentUser?.email ?? 'unknown';

  void _addRecord(FarmRecord record) {
    setState(() => _records.insert(0, record));
    AdminMockData.instance.logAction(
      action: AuditActionType.createRecord,
      performedBy: _performedBy,
      description: 'Tag #${record.tagNumber}',
    );
  }

  void _deleteRecord(String id) {
    final record = _records.firstWhere((r) => r.id == id);
    setState(() => _records.removeWhere((r) => r.id == id));
    AdminMockData.instance.logAction(
      action: AuditActionType.deleteRecord,
      performedBy: _performedBy,
      description: 'Tag #${record.tagNumber}',
    );
  }

  void _editRecord(FarmRecord updated) {
    setState(() {
      final index = _records.indexWhere((r) => r.id == updated.id);
      if (index != -1) _records[index] = updated;
    });
    AdminMockData.instance.logAction(
      action: AuditActionType.editRecord,
      performedBy: _performedBy,
      description: 'Tag #${updated.tagNumber}',
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
                      final newRecord = await Navigator.of(context).push<FarmRecord>(
                        MaterialPageRoute(
                          builder: (_) => ScanScreen(createdBy: userEmail),
                        ),
                      );
                      if (newRecord != null) _addRecord(newRecord);
                    },
                  ),
                  _HomeTile(
                    icon: Icons.list_alt,
                    label: 'View Records',
                    color: const Color(0xFF1565C0),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RecordsScreen(
                            records: _records,
                            isAdmin: isAdmin,
                            onDelete: _deleteRecord,
                            onEdit: _editRecord,
                          ),
                        ),
                      );
                    },
                  ),
                  // Admin-only tile — regular farm users never see this,
                  // since the grid item is simply not added to the list.
                  if (isAdmin)
                    _HomeTile(
                      icon: Icons.admin_panel_settings,
                      label: 'Admin Dashboard',
                      color: const Color(0xFF6A1B9A),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminDashboardScreen(records: _records),
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
