import 'package:flutter/material.dart';

import '../services/api_service.dart';

class MonitoringDashboard extends StatefulWidget {
  final Map<String, dynamic> session;
  final String classroomName;
  final List<dynamic> students;
  final String teacherUid;

  const MonitoringDashboard({
    super.key,
    required this.session,
    required this.classroomName,
    required this.students,
    required this.teacherUid,
  });

  @override
  State<MonitoringDashboard> createState() => _MonitoringDashboardState();
}

class _MonitoringDashboardState extends State<MonitoringDashboard> {
  final ApiService _apiService = ApiService();
  bool _isEnding = false;
  late Map<String, dynamic> _session;

  @override
  void initState() {
    super.initState();
    _session = Map<String, dynamic>.from(widget.session);
  }

  Future<void> _endMonitoring() async {
    setState(() => _isEnding = true);
    try {
      final response = await _apiService.endExamSession(
        sessionId: _session['session_id'] as String,
        endedBy: widget.teacherUid,
      );
      if (!mounted) return;
      setState(() => _session = response['session'] as Map<String, dynamic>);
      _showMessage('Monitoring ended.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isEnding = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final monitoredStudents = (_session['monitored_students'] as List<dynamic>? ?? widget.students);
    final status = (_session['status'] as String?) ?? 'unknown';

    return Scaffold(
      appBar: AppBar(title: const Text('Monitoring Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Exam: ${_session['exam_name'] ?? '-'}'),
            Text('Classroom: ${widget.classroomName}'),
            Text('Monitoring Status: $status'),
            const SizedBox(height: 12),
            const Text('Students in Classroom'),
            const SizedBox(height: 8),
            if (monitoredStudents.isEmpty)
              const Text('No students joined yet.')
            else
              Expanded(
                child: ListView.builder(
                  itemCount: monitoredStudents.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(monitoredStudents[index].toString()),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: status == 'active' && !_isEnding ? _endMonitoring : null,
              child: const Text('End Monitoring'),
            ),
          ],
        ),
      ),
    );
  }
}
