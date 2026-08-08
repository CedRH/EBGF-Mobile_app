/// A single record in the system.
///
/// `tagNumber` is the value read by the camera/OCR step (e.g. an ear-tag
/// number or printed code).
///
/// `fieldValues` replaces the old fixed `fieldOne`/`fieldTwo`/`fieldThree`.
/// It's a list because the NUMBER and LABELS of extra fields are now
/// configurable by an admin (see FieldConfigService) — could be 3 fields
/// today, 5 tomorrow. The label for `fieldValues[i]` always comes from
/// `FieldConfigService.instance.fieldLabels[i]` at display time; this
/// model only stores the raw values, not their labels, so renaming a
/// field later doesn't require touching old records.
class FarmRecord {
  final String id;
  final String tagNumber; // value captured from the camera/OCR
  final List<String> fieldValues; // one entry per configured field
  final String createdBy;
  final DateTime createdAt;

  FarmRecord({
    required this.id,
    required this.tagNumber,
    required this.fieldValues,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tagNumber': tagNumber,
      'fieldValues': fieldValues,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FarmRecord.fromMap(Map<String, dynamic> map) {
    return FarmRecord(
      id: map['id'] as String,
      tagNumber: map['tagNumber'] as String,
      fieldValues: List<String>.from(map['fieldValues'] as List),
      createdBy: map['createdBy'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  /// Handy copy-with, used by the edit dialog in RecordsScreen.
  FarmRecord copyWith({
    String? tagNumber,
    List<String>? fieldValues,
  }) {
    return FarmRecord(
      id: id,
      tagNumber: tagNumber ?? this.tagNumber,
      fieldValues: fieldValues ?? this.fieldValues,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}
