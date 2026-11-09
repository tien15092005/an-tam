import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../caregiver/today_api.dart' show ymd;

const weekdayShort = {1: 'T2', 2: 'T3', 3: 'T4', 4: 'T5', 5: 'T6', 6: 'T7', 7: 'CN'};

/// "Thứ 2, 4, 6" / "Hằng ngày"
String weekdaysLabel(List<int> days) {
  if (days.isEmpty || days.length == 7) return 'Hằng ngày';
  return days.map((d) => weekdayShort[d]).join(', ');
}

class Exercise {
  const Exercise({
    required this.id,
    required this.title,
    required this.time,
    required this.daysOfWeek,
    this.durationMin,
    this.note,
    required this.startDate,
    this.endDate,
  });

  final int id;
  final String title;
  final String time;
  final List<int> daysOfWeek;
  final int? durationMin;
  final String? note;
  final DateTime startDate;
  final DateTime? endDate;

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        id: j['id'] as int,
        title: j['title'] as String,
        time: j['time'] as String,
        daysOfWeek: ((j['daysOfWeek'] as List?) ?? const []).cast<int>(),
        durationMin: j['durationMin'] as int?,
        note: j['note'] as String?,
        startDate: DateTime.parse(j['startDate'] as String),
        endDate: j['endDate'] == null ? null : DateTime.parse(j['endDate'] as String),
      );
}

class ExerciseDraft {
  ExerciseDraft({this.title = '', this.time = '06:30', List<int>? daysOfWeek, this.durationMin, this.note, this.startDate, this.endDate})
      : daysOfWeek = daysOfWeek ?? [];

  factory ExerciseDraft.of(Exercise e) => ExerciseDraft(
        title: e.title,
        time: e.time,
        daysOfWeek: [...e.daysOfWeek],
        durationMin: e.durationMin,
        note: e.note,
        startDate: e.startDate,
        endDate: e.endDate,
      );

  String title;
  String time;
  List<int> daysOfWeek;
  int? durationMin;
  String? note;
  DateTime? startDate;
  DateTime? endDate;

  Map<String, dynamic> toJson() => {
        'title': title.trim(),
        'time': time,
        'daysOfWeek': daysOfWeek.length == 7 ? <int>[] : daysOfWeek,
        'durationMin': durationMin,
        'note': (note == null || note!.trim().isEmpty) ? null : note!.trim(),
        'startDate': startDate == null ? null : ymd(startDate!),
        'endDate': endDate == null ? null : ymd(endDate!),
      };
}

typedef ElderRef = ({int groupId, int elderUserId});

class ExercisesApi {
  ExercisesApi(this._ref);
  final Ref _ref;

  Future<List<Exercise>> list(ElderRef e) async {
    final r = await _ref.read(dioProvider).get<List<dynamic>>('/api/groups/${e.groupId}/elders/${e.elderUserId}/exercises');
    return r.data!.map((j) => Exercise.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> create(ElderRef e, ExerciseDraft d) =>
      _ref.read(dioProvider).post<void>('/api/groups/${e.groupId}/elders/${e.elderUserId}/exercises', data: d.toJson());

  Future<void> update(int groupId, int id, ExerciseDraft d) =>
      _ref.read(dioProvider).put<void>('/api/groups/$groupId/exercises/$id', data: d.toJson());

  Future<void> delete(int groupId, int id) => _ref.read(dioProvider).delete<void>('/api/groups/$groupId/exercises/$id');
}

final exercisesApiProvider = Provider<ExercisesApi>(ExercisesApi.new);

final exercisesProvider =
    FutureProvider.autoDispose.family<List<Exercise>, ElderRef>((ref, e) => ref.watch(exercisesApiProvider).list(e));
