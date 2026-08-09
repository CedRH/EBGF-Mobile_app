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
}
