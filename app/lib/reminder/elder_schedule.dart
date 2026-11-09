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

/// One exercise reminder (plan §9: same alarm, its own words and a "TÔI ĐI TẬP ĐÂY" button).
class ElderExercise {
  const ElderExercise({
    required this.id,
    required this.title,
    required this.time,
    required this.daysMask,
    this.durationMin,
    this.note,
    required this.startDate,
    this.endDate,
    required this.createdAt,
  });

  final int id;
  final String title;
  final TimeOfDose time;
  final int daysMask;
  final int? durationMin;
  final String? note;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  List<DateTime> timesBetween(DateTime from, DateTime to) =>
      expandSchedule(times: [time], daysMask: daysMask, startDate: startDate, endDate: endDate, from: from, to: to);

  /// "Đi bộ, 20 phút"
  String get spoken => [title, if (durationMin != null) '$durationMin phút'].join(', ');
}

String exerciseKey(int exerciseId, DateTime day) => '$exerciseId@${dateOnly(day).millisecondsSinceEpoch}';

class ExerciseSlot {
  const ExerciseSlot(this.at, this.exercise, {required this.done});
  final DateTime at;
  final ElderExercise exercise;
  final bool done;

  /// DONE shows as taken; otherwise the same clock rules as a dose.
  DoseStatus statusAt(DateTime now) =>
      doseStatusOf(due: at, now: now, createdAt: exercise.createdAt, logStatus: done ? 'TAKEN' : null);
}

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
    this.exercises = const [],
    this.exercisesDone = const {},
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

  final List<ElderExercise> exercises;

  /// Exercises the elder went to, keyed by [exerciseKey].
  final Set<String> exercisesDone;

  ElderSchedule copyWith({bool? offline, Map<String, String>? logs, Set<String>? exercisesDone}) => ElderSchedule(
      callName: callName,
      version: version,
      meds: meds,
      lastSynced: lastSynced,
      offline: offline ?? this.offline,
      logs: logs ?? this.logs,
      exercises: exercises,
      exercisesDone: exercisesDone ?? this.exercisesDone);

  List<ExerciseSlot> exercisesOn(DateTime day) {
    final d = dateOnly(day);
    return [
      for (final e in exercises)
        for (final at in e.timesBetween(d, d)) ExerciseSlot(at, e, done: exercisesDone.contains(exerciseKey(e.id, at))),
    ]..sort((a, b) => a.at.compareTo(b.at));
  }

  /// Exercises due at exactly this minute.
  List<ElderExercise> exercisesAt(DateTime minute) =>
      [for (final s in exercisesOn(minute)) if (s.at == minute) s.exercise];

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

/// Exercise-only alarm, or the tail added after the medicines when both share a minute.
String exerciseSpeechFor(String callName, List<ElderExercise> exercises, {bool afterMeds = false}) {
  final list = exercises.map((e) => e.spoken).join('. ');
  if (afterMeds) return ' Sau đó đến giờ tập: $list.';
  final who = callName.isEmpty ? '' : '$callName ơi, ';
  return '$whođến giờ tập thể dục rồi ạ. $list. Đi tập thì ${callName.isEmpty ? '' : '$callName '}bấm nút màu xanh.';
}

String titleFor(List<ElderMed> meds) => meds.isEmpty ? 'Đến giờ uống thuốc' : 'Uống thuốc: ${meds.map((m) => m.name).join(', ')}';

/// One alarm per minute that has doses, for [days] days from [now]. Doses at the same minute share
/// one alarm, so two medicines at 8:00 ring once and are read out together.
List<ScheduledAlarm> buildAlarms(ElderSchedule s, DateTime now, {int days = 7}) {
  final today = dateOnly(now);
  final last = DateTime(today.year, today.month, today.day + days - 1);
  final byMinute = <DateTime, List<ElderMed>>{};
  final exByMinute = <DateTime, List<ElderExercise>>{};
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
  for (final e in s.exercises) {
    for (final at in e.timesBetween(today, last)) {
      if (!at.isAfter(now)) continue;
      if (doseStatusOf(due: at, now: now, createdAt: e.createdAt) == DoseStatus.notApplicable) continue;
      if (s.exercisesDone.contains(exerciseKey(e.id, at))) continue;
      exByMinute.putIfAbsent(at, () => []).add(e);
    }
  }
  // Medicines and exercises at the same minute share one alarm.
  final minutes = {...byMinute.keys, ...exByMinute.keys}.toList()..sort();
  return [
    for (final at in minutes)
      _alarmFor(s.callName, at, byMinute[at] ?? const [], exByMinute[at] ?? const []),
  ];
}

ScheduledAlarm _alarmFor(String callName, DateTime at, List<ElderMed> meds, List<ElderExercise> exercises) {
  if (meds.isEmpty) {
    return ScheduledAlarm(
      id: alarmIdForMinute(at),
      at: at,
      title: 'Tập thể dục: ${exercises.map((e) => e.title).join(', ')}',
      speech: exerciseSpeechFor(callName, exercises),
    );
  }
  return ScheduledAlarm(
    id: alarmIdForMinute(at),
    at: at,
    title: titleFor(meds),
    speech: speechFor(callName, meds) + (exercises.isEmpty ? '' : exerciseSpeechFor(callName, exercises, afterMeds: true)),
  );
}
