import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'exam_notifications_screen.dart';

class ExamHistoryScreen extends StatefulWidget {
  final String classroomId;
  final String classroomName;

  const ExamHistoryScreen({
    super.key,
    required this.classroomId,
    required this.classroomName,
  });

  @override
  State<ExamHistoryScreen> createState() => _ExamHistoryScreenState();
}

class _ExamHistoryScreenState extends State<ExamHistoryScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _apiService.getExamHistory(widget.classroomId);
      if (!mounted) return;
      setState(() => _history = history);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}  $hour:$min';
  }

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed': return Colors.green.shade600;
      case 'active': return Colors.blue.shade600;
      case 'cancelled': return Colors.red.shade600;
      default: return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Exam History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            Text(
              widget.classroomName,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.5)),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 64, color: colorScheme.onSurface.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'No exams yet',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: colorScheme.onSurface.withOpacity(0.35),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Completed exams will appear here',
                        style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withOpacity(0.25)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final exam = _history[index];
                      final status = exam['status'] as String?;
                      final alertCount = exam['total_alerts_count'] ?? 0;
                      final suspiciousCount = exam['suspicious_activity_count'] ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              final sessionId = exam['session_id'] as String?;
                              if (sessionId == null || sessionId.isEmpty) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ExamNotificationsScreen(
                                    sessionId: sessionId,
                                    examName: exam['exam_name'] as String? ?? 'Exam',
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(11),
                                        ),
                                        child: Icon(
                                          Icons.assignment_rounded,
                                          color: colorScheme.primary,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              exam['exam_name'] as String? ?? 'Exam',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700, fontSize: 15),
                                            ),
                                            const SizedBox(height: 2),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _statusColor(status).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                status ?? '-',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: _statusColor(status),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: colorScheme.onSurface.withOpacity(0.3),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 14),
                                  Divider(height: 1, color: colorScheme.outline.withOpacity(0.1)),
                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      _timeInfo(
                                        Icons.play_arrow_rounded,
                                        'Start',
                                        _formatDateTime(exam['start_time'] as String?),
                                        colorScheme,
                                      ),
                                      const SizedBox(width: 16),
                                      _timeInfo(
                                        Icons.stop_rounded,
                                        'End',
                                        _formatDateTime(exam['end_time'] as String?),
                                        colorScheme,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      _statBadge(
                                        Icons.notifications_rounded,
                                        '$alertCount',
                                        'Alerts',
                                        Colors.orange.shade600,
                                        colorScheme,
                                      ),
                                      const SizedBox(width: 10),
                                      _statBadge(
                                        Icons.warning_rounded,
                                        '$suspiciousCount',
                                        'Suspicious',
                                        Colors.red.shade600,
                                        colorScheme,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _timeInfo(IconData icon, String label, String value, ColorScheme colorScheme) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurface.withOpacity(0.4)),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withOpacity(0.4))),
              Text(value,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBadge(
    IconData icon,
    String value,
    String label,
    Color color,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}
