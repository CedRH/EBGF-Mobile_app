import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

/// Wraps Firebase Auth + Firestore so the UI screens never talk to
/// FirebaseAuth/Firestore directly. This replaces the placeholder
/// "email contains admin" logic from before.
///
/// HOW ROLES WORK: on sign-up, every new account is written to Firestore's
/// `users` collection with role: "user". Nobody can sign up as admin —
/// you (or another admin, later via User Management) must manually
/// promote them. This mirrors exactly what the comment in
/// signup_screen.dart already told you to do.
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Signs in with email/password, then fetches the matching profile
  /// (name, role, etc.) from Firestore's `users` collection.
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;
    final doc = await _usersCollection.doc(uid).get();

    if (!doc.exists) {
      // Auth account exists but no Firestore profile — shouldn't normally
      // happen if everyone signed up through signUp() below, but this
      // keeps the app from crashing if it does.
      throw Exception(
        'No profile found for this account. Please contact an admin.',
      );
    }

    return AppUser.fromMap({...doc.data()!, 'id': uid});
  }

  /// Creates a new Firebase Auth account AND a matching Firestore profile
  /// document, always with role: user (never admin).
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;
    final newUser = AppUser(
      id: uid,
      name: name.trim(),
      email: email.trim(),
      role: UserRole.user,
      createdAt: DateTime.now(),
    );

    await _usersCollection.doc(uid).set(newUser.toMap());
    return newUser;
  }

  Future<void> signOut() => _auth.signOut();

  /// Human-friendly message from a FirebaseAuthException's error code,
  /// so the UI can show something better than a raw exception string.
  String friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password is too weak (use at least 6 characters).';
      case 'invalid-email':
        return 'That email address looks invalid.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
