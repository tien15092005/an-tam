// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_db.dart';

// ignore_for_file: type=lint
class $CachedMedicationsTable extends CachedMedications
    with TableInfo<$CachedMedicationsTable, CachedMedication> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedMedicationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
    'series_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _strengthMeta = const VerificationMeta(
    'strength',
  );
  @override
  late final GeneratedColumn<String> strength = GeneratedColumn<String>(
    'strength',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dosageMeta = const VerificationMeta('dosage');
  @override
  late final GeneratedColumn<String> dosage = GeneratedColumn<String>(
    'dosage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timesMeta = const VerificationMeta('times');
  @override
  late final GeneratedColumn<String> times = GeneratedColumn<String>(
    'times',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _daysMaskMeta = const VerificationMeta(
    'daysMask',
  );
  @override
  late final GeneratedColumn<int> daysMask = GeneratedColumn<int>(
    'days_mask',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    seriesId,
    name,
    strength,
    dosage,
    description,
    note,
    times,
    daysMask,
    startDate,
    endDate,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_medications';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedMedication> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('strength')) {
      context.handle(
        _strengthMeta,
        strength.isAcceptableOrUnknown(data['strength']!, _strengthMeta),
      );
    }
    if (data.containsKey('dosage')) {
      context.handle(
        _dosageMeta,
        dosage.isAcceptableOrUnknown(data['dosage']!, _dosageMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('times')) {
      context.handle(
        _timesMeta,
        times.isAcceptableOrUnknown(data['times']!, _timesMeta),
      );
    } else if (isInserting) {
      context.missing(_timesMeta);
    }
    if (data.containsKey('days_mask')) {
      context.handle(
        _daysMaskMeta,
        daysMask.isAcceptableOrUnknown(data['days_mask']!, _daysMaskMeta),
      );
    } else if (isInserting) {
      context.missing(_daysMaskMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedMedication map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedMedication(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      strength: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}strength'],
      ),
      dosage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dosage'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      times: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}times'],
      )!,
      daysMask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}days_mask'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CachedMedicationsTable createAlias(String alias) {
    return $CachedMedicationsTable(attachedDatabase, alias);
  }
}

class CachedMedication extends DataClass
    implements Insertable<CachedMedication> {
  final int id;
  final String seriesId;
  final String name;
  final String? strength;
  final String? dosage;
  final String description;
  final String? note;

  /// "07:30,20:00"
  final String times;
  final int daysMask;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  const CachedMedication({
    required this.id,
    required this.seriesId,
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
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['series_id'] = Variable<String>(seriesId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || strength != null) {
      map['strength'] = Variable<String>(strength);
    }
    if (!nullToAbsent || dosage != null) {
      map['dosage'] = Variable<String>(dosage);
    }
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['times'] = Variable<String>(times);
    map['days_mask'] = Variable<int>(daysMask);
    map['start_date'] = Variable<DateTime>(startDate);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CachedMedicationsCompanion toCompanion(bool nullToAbsent) {
    return CachedMedicationsCompanion(
      id: Value(id),
      seriesId: Value(seriesId),
      name: Value(name),
      strength: strength == null && nullToAbsent
          ? const Value.absent()
          : Value(strength),
      dosage: dosage == null && nullToAbsent
          ? const Value.absent()
          : Value(dosage),
      description: Value(description),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      times: Value(times),
      daysMask: Value(daysMask),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      createdAt: Value(createdAt),
    );
  }

  factory CachedMedication.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedMedication(
      id: serializer.fromJson<int>(json['id']),
      seriesId: serializer.fromJson<String>(json['seriesId']),
      name: serializer.fromJson<String>(json['name']),
      strength: serializer.fromJson<String?>(json['strength']),
      dosage: serializer.fromJson<String?>(json['dosage']),
      description: serializer.fromJson<String>(json['description']),
      note: serializer.fromJson<String?>(json['note']),
      times: serializer.fromJson<String>(json['times']),
      daysMask: serializer.fromJson<int>(json['daysMask']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'seriesId': serializer.toJson<String>(seriesId),
      'name': serializer.toJson<String>(name),
      'strength': serializer.toJson<String?>(strength),
      'dosage': serializer.toJson<String?>(dosage),
      'description': serializer.toJson<String>(description),
      'note': serializer.toJson<String?>(note),
      'times': serializer.toJson<String>(times),
      'daysMask': serializer.toJson<int>(daysMask),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CachedMedication copyWith({
    int? id,
    String? seriesId,
    String? name,
    Value<String?> strength = const Value.absent(),
    Value<String?> dosage = const Value.absent(),
    String? description,
    Value<String?> note = const Value.absent(),
    String? times,
    int? daysMask,
    DateTime? startDate,
    Value<DateTime?> endDate = const Value.absent(),
    DateTime? createdAt,
  }) => CachedMedication(
    id: id ?? this.id,
    seriesId: seriesId ?? this.seriesId,
    name: name ?? this.name,
    strength: strength.present ? strength.value : this.strength,
    dosage: dosage.present ? dosage.value : this.dosage,
    description: description ?? this.description,
    note: note.present ? note.value : this.note,
    times: times ?? this.times,
    daysMask: daysMask ?? this.daysMask,
    startDate: startDate ?? this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    createdAt: createdAt ?? this.createdAt,
  );
  CachedMedication copyWithCompanion(CachedMedicationsCompanion data) {
    return CachedMedication(
      id: data.id.present ? data.id.value : this.id,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      name: data.name.present ? data.name.value : this.name,
      strength: data.strength.present ? data.strength.value : this.strength,
      dosage: data.dosage.present ? data.dosage.value : this.dosage,
      description: data.description.present
          ? data.description.value
          : this.description,
      note: data.note.present ? data.note.value : this.note,
      times: data.times.present ? data.times.value : this.times,
      daysMask: data.daysMask.present ? data.daysMask.value : this.daysMask,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedMedication(')
          ..write('id: $id, ')
          ..write('seriesId: $seriesId, ')
          ..write('name: $name, ')
          ..write('strength: $strength, ')
          ..write('dosage: $dosage, ')
          ..write('description: $description, ')
          ..write('note: $note, ')
          ..write('times: $times, ')
          ..write('daysMask: $daysMask, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    seriesId,
    name,
    strength,
    dosage,
    description,
    note,
    times,
    daysMask,
    startDate,
    endDate,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedMedication &&
          other.id == this.id &&
          other.seriesId == this.seriesId &&
          other.name == this.name &&
          other.strength == this.strength &&
          other.dosage == this.dosage &&
          other.description == this.description &&
          other.note == this.note &&
          other.times == this.times &&
          other.daysMask == this.daysMask &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.createdAt == this.createdAt);
}

class CachedMedicationsCompanion extends UpdateCompanion<CachedMedication> {
  final Value<int> id;
  final Value<String> seriesId;
  final Value<String> name;
  final Value<String?> strength;
  final Value<String?> dosage;
  final Value<String> description;
  final Value<String?> note;
  final Value<String> times;
  final Value<int> daysMask;
  final Value<DateTime> startDate;
  final Value<DateTime?> endDate;
  final Value<DateTime> createdAt;
  const CachedMedicationsCompanion({
    this.id = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.name = const Value.absent(),
    this.strength = const Value.absent(),
    this.dosage = const Value.absent(),
    this.description = const Value.absent(),
    this.note = const Value.absent(),
    this.times = const Value.absent(),
    this.daysMask = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CachedMedicationsCompanion.insert({
    this.id = const Value.absent(),
    required String seriesId,
    required String name,
    this.strength = const Value.absent(),
    this.dosage = const Value.absent(),
    required String description,
    this.note = const Value.absent(),
    required String times,
    required int daysMask,
    required DateTime startDate,
    this.endDate = const Value.absent(),
    required DateTime createdAt,
  }) : seriesId = Value(seriesId),
       name = Value(name),
       description = Value(description),
       times = Value(times),
       daysMask = Value(daysMask),
       startDate = Value(startDate),
       createdAt = Value(createdAt);
  static Insertable<CachedMedication> custom({
    Expression<int>? id,
    Expression<String>? seriesId,
    Expression<String>? name,
    Expression<String>? strength,
    Expression<String>? dosage,
    Expression<String>? description,
    Expression<String>? note,
    Expression<String>? times,
    Expression<int>? daysMask,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (seriesId != null) 'series_id': seriesId,
      if (name != null) 'name': name,
      if (strength != null) 'strength': strength,
      if (dosage != null) 'dosage': dosage,
      if (description != null) 'description': description,
      if (note != null) 'note': note,
      if (times != null) 'times': times,
      if (daysMask != null) 'days_mask': daysMask,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CachedMedicationsCompanion copyWith({
    Value<int>? id,
    Value<String>? seriesId,
    Value<String>? name,
    Value<String?>? strength,
    Value<String?>? dosage,
    Value<String>? description,
    Value<String?>? note,
    Value<String>? times,
    Value<int>? daysMask,
    Value<DateTime>? startDate,
    Value<DateTime?>? endDate,
    Value<DateTime>? createdAt,
  }) {
    return CachedMedicationsCompanion(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      name: name ?? this.name,
      strength: strength ?? this.strength,
      dosage: dosage ?? this.dosage,
      description: description ?? this.description,
      note: note ?? this.note,
      times: times ?? this.times,
      daysMask: daysMask ?? this.daysMask,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (strength.present) {
      map['strength'] = Variable<String>(strength.value);
    }
    if (dosage.present) {
      map['dosage'] = Variable<String>(dosage.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (times.present) {
      map['times'] = Variable<String>(times.value);
    }
    if (daysMask.present) {
      map['days_mask'] = Variable<int>(daysMask.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedMedicationsCompanion(')
          ..write('id: $id, ')
          ..write('seriesId: $seriesId, ')
          ..write('name: $name, ')
          ..write('strength: $strength, ')
          ..write('dosage: $dosage, ')
          ..write('description: $description, ')
          ..write('note: $note, ')
          ..write('times: $times, ')
          ..write('daysMask: $daysMask, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CachedImagesTable extends CachedImages
    with TableInfo<$CachedImagesTable, CachedImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _medicationIdMeta = const VerificationMeta(
    'medicationId',
  );
  @override
  late final GeneratedColumn<int> medicationId = GeneratedColumn<int>(
    'medication_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, medicationId, kind, path, sha256];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedImage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('medication_id')) {
      context.handle(
        _medicationIdMeta,
        medicationId.isAcceptableOrUnknown(
          data['medication_id']!,
          _medicationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_medicationIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedImage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      medicationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}medication_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
    );
  }

  @override
  $CachedImagesTable createAlias(String alias) {
    return $CachedImagesTable(attachedDatabase, alias);
  }
}

class CachedImage extends DataClass implements Insertable<CachedImage> {
  final int id;
  final int medicationId;
  final String kind;
  final String path;
  final String sha256;
  const CachedImage({
    required this.id,
    required this.medicationId,
    required this.kind,
    required this.path,
    required this.sha256,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['medication_id'] = Variable<int>(medicationId);
    map['kind'] = Variable<String>(kind);
    map['path'] = Variable<String>(path);
    map['sha256'] = Variable<String>(sha256);
    return map;
  }

  CachedImagesCompanion toCompanion(bool nullToAbsent) {
    return CachedImagesCompanion(
      id: Value(id),
      medicationId: Value(medicationId),
      kind: Value(kind),
      path: Value(path),
      sha256: Value(sha256),
    );
  }

  factory CachedImage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedImage(
      id: serializer.fromJson<int>(json['id']),
      medicationId: serializer.fromJson<int>(json['medicationId']),
      kind: serializer.fromJson<String>(json['kind']),
      path: serializer.fromJson<String>(json['path']),
      sha256: serializer.fromJson<String>(json['sha256']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'medicationId': serializer.toJson<int>(medicationId),
      'kind': serializer.toJson<String>(kind),
      'path': serializer.toJson<String>(path),
      'sha256': serializer.toJson<String>(sha256),
    };
  }

  CachedImage copyWith({
    int? id,
    int? medicationId,
    String? kind,
    String? path,
    String? sha256,
  }) => CachedImage(
    id: id ?? this.id,
    medicationId: medicationId ?? this.medicationId,
    kind: kind ?? this.kind,
    path: path ?? this.path,
    sha256: sha256 ?? this.sha256,
  );
  CachedImage copyWithCompanion(CachedImagesCompanion data) {
    return CachedImage(
      id: data.id.present ? data.id.value : this.id,
      medicationId: data.medicationId.present
          ? data.medicationId.value
          : this.medicationId,
      kind: data.kind.present ? data.kind.value : this.kind,
      path: data.path.present ? data.path.value : this.path,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedImage(')
          ..write('id: $id, ')
          ..write('medicationId: $medicationId, ')
          ..write('kind: $kind, ')
          ..write('path: $path, ')
          ..write('sha256: $sha256')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, medicationId, kind, path, sha256);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedImage &&
          other.id == this.id &&
          other.medicationId == this.medicationId &&
          other.kind == this.kind &&
          other.path == this.path &&
          other.sha256 == this.sha256);
}

class CachedImagesCompanion extends UpdateCompanion<CachedImage> {
  final Value<int> id;
  final Value<int> medicationId;
  final Value<String> kind;
  final Value<String> path;
  final Value<String> sha256;
  const CachedImagesCompanion({
    this.id = const Value.absent(),
    this.medicationId = const Value.absent(),
    this.kind = const Value.absent(),
    this.path = const Value.absent(),
    this.sha256 = const Value.absent(),
  });
  CachedImagesCompanion.insert({
    this.id = const Value.absent(),
    required int medicationId,
    required String kind,
    required String path,
    required String sha256,
  }) : medicationId = Value(medicationId),
       kind = Value(kind),
       path = Value(path),
       sha256 = Value(sha256);
  static Insertable<CachedImage> custom({
    Expression<int>? id,
    Expression<int>? medicationId,
    Expression<String>? kind,
    Expression<String>? path,
    Expression<String>? sha256,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (medicationId != null) 'medication_id': medicationId,
      if (kind != null) 'kind': kind,
      if (path != null) 'path': path,
      if (sha256 != null) 'sha256': sha256,
    });
  }

  CachedImagesCompanion copyWith({
    Value<int>? id,
    Value<int>? medicationId,
    Value<String>? kind,
    Value<String>? path,
    Value<String>? sha256,
  }) {
    return CachedImagesCompanion(
      id: id ?? this.id,
      medicationId: medicationId ?? this.medicationId,
      kind: kind ?? this.kind,
      path: path ?? this.path,
      sha256: sha256 ?? this.sha256,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (medicationId.present) {
      map['medication_id'] = Variable<int>(medicationId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedImagesCompanion(')
          ..write('id: $id, ')
          ..write('medicationId: $medicationId, ')
          ..write('kind: $kind, ')
          ..write('path: $path, ')
          ..write('sha256: $sha256')
          ..write(')'))
        .toString();
  }
}

class $SyncMetaTable extends SyncMeta
    with TableInfo<$SyncMetaTable, SyncMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetaData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncMetaTable createAlias(String alias) {
    return $SyncMetaTable(attachedDatabase, alias);
  }
}

class SyncMetaData extends DataClass implements Insertable<SyncMetaData> {
  final String key;
  final String value;
  const SyncMetaData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(key: Value(key), value: Value(value));
  }

  factory SyncMetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetaData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncMetaData copyWith({String? key, String? value}) =>
      SyncMetaData(key: key ?? this.key, value: value ?? this.value);
  SyncMetaData copyWithCompanion(SyncMetaCompanion data) {
    return SyncMetaData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetaData &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncMetaCompanion extends UpdateCompanion<SyncMetaData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncMetaData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingEventsTable extends PendingEvents
    with TableInfo<$PendingEventsTable, PendingEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clientEventIdMeta = const VerificationMeta(
    'clientEventId',
  );
  @override
  late final GeneratedColumn<String> clientEventId = GeneratedColumn<String>(
    'client_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readyMeta = const VerificationMeta('ready');
  @override
  late final GeneratedColumn<bool> ready = GeneratedColumn<bool>(
    'ready',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("ready" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientEventId,
    path,
    body,
    createdAt,
    ready,
    attempts,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_event_id')) {
      context.handle(
        _clientEventIdMeta,
        clientEventId.isAcceptableOrUnknown(
          data['client_event_id']!,
          _clientEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientEventIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('ready')) {
      context.handle(
        _readyMeta,
        ready.isAcceptableOrUnknown(data['ready']!, _readyMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_event_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      ready: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ready'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
    );
  }

  @override
  $PendingEventsTable createAlias(String alias) {
    return $PendingEventsTable(attachedDatabase, alias);
  }
}

class PendingEvent extends DataClass implements Insertable<PendingEvent> {
  final int id;
  final String clientEventId;

  /// API path, e.g. /api/me/dose-reports
  final String path;
  final String body;
  final DateTime createdAt;

  /// False while the "any problem?" question is still open; only ready events are sent.
  final bool ready;
  final int attempts;
  const PendingEvent({
    required this.id,
    required this.clientEventId,
    required this.path,
    required this.body,
    required this.createdAt,
    required this.ready,
    required this.attempts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_event_id'] = Variable<String>(clientEventId);
    map['path'] = Variable<String>(path);
    map['body'] = Variable<String>(body);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['ready'] = Variable<bool>(ready);
    map['attempts'] = Variable<int>(attempts);
    return map;
  }

  PendingEventsCompanion toCompanion(bool nullToAbsent) {
    return PendingEventsCompanion(
      id: Value(id),
      clientEventId: Value(clientEventId),
      path: Value(path),
      body: Value(body),
      createdAt: Value(createdAt),
      ready: Value(ready),
      attempts: Value(attempts),
    );
  }

  factory PendingEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingEvent(
      id: serializer.fromJson<int>(json['id']),
      clientEventId: serializer.fromJson<String>(json['clientEventId']),
      path: serializer.fromJson<String>(json['path']),
      body: serializer.fromJson<String>(json['body']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      ready: serializer.fromJson<bool>(json['ready']),
      attempts: serializer.fromJson<int>(json['attempts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientEventId': serializer.toJson<String>(clientEventId),
      'path': serializer.toJson<String>(path),
      'body': serializer.toJson<String>(body),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'ready': serializer.toJson<bool>(ready),
      'attempts': serializer.toJson<int>(attempts),
    };
  }

  PendingEvent copyWith({
    int? id,
    String? clientEventId,
    String? path,
    String? body,
    DateTime? createdAt,
    bool? ready,
    int? attempts,
  }) => PendingEvent(
    id: id ?? this.id,
    clientEventId: clientEventId ?? this.clientEventId,
    path: path ?? this.path,
    body: body ?? this.body,
    createdAt: createdAt ?? this.createdAt,
    ready: ready ?? this.ready,
    attempts: attempts ?? this.attempts,
  );
  PendingEvent copyWithCompanion(PendingEventsCompanion data) {
    return PendingEvent(
      id: data.id.present ? data.id.value : this.id,
      clientEventId: data.clientEventId.present
          ? data.clientEventId.value
          : this.clientEventId,
      path: data.path.present ? data.path.value : this.path,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      ready: data.ready.present ? data.ready.value : this.ready,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingEvent(')
          ..write('id: $id, ')
          ..write('clientEventId: $clientEventId, ')
          ..write('path: $path, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('ready: $ready, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, clientEventId, path, body, createdAt, ready, attempts);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingEvent &&
          other.id == this.id &&
          other.clientEventId == this.clientEventId &&
          other.path == this.path &&
          other.body == this.body &&
          other.createdAt == this.createdAt &&
          other.ready == this.ready &&
          other.attempts == this.attempts);
}

class PendingEventsCompanion extends UpdateCompanion<PendingEvent> {
  final Value<int> id;
  final Value<String> clientEventId;
  final Value<String> path;
  final Value<String> body;
  final Value<DateTime> createdAt;
  final Value<bool> ready;
  final Value<int> attempts;
  const PendingEventsCompanion({
    this.id = const Value.absent(),
    this.clientEventId = const Value.absent(),
    this.path = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.ready = const Value.absent(),
    this.attempts = const Value.absent(),
  });
  PendingEventsCompanion.insert({
    this.id = const Value.absent(),
    required String clientEventId,
    required String path,
    required String body,
    required DateTime createdAt,
    this.ready = const Value.absent(),
    this.attempts = const Value.absent(),
  }) : clientEventId = Value(clientEventId),
       path = Value(path),
       body = Value(body),
       createdAt = Value(createdAt);
  static Insertable<PendingEvent> custom({
    Expression<int>? id,
    Expression<String>? clientEventId,
    Expression<String>? path,
    Expression<String>? body,
    Expression<DateTime>? createdAt,
    Expression<bool>? ready,
    Expression<int>? attempts,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientEventId != null) 'client_event_id': clientEventId,
      if (path != null) 'path': path,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
      if (ready != null) 'ready': ready,
      if (attempts != null) 'attempts': attempts,
    });
  }

  PendingEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? clientEventId,
    Value<String>? path,
    Value<String>? body,
    Value<DateTime>? createdAt,
    Value<bool>? ready,
    Value<int>? attempts,
  }) {
    return PendingEventsCompanion(
      id: id ?? this.id,
      clientEventId: clientEventId ?? this.clientEventId,
      path: path ?? this.path,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      ready: ready ?? this.ready,
      attempts: attempts ?? this.attempts,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientEventId.present) {
      map['client_event_id'] = Variable<String>(clientEventId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (ready.present) {
      map['ready'] = Variable<bool>(ready.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingEventsCompanion(')
          ..write('id: $id, ')
          ..write('clientEventId: $clientEventId, ')
          ..write('path: $path, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('ready: $ready, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }
}

class $LocalDoseLogsTable extends LocalDoseLogs
    with TableInfo<$LocalDoseLogsTable, LocalDoseLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalDoseLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _medicationIdMeta = const VerificationMeta(
    'medicationId',
  );
  @override
  late final GeneratedColumn<int> medicationId = GeneratedColumn<int>(
    'medication_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledAtMeta = const VerificationMeta(
    'scheduledAt',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledAt = GeneratedColumn<DateTime>(
    'scheduled_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [medicationId, scheduledAt, status];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_dose_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalDoseLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('medication_id')) {
      context.handle(
        _medicationIdMeta,
        medicationId.isAcceptableOrUnknown(
          data['medication_id']!,
          _medicationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_medicationIdMeta);
    }
    if (data.containsKey('scheduled_at')) {
      context.handle(
        _scheduledAtMeta,
        scheduledAt.isAcceptableOrUnknown(
          data['scheduled_at']!,
          _scheduledAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {medicationId, scheduledAt};
  @override
  LocalDoseLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalDoseLog(
      medicationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}medication_id'],
      )!,
      scheduledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $LocalDoseLogsTable createAlias(String alias) {
    return $LocalDoseLogsTable(attachedDatabase, alias);
  }
}

class LocalDoseLog extends DataClass implements Insertable<LocalDoseLog> {
  final int medicationId;

  /// The scheduled local minute.
  final DateTime scheduledAt;

  /// TAKEN | NOT_TAKEN | SKIPPED
  final String status;
  const LocalDoseLog({
    required this.medicationId,
    required this.scheduledAt,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['medication_id'] = Variable<int>(medicationId);
    map['scheduled_at'] = Variable<DateTime>(scheduledAt);
    map['status'] = Variable<String>(status);
    return map;
  }

  LocalDoseLogsCompanion toCompanion(bool nullToAbsent) {
    return LocalDoseLogsCompanion(
      medicationId: Value(medicationId),
      scheduledAt: Value(scheduledAt),
      status: Value(status),
    );
  }

  factory LocalDoseLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalDoseLog(
      medicationId: serializer.fromJson<int>(json['medicationId']),
      scheduledAt: serializer.fromJson<DateTime>(json['scheduledAt']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'medicationId': serializer.toJson<int>(medicationId),
      'scheduledAt': serializer.toJson<DateTime>(scheduledAt),
      'status': serializer.toJson<String>(status),
    };
  }

  LocalDoseLog copyWith({
    int? medicationId,
    DateTime? scheduledAt,
    String? status,
  }) => LocalDoseLog(
    medicationId: medicationId ?? this.medicationId,
    scheduledAt: scheduledAt ?? this.scheduledAt,
    status: status ?? this.status,
  );
  LocalDoseLog copyWithCompanion(LocalDoseLogsCompanion data) {
    return LocalDoseLog(
      medicationId: data.medicationId.present
          ? data.medicationId.value
          : this.medicationId,
      scheduledAt: data.scheduledAt.present
          ? data.scheduledAt.value
          : this.scheduledAt,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalDoseLog(')
          ..write('medicationId: $medicationId, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(medicationId, scheduledAt, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalDoseLog &&
          other.medicationId == this.medicationId &&
          other.scheduledAt == this.scheduledAt &&
          other.status == this.status);
}

class LocalDoseLogsCompanion extends UpdateCompanion<LocalDoseLog> {
  final Value<int> medicationId;
  final Value<DateTime> scheduledAt;
  final Value<String> status;
  final Value<int> rowid;
  const LocalDoseLogsCompanion({
    this.medicationId = const Value.absent(),
    this.scheduledAt = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalDoseLogsCompanion.insert({
    required int medicationId,
    required DateTime scheduledAt,
    required String status,
    this.rowid = const Value.absent(),
  }) : medicationId = Value(medicationId),
       scheduledAt = Value(scheduledAt),
       status = Value(status);
  static Insertable<LocalDoseLog> custom({
    Expression<int>? medicationId,
    Expression<DateTime>? scheduledAt,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (medicationId != null) 'medication_id': medicationId,
      if (scheduledAt != null) 'scheduled_at': scheduledAt,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalDoseLogsCompanion copyWith({
    Value<int>? medicationId,
    Value<DateTime>? scheduledAt,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return LocalDoseLogsCompanion(
      medicationId: medicationId ?? this.medicationId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (medicationId.present) {
      map['medication_id'] = Variable<int>(medicationId.value);
    }
    if (scheduledAt.present) {
      map['scheduled_at'] = Variable<DateTime>(scheduledAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalDoseLogsCompanion(')
          ..write('medicationId: $medicationId, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ScheduleDb extends GeneratedDatabase {
  _$ScheduleDb(QueryExecutor e) : super(e);
  $ScheduleDbManager get managers => $ScheduleDbManager(this);
  late final $CachedMedicationsTable cachedMedications =
      $CachedMedicationsTable(this);
  late final $CachedImagesTable cachedImages = $CachedImagesTable(this);
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
  late final $PendingEventsTable pendingEvents = $PendingEventsTable(this);
  late final $LocalDoseLogsTable localDoseLogs = $LocalDoseLogsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedMedications,
    cachedImages,
    syncMeta,
    pendingEvents,
    localDoseLogs,
  ];
}

typedef $$CachedMedicationsTableCreateCompanionBuilder =
    CachedMedicationsCompanion Function({
      Value<int> id,
      required String seriesId,
      required String name,
      Value<String?> strength,
      Value<String?> dosage,
      required String description,
      Value<String?> note,
      required String times,
      required int daysMask,
      required DateTime startDate,
      Value<DateTime?> endDate,
      required DateTime createdAt,
    });
typedef $$CachedMedicationsTableUpdateCompanionBuilder =
    CachedMedicationsCompanion Function({
      Value<int> id,
      Value<String> seriesId,
      Value<String> name,
      Value<String?> strength,
      Value<String?> dosage,
      Value<String> description,
      Value<String?> note,
      Value<String> times,
      Value<int> daysMask,
      Value<DateTime> startDate,
      Value<DateTime?> endDate,
      Value<DateTime> createdAt,
    });

class $$CachedMedicationsTableFilterComposer
    extends Composer<_$ScheduleDb, $CachedMedicationsTable> {
  $$CachedMedicationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get strength => $composableBuilder(
    column: $table.strength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dosage => $composableBuilder(
    column: $table.dosage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get times => $composableBuilder(
    column: $table.times,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get daysMask => $composableBuilder(
    column: $table.daysMask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedMedicationsTableOrderingComposer
    extends Composer<_$ScheduleDb, $CachedMedicationsTable> {
  $$CachedMedicationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get strength => $composableBuilder(
    column: $table.strength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dosage => $composableBuilder(
    column: $table.dosage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get times => $composableBuilder(
    column: $table.times,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get daysMask => $composableBuilder(
    column: $table.daysMask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedMedicationsTableAnnotationComposer
    extends Composer<_$ScheduleDb, $CachedMedicationsTable> {
  $$CachedMedicationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get seriesId =>
      $composableBuilder(column: $table.seriesId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get strength =>
      $composableBuilder(column: $table.strength, builder: (column) => column);

  GeneratedColumn<String> get dosage =>
      $composableBuilder(column: $table.dosage, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get times =>
      $composableBuilder(column: $table.times, builder: (column) => column);

  GeneratedColumn<int> get daysMask =>
      $composableBuilder(column: $table.daysMask, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CachedMedicationsTableTableManager
    extends
        RootTableManager<
          _$ScheduleDb,
          $CachedMedicationsTable,
          CachedMedication,
          $$CachedMedicationsTableFilterComposer,
          $$CachedMedicationsTableOrderingComposer,
          $$CachedMedicationsTableAnnotationComposer,
          $$CachedMedicationsTableCreateCompanionBuilder,
          $$CachedMedicationsTableUpdateCompanionBuilder,
          (
            CachedMedication,
            BaseReferences<
              _$ScheduleDb,
              $CachedMedicationsTable,
              CachedMedication
            >,
          ),
          CachedMedication,
          PrefetchHooks Function()
        > {
  $$CachedMedicationsTableTableManager(
    _$ScheduleDb db,
    $CachedMedicationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedMedicationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedMedicationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedMedicationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> seriesId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> strength = const Value.absent(),
                Value<String?> dosage = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> times = const Value.absent(),
                Value<int> daysMask = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CachedMedicationsCompanion(
                id: id,
                seriesId: seriesId,
                name: name,
                strength: strength,
                dosage: dosage,
                description: description,
                note: note,
                times: times,
                daysMask: daysMask,
                startDate: startDate,
                endDate: endDate,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String seriesId,
                required String name,
                Value<String?> strength = const Value.absent(),
                Value<String?> dosage = const Value.absent(),
                required String description,
                Value<String?> note = const Value.absent(),
                required String times,
                required int daysMask,
                required DateTime startDate,
                Value<DateTime?> endDate = const Value.absent(),
                required DateTime createdAt,
              }) => CachedMedicationsCompanion.insert(
                id: id,
                seriesId: seriesId,
                name: name,
                strength: strength,
                dosage: dosage,
                description: description,
                note: note,
                times: times,
                daysMask: daysMask,
                startDate: startDate,
                endDate: endDate,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedMedicationsTable, CachedMedication>(table),
                  BaseReferences<
                    _$ScheduleDb,
                    $CachedMedicationsTable,
                    CachedMedication
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedMedicationsTableProcessedTableManager =
    ProcessedTableManager<
      _$ScheduleDb,
      $CachedMedicationsTable,
      CachedMedication,
      $$CachedMedicationsTableFilterComposer,
      $$CachedMedicationsTableOrderingComposer,
      $$CachedMedicationsTableAnnotationComposer,
      $$CachedMedicationsTableCreateCompanionBuilder,
      $$CachedMedicationsTableUpdateCompanionBuilder,
      (
        CachedMedication,
        BaseReferences<_$ScheduleDb, $CachedMedicationsTable, CachedMedication>,
      ),
      CachedMedication,
      PrefetchHooks Function()
    >;
typedef $$CachedImagesTableCreateCompanionBuilder =
    CachedImagesCompanion Function({
      Value<int> id,
      required int medicationId,
      required String kind,
      required String path,
      required String sha256,
    });
typedef $$CachedImagesTableUpdateCompanionBuilder =
    CachedImagesCompanion Function({
      Value<int> id,
      Value<int> medicationId,
      Value<String> kind,
      Value<String> path,
      Value<String> sha256,
    });

class $$CachedImagesTableFilterComposer
    extends Composer<_$ScheduleDb, $CachedImagesTable> {
  $$CachedImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get medicationId => $composableBuilder(
    column: $table.medicationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedImagesTableOrderingComposer
    extends Composer<_$ScheduleDb, $CachedImagesTable> {
  $$CachedImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get medicationId => $composableBuilder(
    column: $table.medicationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedImagesTableAnnotationComposer
    extends Composer<_$ScheduleDb, $CachedImagesTable> {
  $$CachedImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get medicationId => $composableBuilder(
    column: $table.medicationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);
}

class $$CachedImagesTableTableManager
    extends
        RootTableManager<
          _$ScheduleDb,
          $CachedImagesTable,
          CachedImage,
          $$CachedImagesTableFilterComposer,
          $$CachedImagesTableOrderingComposer,
          $$CachedImagesTableAnnotationComposer,
          $$CachedImagesTableCreateCompanionBuilder,
          $$CachedImagesTableUpdateCompanionBuilder,
          (
            CachedImage,
            BaseReferences<_$ScheduleDb, $CachedImagesTable, CachedImage>,
          ),
          CachedImage,
          PrefetchHooks Function()
        > {
  $$CachedImagesTableTableManager(_$ScheduleDb db, $CachedImagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> medicationId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
              }) => CachedImagesCompanion(
                id: id,
                medicationId: medicationId,
                kind: kind,
                path: path,
                sha256: sha256,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int medicationId,
                required String kind,
                required String path,
                required String sha256,
              }) => CachedImagesCompanion.insert(
                id: id,
                medicationId: medicationId,
                kind: kind,
                path: path,
                sha256: sha256,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedImagesTable, CachedImage>(table),
                  BaseReferences<_$ScheduleDb, $CachedImagesTable, CachedImage>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$ScheduleDb,
      $CachedImagesTable,
      CachedImage,
      $$CachedImagesTableFilterComposer,
      $$CachedImagesTableOrderingComposer,
      $$CachedImagesTableAnnotationComposer,
      $$CachedImagesTableCreateCompanionBuilder,
      $$CachedImagesTableUpdateCompanionBuilder,
      (
        CachedImage,
        BaseReferences<_$ScheduleDb, $CachedImagesTable, CachedImage>,
      ),
      CachedImage,
      PrefetchHooks Function()
    >;
typedef $$SyncMetaTableCreateCompanionBuilder = SyncMetaCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SyncMetaTableUpdateCompanionBuilder = SyncMetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SyncMetaTableFilterComposer
    extends Composer<_$ScheduleDb, $SyncMetaTable> {
  $$SyncMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetaTableOrderingComposer
    extends Composer<_$ScheduleDb, $SyncMetaTable> {
  $$SyncMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetaTableAnnotationComposer
    extends Composer<_$ScheduleDb, $SyncMetaTable> {
  $$SyncMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncMetaTableTableManager
    extends
        RootTableManager<
          _$ScheduleDb,
          $SyncMetaTable,
          SyncMetaData,
          $$SyncMetaTableFilterComposer,
          $$SyncMetaTableOrderingComposer,
          $$SyncMetaTableAnnotationComposer,
          $$SyncMetaTableCreateCompanionBuilder,
          $$SyncMetaTableUpdateCompanionBuilder,
          (
            SyncMetaData,
            BaseReferences<_$ScheduleDb, $SyncMetaTable, SyncMetaData>,
          ),
          SyncMetaData,
          PrefetchHooks Function()
        > {
  $$SyncMetaTableTableManager(_$ScheduleDb db, $SyncMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SyncMetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncMetaTable, SyncMetaData>(table),
                  BaseReferences<_$ScheduleDb, $SyncMetaTable, SyncMetaData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$ScheduleDb,
      $SyncMetaTable,
      SyncMetaData,
      $$SyncMetaTableFilterComposer,
      $$SyncMetaTableOrderingComposer,
      $$SyncMetaTableAnnotationComposer,
      $$SyncMetaTableCreateCompanionBuilder,
      $$SyncMetaTableUpdateCompanionBuilder,
      (
        SyncMetaData,
        BaseReferences<_$ScheduleDb, $SyncMetaTable, SyncMetaData>,
      ),
      SyncMetaData,
      PrefetchHooks Function()
    >;
typedef $$PendingEventsTableCreateCompanionBuilder =
    PendingEventsCompanion Function({
      Value<int> id,
      required String clientEventId,
      required String path,
      required String body,
      required DateTime createdAt,
      Value<bool> ready,
      Value<int> attempts,
    });
typedef $$PendingEventsTableUpdateCompanionBuilder =
    PendingEventsCompanion Function({
      Value<int> id,
      Value<String> clientEventId,
      Value<String> path,
      Value<String> body,
      Value<DateTime> createdAt,
      Value<bool> ready,
      Value<int> attempts,
    });

class $$PendingEventsTableFilterComposer
    extends Composer<_$ScheduleDb, $PendingEventsTable> {
  $$PendingEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientEventId => $composableBuilder(
    column: $table.clientEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ready => $composableBuilder(
    column: $table.ready,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingEventsTableOrderingComposer
    extends Composer<_$ScheduleDb, $PendingEventsTable> {
  $$PendingEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientEventId => $composableBuilder(
    column: $table.clientEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ready => $composableBuilder(
    column: $table.ready,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingEventsTableAnnotationComposer
    extends Composer<_$ScheduleDb, $PendingEventsTable> {
  $$PendingEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientEventId => $composableBuilder(
    column: $table.clientEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get ready =>
      $composableBuilder(column: $table.ready, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);
}

class $$PendingEventsTableTableManager
    extends
        RootTableManager<
          _$ScheduleDb,
          $PendingEventsTable,
          PendingEvent,
          $$PendingEventsTableFilterComposer,
          $$PendingEventsTableOrderingComposer,
          $$PendingEventsTableAnnotationComposer,
          $$PendingEventsTableCreateCompanionBuilder,
          $$PendingEventsTableUpdateCompanionBuilder,
          (
            PendingEvent,
            BaseReferences<_$ScheduleDb, $PendingEventsTable, PendingEvent>,
          ),
          PendingEvent,
          PrefetchHooks Function()
        > {
  $$PendingEventsTableTableManager(_$ScheduleDb db, $PendingEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientEventId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> ready = const Value.absent(),
                Value<int> attempts = const Value.absent(),
              }) => PendingEventsCompanion(
                id: id,
                clientEventId: clientEventId,
                path: path,
                body: body,
                createdAt: createdAt,
                ready: ready,
                attempts: attempts,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientEventId,
                required String path,
                required String body,
                required DateTime createdAt,
                Value<bool> ready = const Value.absent(),
                Value<int> attempts = const Value.absent(),
              }) => PendingEventsCompanion.insert(
                id: id,
                clientEventId: clientEventId,
                path: path,
                body: body,
                createdAt: createdAt,
                ready: ready,
                attempts: attempts,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingEventsTable, PendingEvent>(table),
                  BaseReferences<
                    _$ScheduleDb,
                    $PendingEventsTable,
                    PendingEvent
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$ScheduleDb,
      $PendingEventsTable,
      PendingEvent,
      $$PendingEventsTableFilterComposer,
      $$PendingEventsTableOrderingComposer,
      $$PendingEventsTableAnnotationComposer,
      $$PendingEventsTableCreateCompanionBuilder,
      $$PendingEventsTableUpdateCompanionBuilder,
      (
        PendingEvent,
        BaseReferences<_$ScheduleDb, $PendingEventsTable, PendingEvent>,
      ),
      PendingEvent,
      PrefetchHooks Function()
    >;
typedef $$LocalDoseLogsTableCreateCompanionBuilder =
    LocalDoseLogsCompanion Function({
      required int medicationId,
      required DateTime scheduledAt,
      required String status,
      Value<int> rowid,
    });
typedef $$LocalDoseLogsTableUpdateCompanionBuilder =
    LocalDoseLogsCompanion Function({
      Value<int> medicationId,
      Value<DateTime> scheduledAt,
      Value<String> status,
      Value<int> rowid,
    });

class $$LocalDoseLogsTableFilterComposer
    extends Composer<_$ScheduleDb, $LocalDoseLogsTable> {
  $$LocalDoseLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get medicationId => $composableBuilder(
    column: $table.medicationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalDoseLogsTableOrderingComposer
    extends Composer<_$ScheduleDb, $LocalDoseLogsTable> {
  $$LocalDoseLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get medicationId => $composableBuilder(
    column: $table.medicationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalDoseLogsTableAnnotationComposer
    extends Composer<_$ScheduleDb, $LocalDoseLogsTable> {
  $$LocalDoseLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get medicationId => $composableBuilder(
    column: $table.medicationId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$LocalDoseLogsTableTableManager
    extends
        RootTableManager<
          _$ScheduleDb,
          $LocalDoseLogsTable,
          LocalDoseLog,
          $$LocalDoseLogsTableFilterComposer,
          $$LocalDoseLogsTableOrderingComposer,
          $$LocalDoseLogsTableAnnotationComposer,
          $$LocalDoseLogsTableCreateCompanionBuilder,
          $$LocalDoseLogsTableUpdateCompanionBuilder,
          (
            LocalDoseLog,
            BaseReferences<_$ScheduleDb, $LocalDoseLogsTable, LocalDoseLog>,
          ),
          LocalDoseLog,
          PrefetchHooks Function()
        > {
  $$LocalDoseLogsTableTableManager(_$ScheduleDb db, $LocalDoseLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalDoseLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalDoseLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalDoseLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> medicationId = const Value.absent(),
                Value<DateTime> scheduledAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalDoseLogsCompanion(
                medicationId: medicationId,
                scheduledAt: scheduledAt,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int medicationId,
                required DateTime scheduledAt,
                required String status,
                Value<int> rowid = const Value.absent(),
              }) => LocalDoseLogsCompanion.insert(
                medicationId: medicationId,
                scheduledAt: scheduledAt,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalDoseLogsTable, LocalDoseLog>(table),
                  BaseReferences<
                    _$ScheduleDb,
                    $LocalDoseLogsTable,
                    LocalDoseLog
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalDoseLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$ScheduleDb,
      $LocalDoseLogsTable,
      LocalDoseLog,
      $$LocalDoseLogsTableFilterComposer,
      $$LocalDoseLogsTableOrderingComposer,
      $$LocalDoseLogsTableAnnotationComposer,
      $$LocalDoseLogsTableCreateCompanionBuilder,
      $$LocalDoseLogsTableUpdateCompanionBuilder,
      (
        LocalDoseLog,
        BaseReferences<_$ScheduleDb, $LocalDoseLogsTable, LocalDoseLog>,
      ),
      LocalDoseLog,
      PrefetchHooks Function()
    >;

class $ScheduleDbManager {
  final _$ScheduleDb _db;
  $ScheduleDbManager(this._db);
  $$CachedMedicationsTableTableManager get cachedMedications =>
      $$CachedMedicationsTableTableManager(_db, _db.cachedMedications);
  $$CachedImagesTableTableManager get cachedImages =>
      $$CachedImagesTableTableManager(_db, _db.cachedImages);
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db, _db.syncMeta);
  $$PendingEventsTableTableManager get pendingEvents =>
      $$PendingEventsTableTableManager(_db, _db.pendingEvents);
  $$LocalDoseLogsTableTableManager get localDoseLogs =>
      $$LocalDoseLogsTableTableManager(_db, _db.localDoseLogs);
}
