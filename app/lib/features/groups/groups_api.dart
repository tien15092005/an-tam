import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/server_config.dart';
import '../../core/network/api_client.dart';
import '../auth/session.dart';

enum GroupRole { owner, member, elder }

GroupRole _role(String s) => GroupRole.values.byName(s.toLowerCase());

class GroupSummary {
  const GroupSummary(this.id, this.name, this.myRole);
  final int id;
  final String name;
  final GroupRole myRole;

  factory GroupSummary.fromJson(Map<String, dynamic> j) =>
      GroupSummary(j['id'] as int, j['name'] as String, _role(j['myRole'] as String));

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'myRole': myRole.name.toUpperCase()};
}

class GroupMember {
  const GroupMember({required this.userId, required this.displayName, this.phone, required this.role, this.birthYear});
  final int userId;
  final String displayName;
  final String? phone;
  final GroupRole role;
  final int? birthYear;

  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
        userId: j['userId'] as int,
        displayName: j['displayName'] as String,
        phone: j['phone'] as String?,
        role: _role(j['role'] as String),
        birthYear: (j['elder'] as Map<String, dynamic>?)?['birthYear'] as int?,
      );
}

class GroupDetail {
  const GroupDetail(this.id, this.name, this.myRole, this.members);
  final int id;
  final String name;
  final GroupRole myRole;
  final List<GroupMember> members;

  bool get iAmOwner => myRole == GroupRole.owner;

  factory GroupDetail.fromJson(Map<String, dynamic> j) => GroupDetail(
        j['id'] as int,
        j['name'] as String,
        _role(j['myRole'] as String),
        (j['members'] as List).map((m) => GroupMember.fromJson(m as Map<String, dynamic>)).toList(),
      );
}

class Me {
  const Me(this.id, this.accountType, this.displayName, this.groups);
  final int id;
  final String accountType;
  final String displayName;
  final List<GroupSummary> groups;

  bool get isElder => accountType == 'ELDER';

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        j['id'] as int,
        j['accountType'] as String,
        j['displayName'] as String,
        (j['groups'] as List).map((g) => GroupSummary.fromJson(g as Map<String, dynamic>)).toList(),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'accountType': accountType, 'displayName': displayName, 'groups': groups.map((g) => g.toJson()).toList()};
}

class CodeResult {
  const CodeResult(this.code, this.expiresAt);
  final String code;
  final DateTime expiresAt;

  factory CodeResult.fromJson(Map<String, dynamic> j) =>
      CodeResult(j['code'] as String, DateTime.parse(j['expiresAt'] as String).toLocal());
}

/// Typed calls to the group endpoints (backend GroupController).
class GroupsApi {
  GroupsApi(this._ref);
  final Ref _ref;

  Future<Map<String, dynamic>> _post(String path, [Object? data]) async =>
      (await _ref.read(dioProvider).post<Map<String, dynamic>>(path, data: data)).data ?? const {};

  Future<Me> me() async => Me.fromJson((await _ref.read(dioProvider).get<Map<String, dynamic>>('/api/me')).data!);

  Future<GroupDetail> detail(int groupId) async =>
      GroupDetail.fromJson((await _ref.read(dioProvider).get<Map<String, dynamic>>('/api/groups/$groupId')).data!);

  Future<GroupSummary> create(String name) async => GroupSummary.fromJson(await _post('/api/groups', {'name': name}));

  Future<GroupSummary> acceptInvite(String code) async =>
      GroupSummary.fromJson(await _post('/api/invites/accept', {'code': code}));

  Future<CodeResult> createInvite(int groupId) async => CodeResult.fromJson(await _post('/api/groups/$groupId/invites'));

  Future<void> addElder(int groupId, {required String callName, int? birthYear, String? phone}) =>
      _post('/api/groups/$groupId/elders', {'callName': callName, 'birthYear': birthYear, 'phone': phone});

  Future<CodeResult> pairingCode(int groupId, int elderUserId) async =>
      CodeResult.fromJson(await _post('/api/groups/$groupId/elders/$elderUserId/pairing-code'));

  Future<void> transferOwnership(int groupId, int userId) =>
      _post('/api/groups/$groupId/transfer-ownership', {'userId': userId});

  /// A one-time code (15 minutes) for a sibling who forgot their password.
  Future<CodeResult> createPasswordReset(int groupId, int userId) async =>
      CodeResult.fromJson(await _post('/api/groups/$groupId/members/$userId/password-reset'));

  /// A parent's phone was lost: sign it out now; their data stays.
  Future<void> signOutElderPhone(int groupId, int elderUserId) => _post('/api/groups/$groupId/elders/$elderUserId/sign-out');

  /// Removes a parent and erases their data; their phone is signed out.
  Future<void> removeElder(int groupId, int elderUserId) =>
      _ref.read(dioProvider).delete<void>('/api/groups/$groupId/elders/$elderUserId');

  Future<void> removeMember(int groupId, int userId) =>
      _ref.read(dioProvider).delete<void>('/api/groups/$groupId/members/$userId');

  Future<void> leave(int groupId, {bool confirmDelete = false}) =>
      _ref.read(dioProvider).post<void>('/api/groups/$groupId/leave', queryParameters: {'confirmDelete': confirmDelete});
}

final groupsApiProvider = Provider<GroupsApi>(GroupsApi.new);

const _cachedMeKey = 'cached_me';

/// Who is signed in. The last answer is kept on the phone so an elder whose phone is offline still
/// lands on their home screen (and its saved medicines) instead of a network error.
final meProvider = FutureProvider.autoDispose<Me>((ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  try {
    final me = await ref.watch(groupsApiProvider).me();
    await prefs.setString(_cachedMeKey, jsonEncode(me.toJson()));
    return me;
  } on DioException catch (e) {
    final cached = prefs.getString(_cachedMeKey);
    // Fall back when the server could not be reached, or for an elder phone waiting to be paired again
    // (it keeps showing its saved medicines). Never for other errors.
    final waitingForPairing = ref.read(sessionProvider).value?.expired ?? false;
    if ((e.response == null || waitingForPairing) && cached != null) {
      return Me.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }
    rethrow;
  }
});

Future<void> forgetCachedMe(SharedPreferences prefs) => prefs.remove(_cachedMeKey);

final groupDetailProvider =
    FutureProvider.autoDispose.family<GroupDetail, int>((ref, id) => ref.watch(groupsApiProvider).detail(id));
