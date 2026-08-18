import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../models/farm_record.dart';
import '../services/field_config_service.dart';

/// Records list.
///
/// PERMISSIONS (as you specified):
/// - Admin: can edit AND delete any record.
/// - Regular farm user: can edit, but the delete button is hidden/disabled.
///
/// EXPORT: The "Export to Excel" button builds a real .xlsx file on the
/// device using the `excel` package, then opens the native share sheet
/// (via `share_plus`) so the user can save it to Drive, email it, etc.
///
/// CHANGE FROM BEFORE: field columns/rows now come from
/// FieldConfigService.instance.fieldLabels instead of the hardcoded
/// "Field 1/2/3" — both on-screen and in the exported spreadsheet.
class RecordsScreen extends StatelessWidget {
  final List<FarmRecord> records;
  final bool isAdmin;
  final void Function(String id) onDelete;
  final void Function(FarmRecord updated) onEdit;

  const RecordsScreen({
    super.key,
    required this.records,
    required this.isAdmin,
    required this.onDelete,
    required this.onEdit,
  });

  Future<void> _exportToExcel(BuildContext context) async {
    final fieldLabels = FieldConfigService.instance.fieldLabels;
    final excelFile = Excel.createExcel();
    final sheet = excelFile['Records'];

    sheet.appendRow([
      TextCellValue('Tag Number'),
      ...fieldLabels.map((label) => TextCellValue(label)),
      TextCellValue('Created By'),
      TextCellValue('Created At'),
    ]);

    for (final record in records) {
      sheet.appendRow([
        TextCellValue(record.tagNumber),
        ...List.generate(
          fieldLabels.length,
          (i) => TextCellValue(
              i < record.fieldValues.length ? record.fieldValues[i] : ''),
        ),
        TextCellValue(record.createdBy),
        TextCellValue(record.createdAt.toString()),
      ]);
    }

    final bytes = excelFile.encode();
    if (bytes == null) return;

    final directory = await getTemporaryDirectory();
    final filePath =
        '${directory.path}/farm_records_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([XFile(filePath)], text: 'Farm Records Export');
  }

  void _confirmDelete(BuildContext context, FarmRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record?'),
        content:
            Text('This will permanently delete tag "${record.tagNumber}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              onDelete(record.id);
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Decoration for the Edit Tag dialog's text boxes.
  // Label lives OUTSIDE/ABOVE the box (see _editRecordDialog), so this
  // only styles the box itself. Border radius kept at 10 (same as the
  // rest of the app) — not a pill shape.
  //
  // NEW: taller contentPadding (18 vertical, was 14) so the box itself
  // is bigger/easier to tap and read, matching the "make it bigger for
  // older devices/users" request.
  InputDecoration _editFieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF6F8F4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  void _editRecordDialog(BuildContext context, FarmRecord record) {
    final fieldLabels = FieldConfigService.instance.fieldLabels;
    final controllers = List.generate(
      fieldLabels.length,
      (i) => TextEditingController(
        text: i < record.fieldValues.length ? record.fieldValues[i] : '',
      ),
    );

    // Use most of the screen width instead of the dialog's default
    // shrink-wrapped size — makes the whole card noticeably bigger,
    // which is the point: more room = bigger text = easier to read.
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // Smaller inset padding = dialog stretches closer to the screen
        // edges = wider card overall.
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text('Edit Tag ${record.tagNumber}'),
        // NEW: bigger, bolder dialog title.
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        content: SizedBox(
          width:
              screenWidth, // fills the widened dialog instead of shrink-wrapping
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < fieldLabels.length; i++)
                  Padding(
                    // More breathing room between fields (was 16, now 22)
                    // now that everything is bigger.
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fieldLabels[i],
                          // NEW: bigger label text (was 14, now 16).
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: controllers[i],
                          // NEW: bigger text INSIDE the box too (was
                          // default ~14, now 18) — this is the part
                          // that matters most for readability.
                          style: const TextStyle(fontSize: 18),
                          decoration: _editFieldDecoration(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            onPressed: () {
              onEdit(record.copyWith(
                fieldValues: controllers.map((c) => c.text.trim()).toList(),
              ));
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export to Excel',
            onPressed: records.isEmpty ? null : () => _exportToExcel(context),
          ),
        ],
      ),
      body: records.isEmpty
          ? const Center(child: Text('No records yet. Scan a tag to add one.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final record = records[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF991F0A).withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ListTile(
                    title: Text(
                      record.tagNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${record.fieldValues.join(' • ')}\n'
                      'by ${record.createdBy}',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blueGrey),
                          onPressed: () => _editRecordDialog(context, record),
                        ),
                        if (isAdmin)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(context, record),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
