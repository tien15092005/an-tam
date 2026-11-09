import '../domain/dose_status.dart';
import '../domain/schedule_expander.dart';
import 'alarm_channel.dart';

/// One medication as the elder's phone keeps it (photos are local file paths).
class ElderMed {
  const ElderMed({
    required this.id,
    required this.name,
    this.strength,
    this.dosage,
    required this.description,
    this.note,
    required this.times,
    required this.daysMask,
    required this.startDate,
    this.endDate,
    required this.createdAt,
    this.photos = const [],
  });

  final int id;
  final String name;
  final String? strength;
  final String? dosage;
  final String description;
  final String? note;
  final List<TimeOfDose> times;
  final int daysMask;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  /// Pill photos first, then packaging.
  final List<String> photos;

  List<DateTime> dosesBetween(DateTime from, DateTime to) =>
      expandSchedule(times: times, daysMask: daysMask, startDate: startDate, endDate: endDate, from: from, to: to);
}

String doseKey(int medicationId, DateTime minute) => '$medicationId@${minute.millisecondsSinceEpoch}';

class DoseSlot {
  const DoseSlot(this.at, this.med, [this.logStatus]);
  final DateTime at;
  final ElderMed med;

  /// TAKEN / NOT_TAKEN / SKIPPED once answered.
  final String? logStatus;

  DoseStatus statusAt(DateTime now) => doseStatusOf(due: at, now: now, createdAt: med.createdAt, logStatus: logStatus);
}

class ElderSchedule {
  const ElderSchedule({
    required this.callName,
    required this.version,
    required this.meds,
    this.lastSynced,
    this.offline = false,
    this.logs = const {},
  });

  static const empty = ElderSchedule(callName: '', version: -1, meds: []);

  final String callName;
  final int version;
  final List<ElderMed> meds;
  final DateTime? lastSynced;

  /// True when the last attempt to reach the server failed and this is the saved copy.
  final bool offline;

  /// Answers per dose, keyed by [doseKey].
  final Map<String, String> logs;

  ElderSchedule copyWith({bool? offline, Map<String, String>? logs}) => ElderSchedule(
      callName: callName,
      version: version,
      meds: meds,
      lastSynced: lastSynced,
      offline: offline ?? this.offline,
      logs: logs ?? this.logs);

  /// Doses on one calendar day, by time.
  List<DoseSlot> dosesOn(DateTime day) {
    final d = dateOnly(day);
    final slots = [
      for (final m in meds)
        for (final at in m.dosesBetween(d, d)) DoseSlot(at, m, logs[doseKey(m.id, at)]),
    ]..sort((a, b) => a.at.compareTo(b.at));
    return slots;
  }

  /// Doses due at exactly this minute (what a ringing alarm is about).
  List<ElderMed> medsAt(DateTime minute) =>
      [for (final s in dosesOn(minute)) if (s.at == minute) s.med];

  /// The next dose still to take today (due now or later), for the home screen's big card.
  DoseSlot? nextDose(DateTime now) {
    for (final s in dosesOn(now)) {
      final st = s.statusAt(now);
      if (st == DoseStatus.due || st == DoseStatus.upcoming) return s;
    }
    return null;
  }
}

/// What the phone says aloud. Names and amounts only: "5mg" read by TTS is confusing, the dose is not.
String speechFor(String callName, List<ElderMed> meds) {
  final who = callName.isEmpty ? '' : '$callName ơi, ';
  if (meds.isEmpty) return '$whođến giờ uống thuốc rồi ạ. Uống xong, bấm nút màu xanh.';
  final parts = [
    for (final m in meds)
      [m.name, if (m.dosage != null) m.dosage!, if (m.description.isNotEmpty) m.description].join(', '),
  ];
  final count = meds.length == 1 ? '' : 'Có ${meds.length} loại. ';
  return '$whođến giờ uống thuốc rồi ạ. $count${parts.join('. ')}. Uống xong, ${callName.isEmpty ? '' : '$callName '}bấm nút màu xanh.';
}

String titleFor(List<ElderMed> meds) => meds.isEmpty ? 'Đến giờ uống thuốc' : 'Uống thuốc: ${meds.map((m) => m.name).join(', ')}';

/// One alarm per minute that has doses, for [days] days from [now]. Doses at the same minute share
/// one alarm, so two medicines at 8:00 ring once and are read out together.
List<ScheduledAlarm> buildAlarms(ElderSchedule s, DateTime now, {int days = 7}) {
  final today = dateOnly(now);
  final last = DateTime(today.year, today.month, today.day + days - 1);
  final byMinute = <DateTime, List<ElderMed>>{};
  for (final m in s.meds) {
    for (final at in m.dosesBetween(today, last)) {
      if (!at.isAfter(now)) continue;
      // A medication added after today's time does not ring for it (NOT_APPLICABLE).
      if (doseStatusOf(due: at, now: now, createdAt: m.createdAt) == DoseStatus.notApplicable) continue;
      // Already answered (e.g. confirmed early from the home screen): do not ring.
      if (s.logs.containsKey(doseKey(m.id, at))) continue;
      byMinute.putIfAbsent(at, () => []).add(m);
    }
  }
  final minutes = byMinute.keys.toList()..sort();
  return [
    for (final at in minutes)
      ScheduledAlarm(id: alarmIdForMinute(at), at: at, title: titleFor(byMinute[at]!), speech: speechFor(s.callName, byMinute[at]!)),
  ];
}
