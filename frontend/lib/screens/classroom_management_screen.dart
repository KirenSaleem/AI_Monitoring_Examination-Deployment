import 'package:flutter/material.dart';

import 'classroom_participants_screen.dart';
import 'exam_history_screen.dart';
import 'monitoring_dashboard.dart';
import 'start_exam_screen.dart';

class ClassroomManagementScreen extends StatelessWidget {
  final Map<String, dynamic> classroom;
  final Map<String, dynamic>? activeSession;
  final String role;
  final String teacherUid;

  const ClassroomManagementScreen({
    super.key,
    required this.classroom,
    required this.activeSession,
    required this.role,
    required this.teacherUid,
  });

  bool get _isTeacher => role == 'teacher';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final classroomId = classroom['classroom_id'] as String? ?? '';
    final classroomName = classroom['classroom_name'] as String? ?? 'Classroom';
    final students = classroom['students_details'] as List<dynamic>? ?? [];
    final teachers = classroom['teachers_details'] as List<dynamic>? ?? [];
    final isActive = activeSession != null;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Text(classroomName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.82)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _classInfoTile(
                          Icons.key_rounded,
                          'Code',
                          classroom['classroom_code'] ?? '-',
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.white24),
                      Expanded(
                        child: _classInfoTile(
                          Icons.people_rounded,
                          'Students',
                          '${students.length}',
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.white24),
                      Expanded(
                        child: _classInfoTile(
                          Icons.school_rounded,
                          'Teachers',
                          '${teachers.length}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive ? Colors.greenAccent : Colors.white54,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isActive ? 'Monitoring Active' : 'Monitoring Inactive',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (_isTeacher) ...[
              // Section label
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  'Actions',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: colorScheme.onSurface.withOpacity(0.45),
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              _actionCard(
                context: context,
                icon: isActive ? Icons.monitor_rounded : Icons.play_circle_rounded,
                iconBgColor: isActive ? Colors.green.shade600 : colorScheme.primary,
                title: isActive ? 'Open Monitoring' : 'Start Monitoring',
                subtitle: isActive
                    ? 'Return to the running exam session'
                    : 'Begin a new monitored exam session',
                onTap: () async {
                  if (activeSession == null) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StartExamScreen(
                          classroomId: classroomId,
                          classroomName: classroomName,
                          teacherUid: teacherUid,
                          students: students,
                        ),
                      ),
                    );
                  } else {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MonitoringDashboard(
                          session: activeSession!,
                          classroomId: classroomId,
                          classroomName: classroomName,
                          students: students,
                          teacherUid: teacherUid,
                        ),
                      ),
                    );
                    if (context.mounted && result == true) {
                      Navigator.pop(context, true);
                    }
                  }
                },
              ),

              const SizedBox(height: 10),

              _actionCard(
                context: context,
                icon: Icons.groups_rounded,
                iconBgColor: Colors.indigo.shade500,
                title: 'View Participants',
                subtitle: 'Browse all teachers and students',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassroomParticipantsScreen(
                        classroomName: classroomName,
                        teachers: teachers,
                        students: students,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              _actionCard(
                context: context,
                icon: Icons.history_rounded,
                iconBgColor: Colors.orange.shade600,
                title: 'Exam History',
                subtitle: 'View past exams and flagged activity',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExamHistoryScreen(
                        classroomId: classroomId,
                        classroomName: classroomName,
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _classInfoTile(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _actionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: colorScheme.onSurface.withOpacity(0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
