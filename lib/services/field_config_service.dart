import 'package:cloud_firestore/cloud_firestore.dart';
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
/// CHANGE: labels now live in Firestore (`app_config/fields`) instead of
/// only in memory, so a rename by one admin shows up on every device —
/// and survives an app restart. The service keeps a live Firestore
/// listener running from the moment it's first touched, and caches the
/// latest value in [_fieldLabels] so screens that need labels
/// synchronously (ScanScreen, RecordsScreen) can keep calling
/// `fieldLabels` exactly like before — no other screen needs to change.
///
/// `extends ChangeNotifier` so screens can optionally listen for changes
/// with `AnimatedBuilder`/`ListenableBuilder` if you want the UI to
/// live-update the moment an admin saves new labels.
class FieldConfigService extends ChangeNotifier {
  FieldConfigService._internal() {
    _listen();
  }
  static final FieldConfigService instance = FieldConfigService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _fieldsDoc =>
      _firestore.collection('app_config').doc('fields');

  // Sensible starting defaults so the app is usable before Firestore's
  // first snapshot arrives (or before an admin customizes anything).
  List<String> _fieldLabels = ['Leg Band Color', 'Bloodline', 'Marks'];

  /// Read-only view — screens should call [updateLabels]/[addField]/
  /// [removeField] rather than mutating this list directly.
  List<String> get fieldLabels => List.unmodifiable(_fieldLabels);

  void _listen() {
    _fieldsDoc.snapshots().listen((snapshot) {
      final data = snapshot.data();
      if (data == null || data['labels'] == null) return;
      final labels = List<String>.from(data['labels'] as List);
      if (labels.isEmpty) return; // never allow the UI to go blank
      _fieldLabels = labels;
      notifyListeners();
    });
  }

  Future<void> updateLabels(List<String> newLabels) async {
    var cleaned =
        newLabels.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (cleaned.isEmpty) {
      // Never allow zero fields — fall back to one generic field so
      // forms elsewhere don't break.
      cleaned = ['Field 1'];
    }

    // Optimistic local update so the admin sees it instantly, even
    // before Firestore's snapshot round-trips back.
    _fieldLabels = cleaned;
    notifyListeners();

    await _fieldsDoc.set({'labels': cleaned});
  }

  Future<void> addField(String label) {
    final updated = [
      ..._fieldLabels,
      label.trim().isEmpty ? 'New Field' : label.trim(),
    ];
    return updateLabels(updated);
  }

  Future<void> removeField(int index) {
    if (_fieldLabels.length <= 1) return Future.value(); // keep at least one
    final updated = [..._fieldLabels]..removeAt(index);
    return updateLabels(updated);
  }
}
