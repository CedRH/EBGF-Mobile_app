import '../models/app_user.dart';

/// Holds the currently logged-in user for the whole app session.
///
/// WHY THIS EXISTS: before, `isAdmin` and `userEmail` were passed as
/// constructor params from screen to screen (Login -> Home -> Records...).
/// That gets fragile fast — miss one param on one route and you get a
/// compile error or a silently wrong value. A singleton "session" fixes
/// that: any screen can just ask `SessionService.instance.currentUser`
/// instead of needing it handed down through 5 constructors.
///
/// This is a plain singleton (not Provider/Riverpod) on purpose — it's
/// the simplest thing that works while everything is still mock data.
/// When Firebase Auth is wired in, `login()` below is where you'd store
/// the result of `FirebaseAuth.instance.signInWithEmailAndPassword(...)`
/// plus the role fetched from Firestore.
class SessionService {
  SessionService._internal();
  static final SessionService instance = SessionService._internal();

  AppUser? currentUser;

  bool get isLoggedIn => currentUser != null;
  bool get isAdmin => currentUser?.isAdmin ?? false;

  void login(AppUser user) {
    currentUser = user;
  }

  void logout() {
    currentUser = null;
  }
}
