import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'monitoring_dashboard.dart';

class StartExamScreen extends StatefulWidget {
  final String classroomId;
  final String classroomName;
  final String teacherUid;
  final List<dynamic> students;

  const StartExamScreen({
    super.key,
    required this.classroomId,
    required this.classroomName,
    required this.teacherUid,
    required this.students,
  });

  @override
  State<StartExamScreen> createState() => _StartExamScreenState();
}

class _StartExamScreenState extends State<StartExamScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _examNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _examNameController.dispose();
    super.dispose();
  }

  Future<void> _startMonitoring() async {
    final examName = _examNameController.text.trim();
    if (examName.isEmpty) {
      _showMessage('Please enter exam name.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _apiService.startExamSession(
        classroomId: widget.classroomId,
        examName: examName,
        startedBy: widget.teacherUid,
      );
      final session = response['session'] as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MonitoringDashboard(
            session: session,
            classroomName: widget.classroomName,
            students: widget.students,
            teacherUid: widget.teacherUid,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start Monitoring')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Classroom: ${widget.classroomName}'),
            const SizedBox(height: 12),
            TextField(
              controller: _examNameController,
              decoration: const InputDecoration(
                labelText: 'Exam Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _startMonitoring,
              child: const Text('Start'),
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
