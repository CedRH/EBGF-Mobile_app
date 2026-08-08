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
          (i) => TextCellValue(i < record.fieldValues.length ? record.fieldValues[i] : ''),
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
        content: Text('This will permanently delete tag "${record.tagNumber}".'),
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

  void _editRecordDialog(BuildContext context, FarmRecord record) {
    final fieldLabels = FieldConfigService.instance.fieldLabels;
    // Build one controller per current field label, seeded with the
    // record's existing value at that position (or blank if the record
    // was created before this field existed — e.g. an admin added a
    // field after this record was saved).
    final controllers = List.generate(
      fieldLabels.length,
      (i) => TextEditingController(
        text: i < record.fieldValues.length ? record.fieldValues[i] : '',
      ),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Tag ${record.tagNumber}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < fieldLabels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: controllers[i],
                    decoration: InputDecoration(labelText: fieldLabels[i]),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        // Only admins see/can use the delete button.
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
