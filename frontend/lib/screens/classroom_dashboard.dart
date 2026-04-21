import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'monitoring_dashboard.dart';
import 'start_exam_screen.dart';

class ClassroomDashboard extends StatefulWidget {
  final String firebaseUid;
  final String role;

  const ClassroomDashboard({
    super.key,
    required this.firebaseUid,
    required this.role,
  });

  @override
  State<ClassroomDashboard> createState() => _ClassroomDashboardState();
}

class _ClassroomDashboardState extends State<ClassroomDashboard> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final TextEditingController _classroomNameController = TextEditingController();
  final TextEditingController _classroomCodeController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _classrooms = [];
  final Map<String, Map<String, dynamic>> _activeSessions = {};

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  @override
  void dispose() {
    _classroomNameController.dispose();
    _classroomCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadClassrooms() async {
    setState(() => _isLoading = true);
    try {
      final data = widget.role == 'teacher'
          ? await _apiService.getTeacherClassrooms(widget.firebaseUid)
          : await _apiService.getStudentClassrooms(widget.firebaseUid);
      final Map<String, Map<String, dynamic>> activeSessions = {};
      for (final classroom in data) {
        final classroomId = classroom['classroom_id'] as String?;
        if (classroomId == null) continue;
        final active = await _apiService.getActiveExamSession(classroomId);
        if (active != null) {
          activeSessions[classroomId] = active;
        }
      }
      if (!mounted) return;
      setState(() {
        _classrooms = data;
        _activeSessions
          ..clear()
          ..addAll(activeSessions);
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createClassroom() async {
    final String classroomName = _classroomNameController.text.trim();
    if (classroomName.isEmpty) {
      _showMessage('Please enter classroom name.');
      return;
    }

    try {
      final response = await _apiService.createClassroom(
        classroomName: classroomName,
        createdBy: widget.firebaseUid,
      );
      final classroom = response['classroom'] as Map<String, dynamic>;
      _showMessage('Created. Code: ${classroom['classroom_code']}');
      _classroomNameController.clear();
      await _loadClassrooms();
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _joinClassroom() async {
    final String classroomCode = _classroomCodeController.text.trim().toUpperCase();
    if (classroomCode.isEmpty) {
      _showMessage('Please enter classroom code.');
      return;
    }
    try {
      await _apiService.joinClassroom(
        firebaseUid: widget.firebaseUid,
        classroomCode: classroomCode,
      );
      _showMessage('Joined classroom successfully.');
      _classroomCodeController.clear();
      await _loadClassrooms();
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openStartMonitoring(Map<String, dynamic> classroom) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StartExamScreen(
          classroomId: classroom['classroom_id'] as String,
          classroomName: classroom['classroom_name'] as String? ?? 'Classroom',
          teacherUid: widget.firebaseUid,
          students: classroom['students'] as List<dynamic>? ?? [],
        ),
      ),
    );
    if (result == true) {
      await _loadClassrooms();
    } else {
      await _loadClassrooms();
    }
  }

  Future<void> _openMonitoringDashboard(
    Map<String, dynamic> classroom,
    Map<String, dynamic> session,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MonitoringDashboard(
          session: session,
          classroomName: classroom['classroom_name'] as String? ?? 'Classroom',
          students: classroom['students'] as List<dynamic>? ?? [],
          teacherUid: widget.firebaseUid,
        ),
      ),
    );
    if (result == true) {
      await _loadClassrooms();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bool isTeacher = widget.role == 'teacher';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Classroom Dashboard'),
        actions: [
          TextButton(
            onPressed: _logout,
            child: const Text('Logout'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Role: ${widget.role.toUpperCase()}'),
            const SizedBox(height: 12),
            if (isTeacher) ...[
              TextField(
                controller: _classroomNameController,
                decoration: const InputDecoration(
                  labelText: 'Classroom Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _createClassroom,
                child: const Text('Create Classroom'),
              ),
            ] else ...[
              TextField(
                controller: _classroomCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Classroom Code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _joinClassroom,
                child: const Text('Join Classroom'),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Your Classrooms'),
                TextButton(onPressed: _loadClassrooms, child: const Text('Refresh')),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_classrooms.isEmpty)
              const Text('No classrooms yet.')
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _classrooms.length,
                  itemBuilder: (context, index) {
                    final classroom = _classrooms[index];
                    final classroomId = classroom['classroom_id'] as String?;
                    final activeSession =
                        classroomId == null ? null : _activeSessions[classroomId];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              title: Text(classroom['classroom_name'] ?? 'Unnamed Class'),
                              subtitle: Text('Code: ${classroom['classroom_code'] ?? '-'}'),
                            ),
                            if (activeSession != null)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Monitoring Active'),
                              ),
                            if (widget.role == 'teacher') ...[
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: activeSession == null
                                    ? () => _openStartMonitoring(classroom)
                                    : () => _openMonitoringDashboard(classroom, activeSession),
                                child: Text(
                                  activeSession == null
                                      ? 'Start Monitoring'
                                      : 'Open Monitoring',
                                ),
                              ),
                            ] else if (activeSession != null) ...[
                              const SizedBox(height: 8),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('You are linked to this active exam session.'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
