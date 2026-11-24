/// Status of one scheduled dose. Mirrors backend `vn.antam.schedule.DoseStatus`;
/// both pass the cases in shared/test-vectors/dose-status.json.
enum DoseStatus { upcoming, due, missed, taken, notTaken, skipped, notApplicable }

/// After 3 alarm attempts (at 0, 10 and 20 minutes) the phone goes quiet and caregivers are told.
const doseGrace = Duration(minutes: 30);

/// [due], [now] and [createdAt] are the elder's local wall-clock times.
/// [logStatus] is TAKEN / NOT_TAKEN / SKIPPED, or null when nothing was recorded.
DoseStatus doseStatusOf({required DateTime due, required DateTime now, required DateTime createdAt, String? logStatus}) {
  switch (logStatus) {
    case 'TAKEN':
      return DoseStatus.taken;
    case 'NOT_TAKEN':
      return DoseStatus.notTaken;
    case 'SKIPPED':
      return DoseStatus.skipped;
  }
  final createdMinute = DateTime(createdAt.year, createdAt.month, createdAt.day, createdAt.hour, createdAt.minute);
  if (createdMinute.isAfter(due)) return DoseStatus.notApplicable;
  if (now.isBefore(due)) return DoseStatus.upcoming;
  return now.difference(due) <= doseGrace ? DoseStatus.due : DoseStatus.missed;
}
