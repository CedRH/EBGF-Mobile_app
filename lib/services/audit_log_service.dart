import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/audit_log_entry.dart';

class AuditLogService {
  AuditLogService._internal();
  static final AuditLogService instance = AuditLogService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _auditLogCollection =>
      _firestore.collection('audit_logs');

  /// CHANGED: was a getter with no limit — now a method, capped.
  Stream<List<AuditLogEntry>> auditLogStream({int limit = 50}) {
    return _auditLogCollection
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AuditLogEntry.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// NEW: last login time for the throttle check below.
  Future<DateTime?> lastLoginTime(String email) async {
    try {
      final snapshot = await _auditLogCollection
          .where('performedBy', isEqualTo: email)
          .where('action', isEqualTo: 'login')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return DateTime.parse(snapshot.docs.first.data()['timestamp'] as String);
    } on FirebaseException catch (e) {
      // Some queries require a composite index. Surface a helpful debug
      // message and return null so login can proceed while the index is
      // created. The console link is provided in the exception message.
      debugPrint(
          'AuditLogService.lastLoginTime failed: ${e.code} ${e.message}');
      return null;
    }
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
    await doc.set({
      ...entry.toMap(),
      'expireAt': DateTime.now().add(const Duration(days: 30)),
    });
  }
}
