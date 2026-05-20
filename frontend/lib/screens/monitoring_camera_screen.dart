import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/monitoring_frame_utils.dart';
import '../utils/session_timer_utils.dart';
import '../widgets/camera_zoom_controls.dart';

/// Continuous live preview + ~1 AI scan/sec on downscaled frames (phone & book only).
class MonitoringCameraScreen extends StatefulWidget {
  final String classroomId;
  final String sessionId;
  final String? sessionStartTime;
  final String? sessionEndTime;
  final String sessionStatus;
  final int initialAlertCount;

  const MonitoringCameraScreen({
    super.key,
    required this.classroomId,
    required this.sessionId,
    this.sessionStartTime,
    this.sessionEndTime,
    this.sessionStatus = 'active',
    this.initialAlertCount = 0,
  });

  @override
  State<MonitoringCameraScreen> createState() => _MonitoringCameraScreenState();
}

class _MonitoringCameraScreenState extends State<MonitoringCameraScreen> {
  final ApiService _apiService = ApiService();
  CameraController? _cameraController;
  Timer? _detectionTimer;
  Timer? _uiTimer;
  bool _isAnalyzing = false;
  bool _isReady = false;
  String _statusText = 'Initializing camera...';
  String? _lastAlertText;
  int _framesAnalyzed = 0;
  int _alertCount = 0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _pinchBaseZoom = 1.0;

  static const Duration _detectionInterval = Duration(seconds: 1);

  bool get _isSessionActive => widget.sessionStatus.toLowerCase() == 'active';

  @override
  void initState() {
    super.initState();
    _alertCount = widget.initialAlertCount;
    if (_isSessionActive) {
      _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
    _initCamera();
  }

  Duration _elapsed() {
    return SessionTimer.elapsed(
      startTimeIso: widget.sessionStartTime,
      endTimeIso: widget.sessionEndTime,
      status: widget.sessionStatus,
    );
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _statusText = 'No camera available.');
        return;
      }
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _cameraController!.initialize();
      await _loadZoomLimits();
      if (!mounted) return;
      setState(() {
        _isReady = true;
        _statusText = 'Live Monitoring Active';
      });
      if (_isSessionActive) {
        _startDetectionLoop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusText = 'Camera initialization failed.');
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _loadZoomLimits() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();
      _currentZoom = _minZoom;
    } catch (e) {
      debugPrint('[ExamGuard] Zoom limits: $e');
      _minZoom = 1.0;
      _maxZoom = 1.0;
      _currentZoom = 1.0;
    }
  }

  Future<void> _applyZoom(double level) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    final clamped = level.clamp(_minZoom, _maxZoom);
    try {
      await controller.setZoomLevel(clamped);
      if (mounted) setState(() => _currentZoom = clamped);
    } catch (e) {
      debugPrint('[ExamGuard] setZoomLevel: $e');
    }
  }

  void _startDetectionLoop() {
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(_detectionInterval, (_) => _analyzeNextFrame());
  }

  Future<void> _analyzeNextFrame() async {
    if (!_isSessionActive) return;

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _isAnalyzing) {
      return;
    }
    _isAnalyzing = true;
    String? capturePath;
    String? detectionPath;
    try {
      final XFile capture = await controller.takePicture();
      capturePath = capture.path;
      detectionPath = await prepareDetectionFramePath(capturePath);
      final response = await _apiService.checkMonitoringFrame(
        frameFile: File(detectionPath),
        classroomId: widget.classroomId,
        sessionId: widget.sessionId,
      );
      if (!mounted) return;
      setState(() => _framesAnalyzed++);

      final detected = response['cheating_detected'] as bool? ?? false;
      if (detected) {
        final message = response['message'] as String? ?? 'Suspicious activity detected';
        setState(() {
          _lastAlertText = message;
          _alertCount++;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[ExamGuard] Detection frame: $e');
    } finally {
      for (final path in [detectionPath, capturePath]) {
        if (path != null) {
          try {
            await File(path).delete();
          } catch (_) {}
        }
      }
      _isAnalyzing = false;
    }
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _uiTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = widget.sessionStatus.isEmpty
        ? 'Active'
        : '${widget.sessionStatus[0].toUpperCase()}${widget.sessionStatus.substring(1)}';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Live Monitoring', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _isReady && _cameraController != null
                    ? GestureDetector(
                        onScaleStart: (_) => _pinchBaseZoom = _currentZoom,
                        onScaleUpdate: (details) {
                          _applyZoom(_pinchBaseZoom * details.scale);
                        },
                        child: CameraPreview(_cameraController!),
                      )
                    : Container(
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: Colors.white),
                            const SizedBox(height: 16),
                            Text(
                              _statusText,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                if (_isAnalyzing)
                  const Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: 56),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _liveBadge(),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _chip(Icons.sensors_rounded, '~1 AI scan/s'),
                ),
                if (_isReady)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: CameraZoomControls(
                        currentZoom: _currentZoom,
                        minZoom: _minZoom,
                        maxZoom: _maxZoom,
                        onZoomSelected: _applyZoom,
                      ),
                    ),
                  ),
                if (_lastAlertText != null)
                  Positioned(
                    bottom: 56,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade800.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _lastAlertText!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            color: const Color(0xFF111111),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
            child: Column(
              children: [
                Row(
                  children: [
                    _statTile(
                      Icons.timer_outlined,
                      SessionTimer.formatHms(_elapsed()),
                      'Running Timer',
                      Colors.blue.shade300,
                    ),
                    const SizedBox(width: 10),
                    _statTile(
                      Icons.warning_amber_rounded,
                      '$_alertCount',
                      'Alert Count',
                      Colors.orange.shade400,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statTile(Icons.analytics_outlined, '$_framesAnalyzed', 'AI Scans', Colors.green.shade400),
                    const SizedBox(width: 10),
                    _statTile(Icons.verified_user_outlined, statusLabel, 'Session Status', Colors.teal.shade300),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_statusText, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(),
          SizedBox(width: 6),
          Text(
            'LIVE MONITORING ACTIVE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 13),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _statTile(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_controller),
      child: const SizedBox(
        width: 8,
        height: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
