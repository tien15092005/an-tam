import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/tokens.dart';
import '../../reminder/outbox.dart' show newEventId;
import '../care/care_api.dart';

String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// One medicine at one time on the caregiver's timeline (backend CareDtos.DaySlot).
class DaySlot {
  const DaySlot({
    required this.time,
    required this.medicationId,
    required this.name,
    this.dosage,
    this.description,
    this.imageUrl,
    required this.status,
    this.doseLogId,
    this.source,
    this.checkResult,
    this.loggedAt,
    this.loggedByName,
    required this.canMark,
    required this.canUndo,
  });

  final String time;
  final int medicationId;
  final String name;
  final String? dosage;
  final String? description;
  final String? imageUrl;
  final String status;
  final int? doseLogId;
  final String? source;
  final String? checkResult;
  final DateTime? loggedAt;
  final String? loggedByName;
  final bool canMark;
  final bool canUndo;

  factory DaySlot.fromJson(Map<String, dynamic> j) => DaySlot(
        time: j['scheduledTime'] as String,
        medicationId: j['medicationId'] as int,
        name: j['name'] as String,
        dosage: j['dosage'] as String?,
        description: j['description'] as String?,
        imageUrl: j['imageUrl'] as String?,
        status: j['status'] as String,
        doseLogId: j['doseLogId'] as int?,
        source: j['source'] as String?,
        checkResult: j['checkResult'] as String?,
        loggedAt: j['loggedAt'] == null ? null : DateTime.parse(j['loggedAt'] as String).toLocal(),
        loggedByName: j['loggedByName'] as String?,
        canMark: j['canMark'] as bool? ?? false,
        canUndo: j['canUndo'] as bool? ?? false,
      );

  /// Who answered and how, e.g. "Bà Lan bấm nút lúc 08:03" or "Anh Nam đánh dấu giúp lúc 09:10".
  String? get answeredBy {
    if (loggedAt == null) return null;
    final at = hhmmOf(loggedAt!);
    return switch (source) {
      'CAREGIVER' => '${loggedByName ?? 'Người con'} đánh dấu giúp lúc $at',
      'VOICE' => 'Trả lời bằng giọng nói lúc $at',
      _ => 'Bấm nút lúc $at',
    };
  }

  String? get checkText => switch (checkResult) {
        'ISSUE' => 'Có báo vấn đề',
        'NO_RESPONSE' => 'Không trả lời câu hỏi "có vấn đề gì không"',
        _ => null,
      };
}

/// Status shown with an icon, a word and a colour (never colour alone).
(IconData, String, Color, Color) statusStyle(String status) => switch (status) {
      'TAKEN' => (Icons.check_circle, 'Đã uống', AppColors.ok, AppColors.okSoft),
      'NOT_TAKEN' => (Icons.block, 'Không uống được', AppColors.warn, AppColors.warnSoft),
      'SKIPPED' => (Icons.skip_next, 'Bỏ qua', AppColors.muted, AppColors.navySoft),
      'MISSED' => (Icons.error, 'Chưa xác nhận', AppColors.danger, AppColors.dangerSoft),
      'DUE' => (Icons.notifications_active, 'Đang nhắc', AppColors.primary, AppColors.primarySoft),
      _ => (Icons.schedule, 'Sắp tới', AppColors.navy, AppColors.navySoft),
    };

/// An exercise on the caregiver's day view. status: DONE, UPCOMING, DUE or MISSED.
class DayExercise {
  const DayExercise(this.title, this.time, this.durationMin, this.status, this.loggedAt);
  final String title;
  final String time;
  final int? durationMin;
  final String status;
  final DateTime? loggedAt;

  factory DayExercise.fromJson(Map<String, dynamic> j) => DayExercise(
        j['title'] as String,
        j['time'] as String,
        j['durationMin'] as int?,
        j['status'] as String,
        j['loggedAt'] == null ? null : DateTime.parse(j['loggedAt'] as String).toLocal(),
      );

  (IconData, String, Color) get look => switch (status) {
        'DONE' => (Icons.check_circle, 'Đã đi tập', AppColors.ok),
        'MISSED' => (Icons.error_outline, 'Chưa xác nhận', AppColors.warn),
        'DUE' => (Icons.notifications_active, 'Đang nhắc', AppColors.primary),
        _ => (Icons.schedule, 'Sắp tới', AppColors.navy),
      };
}

/// One day cell of the week / month calendar.
class CalendarDay {
  const CalendarDay(this.date, this.total, this.taken, this.notTaken, this.missed, this.due, this.upcoming, this.exercises,
      this.exercisesDone, this.exercisesMissed);
  final DateTime date;
  final int total, taken, notTaken, missed, due, upcoming, exercises, exercisesDone, exercisesMissed;

  factory CalendarDay.fromJson(Map<String, dynamic> j) => CalendarDay(
        DateTime.parse(j['date'] as String),
        j['total'] as int,
        j['taken'] as int,
        j['notTaken'] as int,
        j['missed'] as int,
        j['due'] as int,
        j['upcoming'] as int,
        j['exercises'] as int,
        j['exercisesDone'] as int,
        j['exercisesMissed'] as int,
      );

  /// The dot: red if anything went unconfirmed, orange if not taken, green if all taken, grey for later.
  /// Null when nothing is scheduled.
  (Color, String)? get dot {
    if (total == 0 && exercises == 0) return null;
    if (missed > 0) return (AppColors.danger, 'có $missed lần chưa xác nhận');
    if (notTaken > 0) return (AppColors.warn, 'có $notTaken lần không uống được');
    if (total > 0 && taken == total && exercisesMissed == 0) return (AppColors.ok, 'đã uống đủ $taken lần');
    if (due + upcoming > 0) return (AppColors.navy, '$taken trên $total lần đã uống, còn ${due + upcoming} lần');
    return (AppColors.muted, '$exercisesDone trên $exercises buổi tập');
  }

  String get semantics {
    final d = dot;
    final ex = exercises == 0 ? '' : ', tập $exercisesDone trên $exercises buổi';
    return 'Ngày ${date.day} tháng ${date.month}: ${d == null ? 'không có lịch' : d.$2}$ex';
  }
}

typedef CalendarRange = ({int groupId, int elderUserId, String from, String to});

final calendarProvider = FutureProvider.autoDispose.family<List<CalendarDay>, CalendarRange>((ref, k) async {
  final r = await ref.read(dioProvider).get<List<dynamic>>('/api/groups/${k.groupId}/elders/${k.elderUserId}/calendar',
      queryParameters: {'from': k.from, 'to': k.to});
  return r.data!.map((j) => CalendarDay.fromJson(j as Map<String, dynamic>)).toList();
});

class DayView {
  const DayView({
    required this.date,
    required this.callName,
    this.phone,
    required this.slots,
    required this.counts,
    required this.missedLast7Days,
    required this.openAlerts,
    this.exercises = const [],
  });

  final DateTime date;
  final String callName;
  final String? phone;
  final List<DaySlot> slots;
  final Map<String, int> counts;
  final int missedLast7Days;
  final int openAlerts;
  final List<DayExercise> exercises;

  factory DayView.fromJson(Map<String, dynamic> j) => DayView(
        date: DateTime.parse(j['date'] as String),
        callName: j['callName'] as String? ?? '',
        phone: j['phone'] as String?,
        slots: (j['slots'] as List).map((s) => DaySlot.fromJson(s as Map<String, dynamic>)).toList(),
        counts: (j['counts'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int)),
        missedLast7Days: j['missedLast7Days'] as int? ?? 0,
        openAlerts: j['openAlerts'] as int? ?? 0,
        exercises: ((j['exercises'] as List?) ?? const []).map((e) => DayExercise.fromJson(e as Map<String, dynamic>)).toList(),
      );

  /// Slots grouped by time, in order (one alarm per time).
  Map<String, List<DaySlot>> get byTime {
    final out = <String, List<DaySlot>>{};
    for (final s in slots) {
      out.putIfAbsent(s.time, () => []).add(s);
    }
    return out;
  }
}

final dayViewProvider = FutureProvider.autoDispose.family<DayView, ElderDay>((ref, k) async {
  final r = await ref
      .read(dioProvider)
      .get<Map<String, dynamic>>('/api/groups/${k.groupId}/elders/${k.elderUserId}/day', queryParameters: {'date': k.date});
  return DayView.fromJson(r.data!);
});

class TodayApi {
  TodayApi(this._ref);
  final Ref _ref;

  /// Marks every listed medicine at that time as taken; the elder's phone stops ringing.
  Future<void> mark(ElderDay day, String time, List<int> medicationIds) => _ref.read(dioProvider).post<void>(
        '/api/groups/${day.groupId}/elders/${day.elderUserId}/doses',
        data: {'clientEventId': newEventId(), 'scheduledDate': day.date, 'scheduledTime': time, 'medicationIds': medicationIds},
      );

  Future<void> undo(ElderDay day, int doseLogId) =>
      _ref.read(dioProvider).delete<void>('/api/groups/${day.groupId}/elders/${day.elderUserId}/doses/$doseLogId');
}

final todayApiProvider = Provider<TodayApi>(TodayApi.new);
