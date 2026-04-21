import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'classroom_dashboard.dart';
import 'profile_setup_screen.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    await _handleAuthAction(
      () => _authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      ),
      successMessage: 'Login successful',
    );
  }

  Future<void> _register() async {
    await _handleAuthAction(
      () => _authService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      ),
      successMessage: 'Registration successful',
    );
  }

  Future<void> _googleSignIn() async {
    await _handleAuthAction(
      () => _authService.signInWithGoogle(),
      successMessage: 'Google sign-in successful',
      requireEmailPassword: false,
    );
  }

  Future<void> _handleAuthAction(
    Future<UserCredential?> Function() action, {
    required String successMessage,
    bool requireEmailPassword = true,
  }) async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (requireEmailPassword && (email.isEmpty || password.isEmpty)) {
      _showMessage('Email and password are required.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final UserCredential? result = await action();
      if (!mounted) return;
      if (result == null) {
        _showMessage('Google sign-in cancelled.');
        return;
      }
      _showMessage(successMessage);
      final User? user = result.user;
      if (user == null || user.email == null) {
        _showMessage('Could not read user info.');
        return;
      }

      final profile = await _apiService.getUserProfile(user.uid);
      if (!mounted) return;

      if (profile != null) {
        final role = (profile['role'] as String?) ?? 'student';
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ClassroomDashboard(
              firebaseUid: user.uid,
              role: role,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(
              firebaseUid: user.uid,
              email: user.email!,
            ),
          ),
        );
      }
    } on Exception catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } catch (_) {
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ExamGuard Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: const Text('Login'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _register,
              child: const Text('Register'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _isLoading ? null : _googleSignIn,
              child: const Text('Google Sign-In'),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
