import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ExamNotificationsScreen extends StatefulWidget {
  final String sessionId;
  final String examName;

  const ExamNotificationsScreen({
    super.key,
    required this.sessionId,
    required this.examName,
  });

  @override
  State<ExamNotificationsScreen> createState() => _ExamNotificationsScreenState();
}

class _ExamNotificationsScreenState extends State<ExamNotificationsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await _apiService.getExamNotifications(widget.sessionId);
      if (!mounted) return;
      setState(() => _notifications = notifications);
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

  String _formatAlertType(String? raw) {
    if (raw == null || raw.isEmpty) return 'Unknown Alert';
    return raw.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
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

  Color _severityColor(dynamic confidence) {
    final val = double.tryParse(confidence?.toString() ?? '') ?? 0;
    if (val >= 0.8) return Colors.red.shade600;
    if (val >= 0.5) return Colors.orange.shade600;
    return Colors.amber.shade600;
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
            const Text('Alert Log', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            Text(
              widget.examName,
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
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 64, color: Colors.green.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text(
                        'All Clear',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No alerts were recorded for this exam',
                        style: TextStyle(
                            fontSize: 13, color: colorScheme.onSurface.withOpacity(0.3)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final alert = _notifications[index];
                      final confidence = alert['confidence'] ?? 0;
                      final alertType = alert['alert_type'] as String?;
                      final severityColor = _severityColor(confidence);
                      final imageUrl = _apiService.buildAbsoluteUrl(
                        alert['evidence_image_url'] as String?,
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: severityColor.withOpacity(0.25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: severityColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.warning_rounded,
                                      color: severityColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatAlertType(alertType),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700, fontSize: 14),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatDateTime(alert['created_at'] as String?),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurface.withOpacity(0.45),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${(double.tryParse(confidence.toString()) ?? 0 * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: severityColor,
                                        ),
                                      ),
                                      Text(
                                        'confidence',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: colorScheme.onSurface.withOpacity(0.4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Status bar
                            Container(
                              margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, size: 8,
                                      color: colorScheme.onSurface.withOpacity(0.35)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Status: ${alert['status'] ?? '-'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Evidence image
                            if (imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(16)),
                                child: Image.network(
                                  imageUrl,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 80,
                                    alignment: Alignment.center,
                                    color: colorScheme.surfaceContainerHighest,
                                    child: Text(
                                      'Evidence image unavailable',
                                      style: TextStyle(
                                        color: colorScheme.onSurface.withOpacity(0.4),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                height: 70,
                                alignment: Alignment.center,
                                margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: colorScheme.outline.withOpacity(0.1)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.image_not_supported_outlined,
                                        size: 20,
                                        color: colorScheme.onSurface.withOpacity(0.25)),
                                    const SizedBox(height: 4),
                                    Text(
                                      'No evidence image',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface.withOpacity(0.3),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
