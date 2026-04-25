import 'dart:io';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'classroom_management_screen.dart';
import 'login_screen.dart';

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

  bool _isLoading = false;
  List<Map<String, dynamic>> _classrooms = [];
  Map<String, dynamic>? _currentUser;
  final Map<String, Map<String, dynamic>> _activeSessions = {};

  bool get _isTeacher => widget.role == 'teacher';

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  Future<void> _loadClassrooms() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _apiService.getUserProfile(widget.firebaseUid);
      final data = _isTeacher
          ? await _apiService.getTeacherClassrooms(widget.firebaseUid)
          : await _apiService.getStudentClassrooms(widget.firebaseUid);

      final activeSessions = <String, Map<String, dynamic>>{};
      for (final classroom in data) {
        final classroomId = classroom['classroom_id'] as String?;
        if (classroomId == null) continue;
        final active = await _apiService.getActiveExamSession(classroomId);
        if (active != null) activeSessions[classroomId] = active;
      }

      if (!mounted) return;
      setState(() {
        _currentUser = profile;
        _classrooms = data;
        _activeSessions
          ..clear()
          ..addAll(activeSessions);
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _createClassroomDialog() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Classroom', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Classroom name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.class_outlined),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              try {
                final response = await _apiService.createClassroom(
                  classroomName: name,
                  createdBy: widget.firebaseUid,
                );
                final classroom = response['classroom'] as Map<String, dynamic>;
                _showMessage('Classroom created · Code: ${classroom['classroom_code']}');
                await _loadClassrooms();
              } catch (e) {
                _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
              }
            },
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _joinClassroomDialog() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Join Classroom', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Classroom code',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.vpn_key_outlined),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final code = controller.text.trim().toUpperCase();
              if (code.isEmpty) return;
              Navigator.pop(context);
              try {
                await _apiService.joinClassroom(
                  firebaseUid: widget.firebaseUid,
                  classroomCode: code,
                );
                _showMessage(_isTeacher
                    ? 'Joined classroom as additional teacher.'
                    : 'Joined classroom successfully.');
                await _loadClassrooms();
              } catch (e) {
                _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
              }
            },
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Widget _buildHeader() {
    final name = _currentUser?['name'] as String? ?? 'User';
    final role = (_currentUser?['role'] as String? ?? widget.role);
    final imagePath = _currentUser?['profile_image'] as String?;
    ImageProvider? profileProvider;
    if (imagePath != null && imagePath.isNotEmpty) {
      profileProvider = imagePath.startsWith('http')
          ? NetworkImage(imagePath)
          : FileImage(File(imagePath));
    }
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outline.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: colorScheme.primaryContainer,
            backgroundImage: profileProvider,
            child: profileProvider == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(
                  '${role[0].toUpperCase()}${role.substring(1)}',
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withOpacity(0.5)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _logout,
            icon: Icon(Icons.logout_rounded, color: colorScheme.onSurface.withOpacity(0.5)),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final activeCount = _activeSessions.length;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('${_classrooms.length}', 'Classrooms', Icons.class_rounded),
          Container(width: 1, height: 32, color: Colors.white24),
          _statItem('$activeCount', 'Active Sessions', Icons.videocam_rounded),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildClassroomCard(Map<String, dynamic> classroom) {
    final colorScheme = Theme.of(context).colorScheme;
    final classroomId = classroom['classroom_id'] as String?;
    final activeSession = classroomId == null ? null : _activeSessions[classroomId];
    final students = classroom['students_details'] as List<dynamic>? ?? [];
    final teachers = classroom['teachers_details'] as List<dynamic>? ?? [];
    final teacherNames = teachers
        .whereType<Map<String, dynamic>>()
        .map((t) => (t['name'] as String?) ?? 'Teacher')
        .join(', ');
    final isActive = activeSession != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? colorScheme.primary.withOpacity(0.4)
              : colorScheme.outline.withOpacity(0.15),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClassroomManagementScreen(
                  classroom: classroom,
                  activeSession: activeSession,
                  role: widget.role,
                  teacherUid: widget.firebaseUid,
                ),
              ),
            );
            if (result != null) await _loadClassrooms();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        classroom['classroom_name'] as String? ?? 'Classroom',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Live',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    _infoChip(
                      Icons.key_rounded,
                      classroom['classroom_code'] ?? '-',
                      colorScheme,
                    ),
                    const SizedBox(width: 8),
                    if (_isTeacher)
                      _infoChip(
                        Icons.people_outline_rounded,
                        '${students.length} students',
                        colorScheme,
                      )
                    else
                      Flexible(
                        child: _infoChip(
                          Icons.person_outline_rounded,
                          teacherNames.isEmpty ? 'No teacher' : teacherNames,
                          colorScheme,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _isTeacher ? 'Manage Classroom' : 'Open Classroom',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 13, color: colorScheme.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.65)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'My Classrooms',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add_rounded, color: colorScheme.onPrimaryContainer, size: 20),
            ),
            color: colorScheme.surface,
            surfaceTintColor: colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'create') _createClassroomDialog();
              else if (value == 'join') _joinClassroomDialog();
            },
            itemBuilder: (context) {
              final items = <PopupMenuEntry<String>>[];
              if (_isTeacher) {
                items.add(PopupMenuItem(
                  value: 'create',
                  child: Row(
                    children: [
                      Icon(Icons.add_box_outlined, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      const Text('Create Classroom', style: TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                ));
              }
              items.add(PopupMenuItem(
                value: 'join',
                child: Row(
                  children: [
                    Icon(Icons.login_rounded, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 10),
                    const Text('Join Classroom', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ));
              return items;
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadClassrooms,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildStatsBar()),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          sliver: _classrooms.isEmpty
                              ? SliverFillRemaining(
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.class_outlined,
                                          size: 64,
                                          color: colorScheme.onSurface.withOpacity(0.2),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No classrooms yet',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface.withOpacity(0.4),
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _isTeacher
                                              ? 'Create your first classroom'
                                              : 'Join a classroom using a code',
                                          style: TextStyle(
                                            color: colorScheme.onSurface.withOpacity(0.3),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _buildClassroomCard(_classrooms[index]),
                                    childCount: _classrooms.length,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
