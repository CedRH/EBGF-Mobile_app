import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../models/farm_record.dart';
import '../models/audit_log_entry.dart';
import '../services/field_config_service.dart';
import '../services/records_service.dart';
import '../services/audit_log_service.dart';
import '../services/session_service.dart';

/// Records list.
///
/// PERMISSIONS:
/// - Admin: can edit AND delete any record.
/// - Regular farm user: can edit, but the delete button is hidden/disabled.
///
/// CHANGE FROM BEFORE: no longer takes `records`/`onDelete`/`onEdit` from
/// HomeScreen — it reads live from RecordsService.instance.recordsStream
/// (Firestore) and owns its own delete/edit logic directly, since any
/// screen can reach that singleton now. This is also why it's real-time:
/// a change made on another device shows up here automatically.
class RecordsScreen extends StatelessWidget {
  final bool isAdmin;

  const RecordsScreen({super.key, required this.isAdmin});

  String get _performedBy =>
      SessionService.instance.currentUser?.email ?? 'unknown';

  Future<void> _onDelete(FarmRecord record) async {
    await RecordsService.instance.deleteRecord(record.id);
    await AuditLogService.instance.logAction(
      action: AuditActionType.deleteRecord,
      performedBy: _performedBy,
      description: 'Tag #${record.tagNumber}',
    );
  }

  Future<void> _onEdit(FarmRecord updated) async {
    await RecordsService.instance.editRecord(updated);
    await AuditLogService.instance.logAction(
      action: AuditActionType.editRecord,
      performedBy: _performedBy,
      description: 'Tag #${updated.tagNumber}',
    );
  }

  Future<void> _exportToExcel(
      BuildContext context, List<FarmRecord> records) async {
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
              _onDelete(record);
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
                    decoration: InputDecoration(
                      labelText: fieldLabels[i],
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      hintText: 'Missing content',
                      hintStyle: const TextStyle(color: Colors.black38),
                    ),
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
              _onEdit(record.copyWith(
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
    return StreamBuilder<List<FarmRecord>>(
      stream: RecordsService.instance.recordsStream,
      builder: (context, snapshot) {
        final records = snapshot.data ?? [];

        return Scaffold(
          appBar: AppBar(
            title: const Text('All Records'),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download_outlined),
                tooltip: 'Export to Excel',
                onPressed: records.isEmpty
                    ? null
                    : () => _exportToExcel(context, records),
              ),
            ],
          ),
          body: !snapshot.hasData
              ? const Center(child: CircularProgressIndicator())
              : records.isEmpty
                  ? const Center(
                      child: Text('No records yet. Scan a tag to add one.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            title: Text(
                              record.tagNumber,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
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
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blueGrey),
                                  onPressed: () =>
                                      _editRecordDialog(context, record),
                                ),
                                if (isAdmin)
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _confirmDelete(context, record),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        );
      },
    );
  }
}
