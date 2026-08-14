import 'package:flutter/material.dart';
import 'scan_screen.dart';
import 'records_screen.dart';
import 'login_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import '../models/farm_record.dart';
import '../models/audit_log_entry.dart';
import '../services/session_service.dart';
import '../services/audit_log_service.dart';
import '../services/records_service.dart';

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
  // Use Firestore as the single source of truth. The RecordsService exposes
  // a stream that updates in real time when any device changes records.

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

  Future<void> _deleteRecord(String id) async {
    // fetch a shallow copy of the record for logging after deletion
    // (best-effort; if missing, description will be generic)
    String tagDesc = id;
    try {
      final current = await RecordsService.instance.recordsStream
          .firstWhere((list) => list.any((r) => r.id == id));
      final record = current.firstWhere((r) => r.id == id);
      tagDesc = 'Tag #${record.tagNumber}';
    } catch (_) {}

    await RecordsService.instance.deleteRecord(id);
    await AuditLogService.instance.logAction(
      action: AuditActionType.deleteRecord,
      performedBy: _performedBy,
      description: tagDesc,
    );
  }

  Future<void> _editRecord(FarmRecord updated) async {
    await RecordsService.instance.editRecord(updated);
    await AuditLogService.instance.logAction(
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
                          builder: (_) => StreamBuilder<List<FarmRecord>>(
                            stream: RecordsService.instance.recordsStream,
                            builder: (context, snapshot) {
                              final records = snapshot.data ?? [];
                              return RecordsScreen(
                                records: records,
                                isAdmin: isAdmin,
                                onDelete: (id) async => await _deleteRecord(id),
                                onEdit: (updated) async =>
                                    await _editRecord(updated),
                              );
                            },
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
  // NOTE: `color` used to fill the WHOLE tile background. Now it's only
  // used to tint the icon, so each tile still reads as "its own type"
  // (green for scan, blue for records, purple for admin) even though
  // every card is white now.
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
    // Same brand red used across the app (AppBar, buttons) — reused here
    // for the shadow so the tile feels tied to the app, not just a
    // generic grey drop shadow.
    const shadowColor = Color.fromARGB(255, 153, 31, 10);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      // Material+InkWell inside the shadowed Container (instead of the
      // Container being the Material itself) so the tap ripple still
      // shows correctly without fighting the box shadow/rounded corners.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon keeps its accent color so tiles stay visually
                // distinct even on a white background.
                Icon(icon, size: 40, color: color),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
