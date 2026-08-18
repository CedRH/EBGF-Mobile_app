import 'package:flutter/material.dart';
import '../models/farm_record.dart';
import '../services/field_config_service.dart';

/// Full-screen editing — used to be a popup dialog, but a dialog gets
/// cramped fast once there are several fields, especially on older/
/// smaller Android devices. A dedicated screen gives every field room
/// to breathe and makes the keyboard behave better too.
class EditRecordScreen extends StatefulWidget {
  final FarmRecord record;

  const EditRecordScreen({super.key, required this.record});

  @override
  State<EditRecordScreen> createState() => _EditRecordScreenState();
}

class _EditRecordScreenState extends State<EditRecordScreen> {
  late final TextEditingController _tagController =
      TextEditingController(text: widget.record.tagNumber);
  late final List<String> _fieldLabels =
      FieldConfigService.instance.fieldLabels;
  late final List<TextEditingController> _fieldControllers = List.generate(
    _fieldLabels.length,
    (i) => TextEditingController(
      text: i < widget.record.fieldValues.length
          ? widget.record.fieldValues[i]
          : '',
    ),
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _tagController.dispose();
    for (final c in _fieldControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final updated = widget.record.copyWith(
      tagNumber: _tagController.text.trim(),
      fieldValues: _fieldControllers.map((c) => c.text.trim()).toList(),
    );

    Navigator.of(context).pop(updated); // hands the updated record back
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Tag ${widget.record.tagNumber}')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _tagController,
                decoration: const InputDecoration(
                  labelText: 'Tag / Scanned Number',
                  prefixIcon: Icon(Icons.qr_code),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < _fieldLabels.length; i++) ...[
                TextFormField(
                  controller: _fieldControllers[i],
                  decoration: InputDecoration(labelText: _fieldLabels[i]),
                ),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
