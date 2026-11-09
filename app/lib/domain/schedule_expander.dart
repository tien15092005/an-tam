/// A time of day, minute precision ("07:30").
class TimeOfDose implements Comparable<TimeOfDose> {
  const TimeOfDose(this.hour, this.minute);

  factory TimeOfDose.parse(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDose(int.parse(parts[0]), int.parse(parts[1]));
  }

  final int hour;
  final int minute;

  int get minutes => hour * 60 + minute;

  @override
  int compareTo(TimeOfDose other) => minutes.compareTo(other.minutes);

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) => other is TimeOfDose && other.minutes == minutes;

  @override
  int get hashCode => minutes;
}

/// Bit 0 = Monday … bit 6 = Sunday. Empty = every day (127).
int weekdayMask(List<int> isoDays) => isoDays.isEmpty ? 127 : isoDays.fold(0, (m, d) => m | (1 << (d - 1)));

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Dose times on dates [from]..[to] (inclusive, local), sorted. Mirrors backend `ScheduleExpander`;
/// both pass shared/test-vectors/schedule-expansion.json.
List<DateTime> expandSchedule({
  required List<TimeOfDose> times,
  required int daysMask,
  required DateTime startDate,
  DateTime? endDate,
  required DateTime from,
  required DateTime to,
}) {
  final sorted = [...times]..sort();
  var day = dateOnly(from.isBefore(startDate) ? startDate : from);
  final last = dateOnly(endDate != null && endDate.isBefore(to) ? endDate : to);
  final out = <DateTime>[];
  // Step by calendar day (not 24 h), so a DST change on a travelling phone cannot skip a date.
  while (!day.isAfter(last)) {
    if (daysMask & (1 << (day.weekday - 1)) != 0) {
      for (final t in sorted) {
        out.add(DateTime(day.year, day.month, day.day, t.hour, t.minute));
      }
    }
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return out;
}
