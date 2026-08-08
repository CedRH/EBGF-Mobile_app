import 'package:flutter/material.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import '../models/app_user.dart';
import '../services/session_service.dart';
import '../services/admin_mock_data.dart';
import '../models/audit_log_entry.dart';

/// Login screen.
///
/// NOTE: This screen currently checks credentials with placeholder logic
/// so you can see and test the UI immediately. When you connect Firebase
/// (see the setup guide), replace `_handleLogin` with a real
/// FirebaseAuth.signInWithEmailAndPassword call, then look up the user's
/// role ("admin" or "user") from Firestore.
///
/// CHANGE FROM BEFORE: instead of navigating to HomeScreen with
/// `userEmail`/`isAdmin` constructor params, this now builds an [AppUser]
/// and stores it in [SessionService]. HomeScreen (and every admin screen
/// after it) reads the logged-in user from there instead.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // TODO: Replace with real Firebase Auth call, e.g.:
    // final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
    //   email: _emailController.text.trim(),
    //   password: _passwordController.text.trim(),
    // );
    // Then fetch role from Firestore using credential.user!.uid

    await Future.delayed(const Duration(milliseconds: 600)); // placeholder

    final email = _emailController.text.trim();

    // Placeholder role logic: anything with "admin" in the email becomes admin.
    final isAdmin = email.toLowerCase().contains('admin');

    // Try to find an existing mock user with this email (e.g. admin@test.com,
    // juan@test.com from AdminMockData's seed data) so User Management shows
    // the same identity you're logged in as. If not found, create one.
    final existing = AdminMockData.instance.allUsers
        .where((u) => u.email.toLowerCase() == email.toLowerCase());

    final user = existing.isNotEmpty
        ? existing.first
        : AppUser(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: email.split('@').first,
            email: email,
            role: isAdmin ? UserRole.admin : UserRole.user,
            createdAt: DateTime.now(),
          );

    if (existing.isEmpty) {
      AdminMockData.instance.allUsers.add(user);
    }

    SessionService.instance.login(user);
    AdminMockData.instance.logAction(
      action: AuditActionType.login,
      performedBy: user.email,
      description: 'Signed in',
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Image.asset(
                    'assets/icons/chicken_logo.png',
                    height: 72,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Farm Records',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Sign in to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Log In'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignUpScreen()),
                      );
                    },
                    child: const Text("Don't have an account? Sign up"),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
