import 'package:flutter/material.dart';
import '../../models/audit_log_entry.dart';
import '../../services/field_config_service.dart';
import '../../services/admin_mock_data.dart';
import '../../services/session_service.dart';

/// Lets an admin rename the extra fields shown on every record (e.g.
/// change "Field 1" to "Leg Band Color"), and add or remove fields
/// entirely. Saving here updates FieldConfigService, which every other
/// screen (ScanScreen, RecordsScreen) reads from — so the change takes
/// effect immediately, app-wide, without touching any other code.
class TagsEditorScreen extends StatefulWidget {
  const TagsEditorScreen({super.key});

  @override
  State<TagsEditorScreen> createState() => _TagsEditorScreenState();
}

class _TagsEditorScreenState extends State<TagsEditorScreen> {
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = FieldConfigService.instance.fieldLabels
        .map((label) => TextEditingController(text: label))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addField() {
    setState(() {
      _controllers.add(TextEditingController(text: 'New Field'));
    });
  }

  void _removeField(int index) {
    if (_controllers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need at least one field.')),
      );
      return;
    }
    setState(() {
      _controllers.removeAt(index).dispose();
    });
  }

  void _save() {
    final newLabels = _controllers.map((c) => c.text.trim()).toList();
    FieldConfigService.instance.updateLabels(newLabels);

    AdminMockData.instance.logAction(
      action: AuditActionType.updateFieldConfig,
      performedBy: SessionService.instance.currentUser?.email ?? 'unknown',
      description: 'Fields set to: ${newLabels.join(', ')}',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Field labels updated.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tags Editor')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'These labels appear when scanning a new record and when '
              'viewing/editing existing ones.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: _controllers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _controllers[index],
                          decoration: InputDecoration(labelText: 'Field ${index + 1}'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _removeField(index),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addField,
              icon: const Icon(Icons.add),
              label: const Text('Add Field'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
