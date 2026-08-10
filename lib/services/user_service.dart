import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

/// Firestore-backed stream of every user in the `users` collection, plus
/// promote/demote writes. AuthService only ever fetches the CURRENT
/// user's profile on sign-in — this covers "see everyone", which is what
/// User Management and Analytics' "Total Users" need.
class UserService {
  UserService._internal();
  static final UserService instance = UserService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  Stream<List<AppUser>> get usersStream {
    return _usersCollection.orderBy('createdAt').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AppUser.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }

  Future<void> promoteUser(String userId) {
    return _usersCollection.doc(userId).update({'role': UserRole.admin.name});
  }

  Future<void> demoteUser(String userId) {
    return _usersCollection.doc(userId).update({'role': UserRole.user.name});
  }

  /// Deletes only the Firestore profile doc — NOT the underlying Firebase
  /// Auth account (client SDK can't delete other users' Auth accounts;
  /// that needs a Cloud Function with the Admin SDK, which this project
  /// doesn't have set up yet).
  ///
  /// Effect: the user is immediately locked out, because AuthService.signIn
  /// throws "No profile found for this account" when the doc is missing —
  /// even though the Auth account technically still exists.
  Future<void> deleteUser(String userId) {
    return _usersCollection.doc(userId).delete();
  }
}
