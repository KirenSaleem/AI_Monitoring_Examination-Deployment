import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ExamGuard Dashboard')),
      body: const Center(
        child: Text(
          'Profile setup complete.\nWelcome to ExamGuard!',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
