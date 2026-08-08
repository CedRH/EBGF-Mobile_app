import 'package:flutter/foundation.dart';

/// Centralizes the labels used for a record's extra fields.
///
/// WHY THIS EXISTS: originally the app had hardcoded fields called
/// "Field 1", "Field 2", "Field 3". But an admin should be able to
/// rename these to whatever makes sense for the farm — "Leg Band Color",
/// "Bloodline", "Distinguishing Marks" — WITHOUT a developer needing to
/// edit code and rebuild the app. This service is the single source of
/// truth for those labels; every screen that shows or edits a record
/// (ScanScreen, RecordsScreen, the Excel export, Tags Editor) reads from
/// here instead of hardcoding text.
///
/// `extends ChangeNotifier` so screens can optionally listen for changes
/// with `AnimatedBuilder`/`ListenableBuilder` if you want the UI to
/// live-update the moment an admin saves new labels.
class FieldConfigService extends ChangeNotifier {
  FieldConfigService._internal();
  static final FieldConfigService instance = FieldConfigService._internal();

  // Sensible starting defaults so the app is usable before an admin
  // customizes anything.
  List<String> _fieldLabels = ['Leg Band Color', 'Bloodline', 'Marks'];

  /// Read-only view — screens should call [updateLabels]/[addField]/
  /// [removeField] rather than mutating this list directly.
  List<String> get fieldLabels => List.unmodifiable(_fieldLabels);

  void updateLabels(List<String> newLabels) {
    _fieldLabels = newLabels
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (_fieldLabels.isEmpty) {
      // Never allow zero fields — fall back to one generic field so
      // forms elsewhere don't break.
      _fieldLabels = ['Field 1'];
    }
    notifyListeners();
  }

  void addField(String label) {
    _fieldLabels = [..._fieldLabels, label.trim().isEmpty ? 'New Field' : label.trim()];
    notifyListeners();
  }

  void removeField(int index) {
    if (_fieldLabels.length <= 1) return; // keep at least one field
    final updated = [..._fieldLabels]..removeAt(index);
    _fieldLabels = updated;
    notifyListeners();
  }
}
