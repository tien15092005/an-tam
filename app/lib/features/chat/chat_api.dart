import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

/// A chat line. [id] is null while the message is still being sent from this phone.
class ChatMessage {
  const ChatMessage({
    this.id,
    required this.groupId,
    this.senderId,
    this.senderName,
    required this.system,
    this.body,
    this.alertId,
    this.clientMessageId,
    required this.createdAt,
    this.deleted = false,
    this.failed = false,
  });

  final int? id;
  final int groupId;
  final int? senderId;
  final String? senderName;
  final bool system;
  final String? body;
  final int? alertId;
  final String? clientMessageId;
  final DateTime createdAt;
  final bool deleted;

  /// Sending failed; tapping retries with the same clientMessageId, so it is never posted twice.
  final bool failed;

  bool get pending => id == null;

  ChatMessage copyWith({bool? failed}) => ChatMessage(
        id: id,
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        system: system,
        body: body,
        alertId: alertId,
        clientMessageId: clientMessageId,
        createdAt: createdAt,
        deleted: deleted,
        failed: failed ?? this.failed,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as int,
        groupId: j['groupId'] as int,
        senderId: j['senderId'] as int?,
        senderName: j['senderName'] as String?,
        system: j['type'] == 'SYSTEM',
        body: j['body'] as String?,
        alertId: j['alertId'] as int?,
        clientMessageId: j['clientMessageId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
        deleted: j['deleted'] as bool? ?? false,
      );
}

/// Joins what we have with what arrived (history page, socket event, send result): one entry per id, a sent
/// message replaces its pending copy, a deletion replaces the text. Oldest first, pending ones last.
List<ChatMessage> mergeMessages(List<ChatMessage> current, Iterable<ChatMessage> incoming) {
  final byId = <int, ChatMessage>{for (final m in current) if (m.id != null) m.id!: m};
  final pending = <String, ChatMessage>{
    for (final m in current) if (m.id == null && m.clientMessageId != null) m.clientMessageId!: m,
  };
  for (final m in incoming) {
    if (m.id == null) {
      if (m.clientMessageId != null) pending[m.clientMessageId!] = m;
      continue;
    }
    byId[m.id!] = m;
    if (m.clientMessageId != null) pending.remove(m.clientMessageId);
  }
  final sent = byId.values.toList()..sort((a, b) => a.id!.compareTo(b.id!));
  return [...sent, ...pending.values];
}

class ChatApi {
  ChatApi(this._ref);
  final Ref _ref;

  /// Newest first from the server; returned oldest first.
  Future<List<ChatMessage>> history(int groupId, {int? before, int limit = 30}) async {
    final r = await _ref.read(dioProvider).get<List<dynamic>>('/api/groups/$groupId/chat/messages',
        queryParameters: {'limit': limit, 'before': ?before});
    return r.data!.map((j) => ChatMessage.fromJson(j as Map<String, dynamic>)).toList().reversed.toList();
  }

  Future<ChatMessage> send(int groupId, String clientMessageId, String body) async {
    final r = await _ref.read(dioProvider).post<Map<String, dynamic>>('/api/groups/$groupId/chat/messages',
        data: {'clientMessageId': clientMessageId, 'body': body});
    return ChatMessage.fromJson(r.data!);
  }

  Future<void> delete(int groupId, int id) => _ref.read(dioProvider).delete<void>('/api/groups/$groupId/chat/messages/$id');

  Future<void> markRead(int groupId, int lastId) =>
      _ref.read(dioProvider).post<void>('/api/groups/$groupId/chat/read', data: {'lastReadMessageId': lastId});

  Future<Map<int, int>> unread() async {
    final r = await _ref.read(dioProvider).get<Map<String, dynamic>>('/api/me/chat/unread');
    return r.data!.map((k, v) => MapEntry(int.parse(k), (v as num).toInt()));
  }
}

final chatApiProvider = Provider<ChatApi>(ChatApi.new);

/// Unread messages per group, for the "Nhóm" tab badge.
final chatUnreadProvider = FutureProvider.autoDispose<Map<int, int>>((ref) => ref.watch(chatApiProvider).unread());
