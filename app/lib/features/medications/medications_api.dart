import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

enum ImageKind { pill, package }

class MedImage {
  const MedImage({required this.id, required this.kind, required this.url, required this.sha256});
  final int id;
  final ImageKind kind;
  final String url;
  final String sha256;

  factory MedImage.fromJson(Map<String, dynamic> j) => MedImage(
        id: j['id'] as int,
        kind: ImageKind.values.byName((j['kind'] as String).toLowerCase()),
        url: j['url'] as String,
        sha256: j['sha256'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'kind': kind.name.toUpperCase(), 'url': url, 'sha256': sha256};
}

/// One medication as the backend returns it (MedicationDtos.MedicationResponse).
class Medication {
  const Medication({
    required this.id,
    required this.seriesId,
    required this.elderUserId,
    required this.name,
    this.strength,
    this.dosage,
    this.note,
    this.shape,
    this.color,
    this.imprint,
    this.pillDescription,
    required this.times,
    required this.daysOfWeek,
    required this.startDate,
    this.endDate,
    this.images = const [],
    required this.createdAt,
  });

  final int id;
  final String seriesId;
  final int elderUserId;
  final String name;
  final String? strength;
  final String? dosage;
  final String? note;
  final String? shape;
  final String? color;
  final String? imprint;
  final String? pillDescription;
  final List<String> times;
  final List<int> daysOfWeek;
  final DateTime startDate;
  final DateTime? endDate;
  final List<MedImage> images;
  final DateTime createdAt;

  bool get everyDay => daysOfWeek.length == 7 || daysOfWeek.isEmpty;

  /// "Viên tròn, màu trắng, có vạch ngang" from the structured fields when no free text was given.
  String get description {
    if (pillDescription != null && pillDescription!.isNotEmpty) return pillDescription!;
    return [
      if (shape != null) 'viên $shape',
      if (color != null) 'màu $color',
      if (imprint != null) 'khắc chữ $imprint',
    ].join(', ');
  }

  String get title => strength == null ? name : '$name $strength';

  static DateTime _date(String s) => DateTime.parse(s);

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        id: j['id'] as int,
        seriesId: j['seriesId'] as String,
        elderUserId: j['elderUserId'] as int,
        name: j['name'] as String,
        strength: j['strength'] as String?,
        dosage: j['dosage'] as String?,
        note: j['note'] as String?,
        shape: j['shape'] as String?,
        color: j['color'] as String?,
        imprint: j['imprint'] as String?,
        pillDescription: j['pillDescription'] as String?,
        times: (j['times'] as List).cast<String>(),
        daysOfWeek: (j['daysOfWeek'] as List).cast<int>(),
        startDate: _date(j['startDate'] as String),
        endDate: j['endDate'] == null ? null : _date(j['endDate'] as String),
        images: (j['images'] as List? ?? const []).map((i) => MedImage.fromJson(i as Map<String, dynamic>)).toList(),
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      );
}

/// What the owner fills in on the form; sent as-is to POST / PUT.
class MedicationDraft {
  MedicationDraft({
    this.name = '',
    this.strength,
    this.dosage,
    this.note,
    this.shape,
    this.color,
    this.imprint,
    this.pillDescription,
    List<String>? times,
    List<int>? daysOfWeek,
    this.startDate,
    this.endDate,
  })  : times = times ?? [],
        daysOfWeek = daysOfWeek ?? [];

  factory MedicationDraft.of(Medication m) => MedicationDraft(
        name: m.name,
        strength: m.strength,
        dosage: m.dosage,
        note: m.note,
        shape: m.shape,
        color: m.color,
        imprint: m.imprint,
        pillDescription: m.pillDescription,
        times: [...m.times],
        daysOfWeek: m.everyDay ? [] : [...m.daysOfWeek],
        startDate: m.startDate,
        endDate: m.endDate,
      );

  String name;
  String? strength, dosage, note, shape, color, imprint, pillDescription;
  List<String> times;
  List<int> daysOfWeek;
  DateTime? startDate;
  DateTime? endDate;

  static String? _d(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'name': name,
        'strength': strength,
        'dosage': dosage,
        'note': note,
        'shape': shape,
        'color': color,
        'imprint': imprint,
        'pillDescription': pillDescription,
        'times': times,
        'daysOfWeek': daysOfWeek,
        'startDate': _d(startDate),
        'endDate': _d(endDate),
        'source': 'MANUAL',
      };
}

class MedicationsApi {
  MedicationsApi(this._ref);
  final Ref _ref;

  Dio get _dio => _ref.read(dioProvider);

  Future<List<Medication>> list(int groupId, int elderUserId) async {
    final r = await _dio.get<List<dynamic>>('/api/groups/$groupId/elders/$elderUserId/medications');
    return r.data!.map((j) => Medication.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Medication> create(int groupId, int elderUserId, MedicationDraft d) async => Medication.fromJson(
      (await _dio.post<Map<String, dynamic>>('/api/groups/$groupId/elders/$elderUserId/medications', data: d.toJson()))
          .data!);

  Future<Medication> update(int groupId, int medicationId, MedicationDraft d) async => Medication.fromJson(
      (await _dio.put<Map<String, dynamic>>('/api/groups/$groupId/medications/$medicationId', data: d.toJson())).data!);

  Future<void> delete(int groupId, int medicationId) => _dio.delete<void>('/api/groups/$groupId/medications/$medicationId');

  Future<MedImage> addImage(int groupId, int medicationId, ImageKind kind, Uint8List bytes, String filename) async {
    final form = FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: filename)});
    final r = await _dio.post<Map<String, dynamic>>('/api/groups/$groupId/medications/$medicationId/images',
        data: form, queryParameters: {'kind': kind.name.toUpperCase()});
    return MedImage.fromJson(r.data!);
  }

  Future<void> deleteImage(int groupId, int medicationId, int imageId) =>
      _dio.delete<void>('/api/groups/$groupId/medications/$medicationId/images/$imageId');

  /// Photo bytes through the signed-in client (so an expired token is refreshed, unlike Image.network).
  Future<Uint8List> imageBytes(String url) async =>
      Uint8List.fromList((await _dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes))).data!);
}

final medicationsApiProvider = Provider<MedicationsApi>(MedicationsApi.new);

typedef ElderKey = ({int groupId, int elderUserId});

final medicationsProvider = FutureProvider.autoDispose.family<List<Medication>, ElderKey>(
    (ref, k) => ref.watch(medicationsApiProvider).list(k.groupId, k.elderUserId));

/// Photos never change once uploaded (a new upload gets a new id), so keep them for the session.
final medicationImageProvider =
    FutureProvider.family<Uint8List, String>((ref, url) => ref.watch(medicationsApiProvider).imageBytes(url));
