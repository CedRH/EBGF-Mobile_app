import 'package:flutter/material.dart';
import '../models/farm_record.dart';
import 'scan_screen.dart';

/// The "Add Record" hub.
///
/// Same pattern as AdminDashboardScreen: a small grid of tiles that each
/// lead to one way of doing the same underlying task. Both tiles ultimately
/// produce a FarmRecord:
/// - "Scan Tag" -> ScanScreen (camera + OCR)
/// - "Manual Entry" -> RecordDetailsScreen directly, blank tag field
///
/// Whichever tile is chosen, the record is bubbled back to the caller so
/// the parent screen can treat it as a single entry point.
class AddRecordScreen extends StatelessWidget {
  final String createdBy;

  const AddRecordScreen({super.key, required this.createdBy});

  Future<void> _scanTag(BuildContext context) async {
    final record = await Navigator.of(context).push<FarmRecord>(
      MaterialPageRoute(
        builder: (_) => ScanScreen(createdBy: createdBy),
      ),
    );
    if (record != null && context.mounted) {
      Navigator.of(context).pop(record);
    }
  }

  Future<void> _enterManually(BuildContext context) async {
    final record = await Navigator.of(context).push<FarmRecord>(
      MaterialPageRoute(
        builder: (_) => RecordDetailsScreen(
          initialTagNumber: '',
          createdBy: createdBy,
        ),
      ),
    );
    if (record != null && context.mounted) {
      Navigator.of(context).pop(record);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F0EE),
      appBar: AppBar(
        title: const Text('Add Record'),
        backgroundColor: const Color.fromARGB(255, 153, 31, 10),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _AddRecordTile(
              icon: Icons.camera_alt,
              label: 'Scan Tag',
              color: const Color(0xFF2E7D32),
              onTap: () => _scanTag(context),
            ),
            _AddRecordTile(
              icon: Icons.keyboard,
              label: 'Manual Entry',
              color: const Color(0xFFEF6C00),
              onTap: () => _enterManually(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddRecordTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AddRecordTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: color),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
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
