import 'package:flutter/material.dart';

/// Compact 1x / 2x / 3x zoom presets for live camera monitoring.
class CameraZoomControls extends StatelessWidget {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onZoomSelected;

  const CameraZoomControls({
    super.key,
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomSelected,
  });

  double _clampPreset(double preset) => preset.clamp(minZoom, maxZoom);

  @override
  Widget build(BuildContext context) {
    const presets = [1.0, 2.0, 3.0];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 16),
          const SizedBox(width: 4),
          ...presets.map((preset) {
            final target = _clampPreset(preset);
            final selected = (currentZoom - target).abs() < 0.15;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: selected ? Colors.white24 : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: maxZoom < minZoom + 0.01 ? null : () => onZoomSelected(target),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      '${preset.toStringAsFixed(0)}x',
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
