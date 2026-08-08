import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/audit_log_entry.dart';

class AuditLogService {
  AuditLogService._internal();
  static final AuditLogService instance = AuditLogService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _auditLogCollection =>
      _firestore.collection('audit_logs');

  Stream<List<AuditLogEntry>> get auditLogStream {
    return _auditLogCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = {...doc.data(), 'id': doc.id};
        return AuditLogEntry.fromMap(data);
      }).toList();
    });
  }

  Future<void> logAction({
    required AuditActionType action,
    required String performedBy,
    required String description,
  }) async {
    final entry = AuditLogEntry(
      id: '',
      action: action,
      performedBy: performedBy,
      description: description,
      timestamp: DateTime.now(),
    );
    final doc = _auditLogCollection.doc();
    await doc.set(entry.toMap());
  }
}
