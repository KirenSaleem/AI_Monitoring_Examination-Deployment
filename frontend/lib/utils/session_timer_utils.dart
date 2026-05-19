/// Elapsed exam/monitoring time from ISO timestamps returned by the API.
class SessionTimer {
  SessionTimer._();

  static Duration elapsed({
    required String? startTimeIso,
    String? endTimeIso,
    String? status,
  }) {
    if (startTimeIso == null || startTimeIso.isEmpty) {
      return Duration.zero;
    }

    final start = DateTime.parse(startTimeIso);
    final normalizedStatus = (status ?? '').toLowerCase();
    final isCompleted = normalizedStatus == 'completed';

    final DateTime end;
    if (isCompleted && endTimeIso != null && endTimeIso.isNotEmpty) {
      end = DateTime.parse(endTimeIso);
    } else if (isCompleted) {
      end = start;
    } else {
      end = DateTime.now();
    }

    final diff = end.difference(start);
    if (diff.isNegative) return Duration.zero;
    return diff;
  }

  static String formatHms(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
