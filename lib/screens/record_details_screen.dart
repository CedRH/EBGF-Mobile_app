import 'package:flutter/material.dart';
import '../models/farm_record.dart';
import '../services/field_config_service.dart';
import 'edit_record_screen.dart';

/// View-only screen for a single record. Tapping a record in the list
/// lands here first — no editing happens on this screen, it's purely
/// for reading the details clearly (big text, one field per row).
///
/// Editing now lives on its own screen (EditRecordScreen), reached via
/// the "Edit" button in the app bar here. This keeps "just looking at
/// a record" and "changing a record" as two clearly separate actions,
/// instead of both living inside one crowded dialog like before.
class RecordDetailsScreen extends StatefulWidget {
  final FarmRecord record;
  final bool isAdmin;
  final void Function(FarmRecord updated) onEdit;
  final void Function(String id) onDelete;

  const RecordDetailsScreen({
    super.key,
    required this.record,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<RecordDetailsScreen> createState() => _RecordDetailsScreenState();
}

class _RecordDetailsScreenState extends State<RecordDetailsScreen> {
  // Kept as local state so that after editing, this screen immediately
  // shows the updated values without needing to pop back to the list
  // and re-open the record.
  late FarmRecord _record = widget.record;

  Future<void> _openEditScreen() async {
    final updated = await Navigator.of(context).push<FarmRecord>(
      MaterialPageRoute(
        builder: (_) => EditRecordScreen(record: _record),
      ),
    );

    if (updated != null) {
      widget
          .onEdit(updated); // tells HomeScreen/RecordsScreen to update its list
      setState(() => _record = updated);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record?'),
        content:
            Text('This will permanently delete tag "${_record.tagNumber}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              widget.onDelete(_record.id);
              Navigator.of(context).pop(); // close dialog
              Navigator.of(context).pop(); // leave details screen too
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fieldLabels = FieldConfigService.instance.fieldLabels;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: _openEditScreen,
          ),
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _DetailCard(
            label: 'Tag / Scanned Number',
            value: _record.tagNumber,
            icon: Icons.qr_code,
            color: const Color(0xFF991F0A),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < fieldLabels.length; i++) ...[
            _DetailCard(
              label: fieldLabels[i],
              value: i < _record.fieldValues.length
                  ? _record.fieldValues[i]
                  : '(empty)',
              icon: Icons.label_outline,
              color: const Color(0xFF2E7D32),
            ),
            const SizedBox(height: 14),
          ],
          _DetailCard(
            label: 'Created By',
            value: _record.createdBy,
            icon: Icons.person_outline,
            color: const Color(0xFF1565C0),
          ),
          const SizedBox(height: 14),
          _DetailCard(
            label: 'Created At',
            value: _record.createdAt.toString(),
            icon: Icons.calendar_today_outlined,
            color: const Color(0xFF6A1B9A),
          ),
        ],
      ),
    );
  }
}

/// Same white-card + red-shadow language used across the whole app —
/// one card per field, so it reads clearly at a glance even on a small
/// or older screen.
class _DetailCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _DetailCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF991F0A).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 26, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? '(empty)' : value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
