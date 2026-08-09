import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/farm_record.dart';

/// Firestore-backed source of truth for farm records. Replaces the
/// in-memory ChangeNotifier version — every screen gets pushed updates
/// the instant a record changes, on ANY device, not just within one
/// running app instance.
class RecordsService {
  RecordsService._internal();
  static final RecordsService instance = RecordsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _recordsCollection =>
      _firestore.collection('records');

  Stream<List<FarmRecord>> get recordsStream {
    return _recordsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FarmRecord.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Firestore assigns the doc ID — the `id` on the record you pass in
  /// is ignored/overwritten.
  Future<void> addRecord(FarmRecord record) async {
    final doc = _recordsCollection.doc();
    await doc.set({...record.toMap(), 'id': doc.id});
  }

  Future<void> deleteRecord(String id) {
    return _recordsCollection.doc(id).delete();
  }

  Future<void> editRecord(FarmRecord updated) {
    return _recordsCollection.doc(updated.id).update(updated.toMap());
  }
}
